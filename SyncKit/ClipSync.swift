import CloudKit
import Foundation
import Observation
import SwiftData
import os

/// Optional iCloud sync of history and pinboards through the person's private CloudKit
/// database, using CKSyncEngine.
///
/// The local SwiftData store stays the source of truth and keeps its current schema.
/// Local saves are picked up from `ModelContext.didSave` and queued for upload; changes
/// from other devices are written back through the same models.
@MainActor
@Observable
final class ClipSync {
    enum Phase: Equatable {
        case off
        case starting
        case syncing
        case upToDate
        case needsAccount
        case failed(String)
    }

    static let shared = ClipSync()
    static let enabledKey = "iCloudSyncEnabled"
    static let imagesKey = "iCloudSyncImages"
    /// The poller's change token, shared with the keyboard (through the app group on
    /// iOS) so it can fetch only what changed since the app last looked.
    static let sharedPollTokenKey = "iCloudSyncPollToken"

    private(set) var phase: Phase = .off
    private(set) var lastSyncedAt: Date?

    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var defaults: UserDefaults = .standard
    @ObservationIgnored private lazy var metadata = SyncMetadataStore()
    @ObservationIgnored private var index: [PersistentIdentifier: SyncKey] = [:]
    @ObservationIgnored private var applyingRemote = false
    @ObservationIgnored private var saveObserver: NSObjectProtocol?

    private let log = Logger(subsystem: "com.minsang.Clipbara", category: "Sync")

    /// The CloudKit environment this build talks to. Xcode signs Debug builds for
    /// development; TestFlight and App Store builds use production.
    static var environment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    static var containerIdentifier: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "ClipbaraCloudKitContainer") as? String,
              id.hasPrefix("iCloud.") else { return nil }
        return id
    }

    var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }

    /// Images sync unless turned off. Stored so the settings toggle survives relaunches.
    var includesImages: Bool {
        defaults.object(forKey: Self.imagesKey) as? Bool ?? true
    }

    func setIncludesImages(_ on: Bool) {
        defaults.set(on, forKey: Self.imagesKey)
        imageSettingVersion += 1
        guard on, let engine, let context else { return }
        // Upload images that were skipped while this was off.
        let images = (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for item in images where item.contentType == .image && SyncSchema.isEligible(item, includeImages: true) {
            changes.append(.saveRecord(SyncKey(kind: .clip, id: item.id).recordID))
        }
        for entry in (try? context.fetch(FetchDescriptor<PinboardEntry>())) ?? []
        where entry.clipboardItem?.contentType == .image && SyncSchema.isEligible(entry, includeImages: true) {
            changes.append(.saveRecord(SyncKey(kind: .entry, id: entry.id).recordID))
        }
        engine.state.add(pendingRecordZoneChanges: changes)
        Task { await syncNow() }
    }

    /// Bumped so views re-read `includesImages`, which lives in UserDefaults.
    private(set) var imageSettingVersion = 0

    private var context: ModelContext? { modelContainer?.mainContext }

    // MARK: - Lifecycle

    /// Call once at launch. Starts syncing only if the person turned it on earlier.
    func configure(container: ModelContainer, defaults: UserDefaults) {
        modelContainer = container
        self.defaults = defaults
        lastSyncedAt = metadata.value.lastSyncedAt
        if isEnabled {
            if let saved = metadata.value.environment, saved != Self.environment {
                // A Debug build and an App Store build share this container on a test
                // device, but not a CloudKit environment. Start over against this one
                // instead of feeding the engine state from the other.
                log.info("sync metadata is from the \(saved, privacy: .public) environment; starting over")
                defaults.removeObject(forKey: Self.sharedPollTokenKey)
                metadata.reset()
                metadata.update { $0.environment = Self.environment }
                startEngine(initialUpload: true)
                syncOnOpen()
                return
            }
            if metadata.value.environment == nil {
                metadata.update { $0.environment = Self.environment }
            }
            startEngine(initialUpload: false)
            // Pushes can be delayed or coalesced; catch up once at launch.
            syncOnOpen()
        }
    }

    struct UploadEstimate {
        var clips = 0
        var images = 0
        var imageBytes = 0
        var pinboards = 0
    }

    /// What turning sync on would upload from this device.
    func uploadEstimate() -> UploadEstimate {
        guard let context else { return UploadEstimate() }
        var estimate = UploadEstimate()
        for item in (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        where SyncSchema.isEligible(item, includeImages: includesImages) {
            if item.contentType == .image {
                estimate.images += 1
                estimate.imageBytes += min(item.rawData.count, SyncImages.maxBytes)
            } else {
                estimate.clips += 1
            }
        }
        estimate.pinboards = (try? context.fetchCount(FetchDescriptor<Pinboard>())) ?? 0
        return estimate
    }

    func enable() async {
        guard let identifier = Self.containerIdentifier else {
            phase = .failed(String(localized: "iCloud is not set up for this build."))
            return
        }
        phase = .starting
        let status = (try? await CKContainer(identifier: identifier).accountStatus()) ?? .couldNotDetermine
        guard status == .available else {
            phase = .needsAccount
            return
        }
        defaults.set(true, forKey: Self.enabledKey)
        metadata.reset()
        metadata.update { $0.environment = Self.environment }
        startEngine(initialUpload: true)
        await syncNow()
    }

    /// Stops syncing. Clips stay on this device and in iCloud.
    func disable() {
        defaults.set(false, forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.sharedPollTokenKey)
        stopEngine()
        metadata.reset()
        lastSyncedAt = nil
        phase = .off
    }

    /// Deletes everything Clipbara stored in iCloud, then turns sync off here.
    /// Other devices notice the deleted zone and turn sync off too; their local clips stay.
    func deleteCloudData() async {
        guard let engine else {
            disable()
            return
        }
        engine.state.add(pendingDatabaseChanges: [.deleteZone(SyncKey.zoneID)])
        do {
            try await engine.sendChanges()
            disable()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    @ObservationIgnored private var lastOpportunisticSync = Date.distantPast
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSend: Task<Void, Never>?
    @ObservationIgnored private var lastActivityAt = Date()

    /// Catch-up when the person opens Clipbara, in case a push was missed.
    func syncOnOpen() {
        guard engine != nil, Date().timeIntervalSince(lastOpportunisticSync) > 3 else { return }
        lastOpportunisticSync = Date()
        lastActivityAt = Date()
        enqueueUnsent()
        Task { await syncNow() }
    }

    /// Pull to refresh on the iPhone list: what opening the app does, but awaited
    /// so the spinner stays until the round trip is done.
    func refresh() async {
        guard engine != nil else { return }
        lastOpportunisticSync = Date()
        lastActivityAt = Date()
        enqueueUnsent()
        await syncNow()
    }

    /// While Clipbara is on screen, check for changes every few seconds instead of
    /// waiting for a push, which can arrive late or not at all. Polls every 4 seconds
    /// while things are changing and every 15 seconds after two quiet minutes; backs off
    /// to 30 seconds after an error. Stop it when the app leaves the screen.
    ///
    /// CKSyncEngine.fetchChanges() only goes to the server for zones it already knows
    /// changed (from a push), so without pushes it does nothing. The poll asks the
    /// server directly with its own change token; applying a record twice is harmless.
    func startLivePolling() {
        guard engine != nil, pollTask == nil else { return }
        lastActivityAt = Date()
        pollTask = Task { @MainActor [weak self] in
            var failed = false
            while !Task.isCancelled {
                let quiet = Date().timeIntervalSince(self?.lastActivityAt ?? .distantPast) > 120
                let interval: Double = failed ? 30 : (quiet ? 15 : 4)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let engine = self?.engine else { return }
                guard engine === self?.engine else { return }
                do {
                    try await self?.pollServer()
                    failed = false
                } catch {
                    failed = true
                }
            }
        }
    }

    func stopLivePolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Sends local changes right away instead of waiting for the engine's own schedule.
    private func sendSoon() {
        lastActivityAt = Date()
        pendingSend?.cancel()
        pendingSend = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let engine = self?.engine else { return }
            try? await engine.sendChanges()
        }
    }

    func syncNow() async {
        guard let engine else { return }
        phase = .syncing
        do {
            try await engine.fetchChanges()
            try await pollServer()
            try await engine.sendChanges()
            markSynced()
        } catch {
            log.error("sync failed: \(error.localizedDescription, privacy: .public)")
            phase = Self.phase(for: error)
        }
    }

    private func startEngine(initialUpload: Bool) {
        guard engine == nil, let identifier = Self.containerIdentifier, modelContainer != nil else { return }
        let database = CKContainer(identifier: identifier).privateCloudDatabase
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: metadata.value.engineState,
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        SyncImages.clearStaging()
        phase = .starting
        rebuildIndex()
        observeSaves()
        if !initialUpload, metadata.value.zoneConfirmed == nil, !metadata.value.systemFields.isEmpty {
            confirmZone()
        }
        if initialUpload {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncKey.zoneID))])
            enqueueEverything()
            metadata.update { $0.imagesBackfilled = true }
        } else if includesImages && metadata.value.imagesBackfilled != true {
            // Sync was on before images were supported: send the images it skipped.
            setIncludesImages(true)
            metadata.update { $0.imagesBackfilled = true }
        }
    }

    private func stopEngine() {
        stopLivePolling()
        pendingSend?.cancel()
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
        saveObserver = nil
        engine = nil
        index = [:]
    }

    private func markSynced() {
        let now = Date()
        lastSyncedAt = now
        metadata.update { $0.lastSyncedAt = now }
        phase = .upToDate
    }

    private static func phase(for error: Error) -> Phase {
        if let ck = error as? CKError, ck.code == .notAuthenticated {
            return .needsAccount
        }
        return .failed(error.localizedDescription)
    }

    // MARK: - Local changes -> pending uploads

    private func observeSaves() {
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let info = note.userInfo ?? [:]
            let inserted = info[ModelContext.NotificationKey.insertedIdentifiers.rawValue] as? [PersistentIdentifier] ?? []
            let updated = info[ModelContext.NotificationKey.updatedIdentifiers.rawValue] as? [PersistentIdentifier] ?? []
            let deleted = info[ModelContext.NotificationKey.deletedIdentifiers.rawValue] as? [PersistentIdentifier] ?? []
            MainActor.assumeIsolated {
                self?.handleLocalSave(changed: inserted + updated, deleted: deleted)
            }
        }
    }

    private func handleLocalSave(changed: [PersistentIdentifier], deleted: [PersistentIdentifier]) {
        guard let engine, let context else { return }
        var saves: [CKSyncEngine.PendingRecordZoneChange] = []
        var deletes: [CKSyncEngine.PendingRecordZoneChange] = []

        for identifier in changed {
            guard let pair = Self.key(for: context.model(for: identifier), includeImages: includesImages) else { continue }
            let (key, eligible) = pair
            index[identifier] = key
            if eligible && !applyingRemote {
                saves.append(.saveRecord(key.recordID))
            }
        }
        for identifier in deleted {
            guard let key = index.removeValue(forKey: identifier) else { continue }
            if !applyingRemote {
                deletes.append(.deleteRecord(key.recordID))
            }
        }
        if !saves.isEmpty || !deletes.isEmpty {
            engine.state.add(pendingRecordZoneChanges: saves + deletes)
            sendSoon()
        }
    }

    private static func key(for model: any PersistentModel, includeImages: Bool) -> (SyncKey, Bool)? {
        switch model {
        case let item as ClipboardItem:
            return (SyncKey(kind: .clip, id: item.id), SyncSchema.isEligible(item, includeImages: includeImages))
        case let pinboard as Pinboard:
            return (SyncKey(kind: .pinboard, id: pinboard.id), true)
        case let entry as PinboardEntry:
            return (SyncKey(kind: .entry, id: entry.id), SyncSchema.isEligible(entry, includeImages: includeImages))
        default:
            return nil
        }
    }

    private func rebuildIndex() {
        guard let context else { return }
        index = [:]
        for item in (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? [] {
            index[item.persistentModelID] = SyncKey(kind: .clip, id: item.id)
        }
        for pinboard in (try? context.fetch(FetchDescriptor<Pinboard>())) ?? [] {
            index[pinboard.persistentModelID] = SyncKey(kind: .pinboard, id: pinboard.id)
        }
        for entry in (try? context.fetch(FetchDescriptor<PinboardEntry>())) ?? [] {
            index[entry.persistentModelID] = SyncKey(kind: .entry, id: entry.id)
        }
    }

    private func enqueueEverything() {
        guard let engine, let context else { return }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for pinboard in (try? context.fetch(FetchDescriptor<Pinboard>())) ?? [] {
            changes.append(.saveRecord(SyncKey(kind: .pinboard, id: pinboard.id).recordID))
        }
        for item in (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        where SyncSchema.isEligible(item, includeImages: includesImages) {
            changes.append(.saveRecord(SyncKey(kind: .clip, id: item.id).recordID))
        }
        for entry in (try? context.fetch(FetchDescriptor<PinboardEntry>())) ?? []
        where SyncSchema.isEligible(entry, includeImages: includesImages) {
            changes.append(.saveRecord(SyncKey(kind: .entry, id: entry.id).recordID))
        }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    /// Queues anything that should be in iCloud but was never sent: no saved server
    /// record and nothing pending. A save the observer missed would otherwise stay on
    /// this device until the clip changed again.
    private func enqueueUnsent() {
        guard let engine, let context else { return }
        let known = Set(metadata.value.systemFields.keys)
        let pending = Set(engine.state.pendingRecordZoneChanges.compactMap { change -> String? in
            if case .saveRecord(let id) = change { return id.recordName }
            return nil
        })
        func unsent(_ key: SyncKey) -> Bool {
            !known.contains(key.recordName) && !pending.contains(key.recordName)
        }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for pinboard in (try? context.fetch(FetchDescriptor<Pinboard>())) ?? [] {
            let key = SyncKey(kind: .pinboard, id: pinboard.id)
            if unsent(key) { changes.append(.saveRecord(key.recordID)) }
        }
        for item in (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        where SyncSchema.isEligible(item, includeImages: includesImages) {
            let key = SyncKey(kind: .clip, id: item.id)
            if unsent(key) { changes.append(.saveRecord(key.recordID)) }
        }
        for entry in (try? context.fetch(FetchDescriptor<PinboardEntry>())) ?? []
        where SyncSchema.isEligible(entry, includeImages: includesImages) {
            let key = SyncKey(kind: .entry, id: entry.id)
            if unsent(key) { changes.append(.saveRecord(key.recordID)) }
        }
        guard !changes.isEmpty else { return }
        log.info("queueing \(changes.count, privacy: .public) unsent records")
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    // MARK: - Polling

    @ObservationIgnored private var polling = false

    private static let lightKeys: [CKRecord.FieldKey] = [
        SyncSchema.ClipField.type, SyncSchema.ClipField.copiedAt, SyncSchema.ClipField.text,
        SyncSchema.ClipField.title, SyncSchema.ClipField.hash, SyncSchema.ClipField.sourceApp,
        SyncSchema.ClipField.sourceBundle,
        SyncSchema.PinboardField.name, SyncSchema.PinboardField.order, SyncSchema.PinboardField.createdAt,
        SyncSchema.EntryField.clipID, SyncSchema.EntryField.pinboardID, SyncSchema.EntryField.order,
        SyncSchema.EntryField.addedAt,
    ]

    private func pollServer() async throws {
        guard !polling, engine != nil, let identifier = Self.containerIdentifier, let context else { return }
        polling = true
        defer { polling = false }
        let database = CKContainer(identifier: identifier).privateCloudDatabase

        var token = metadata.value.pollToken.flatMap(Self.decodeToken)
        var modifications: [CKRecord] = []
        var deletions: [CKRecord.ID] = []
        var moreComing = true
        do {
            while moreComing {
                // Image bytes are left out here; missing images are fetched below.
                let result = try await database.recordZoneChanges(
                    inZoneWith: SyncKey.zoneID,
                    since: token,
                    desiredKeys: Self.lightKeys,
                    resultsLimit: 200
                )
                for (_, outcome) in result.modificationResultsByID {
                    if case .success(let modification) = outcome {
                        modifications.append(modification.record)
                    }
                }
                deletions += result.deletions.map(\.recordID)
                token = result.changeToken
                moreComing = result.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .changeTokenExpired {
            metadata.update { $0.pollToken = nil }
            if error.code == .zoneNotFound, metadata.value.zoneConfirmed == true, engine != nil {
                // Deleted from another device (or from iCloud settings) while this one is
                // open. Turn sync off here, as the engine would once it fetched the
                // database changes. Asking the engine to fetch from here crashed inside
                // CloudKit on 1.5 (an assertion in fetchChanges), so it is left alone.
                log.info("sync zone is gone on the server; turning sync off")
                disable()
            }
            return
        }

        // Images we do not have yet: fetch the full records, asset included.
        let missingImages = modifications.filter { record in
            guard (record[SyncSchema.ClipField.type] as? String) == ContentType.image.rawValue,
                  let key = SyncKey(recordID: record.recordID) else { return false }
            let id = key.id
            return ((try? context.fetchCount(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == id }))) ?? 0) == 0
        }.map(\.recordID)
        if !missingImages.isEmpty {
            let full = try await database.records(for: missingImages)
            modifications = modifications.map { record in
                if case .success(let complete)? = full[record.recordID] { return complete }
                return record
            }
        }

        if !modifications.isEmpty || !deletions.isEmpty {
            applyRemote(modifications: modifications, deletions: deletions)
        }
        if let token {
            let data = Self.encodeToken(token)
            metadata.update { $0.pollToken = data }
            defaults.set(data, forKey: Self.sharedPollTokenKey)
        }
    }

    private static func encodeToken(_ token: CKServerChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private static func decodeToken(_ data: Data) -> CKServerChangeToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    // MARK: - Building records to send

    fileprivate func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let key = SyncKey(recordID: recordID), let context else { return nil }
        let record = metadata.record(for: key)
        let id = key.id
        switch key.kind {
        case .clip:
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == id })
            guard let item = try? context.fetch(descriptor).first,
                  SyncSchema.isEligible(item, includeImages: includesImages),
                  SyncSchema.fill(record, from: item) else { return nil }
        case .pinboard:
            let descriptor = FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == id })
            guard let pinboard = try? context.fetch(descriptor).first else { return nil }
            SyncSchema.fill(record, from: pinboard)
        case .entry:
            let descriptor = FetchDescriptor<PinboardEntry>(predicate: #Predicate { $0.id == id })
            guard let entry = try? context.fetch(descriptor).first,
                  SyncSchema.isEligible(entry, includeImages: includesImages) else { return nil }
            SyncSchema.fill(record, from: entry)
        }
        return record
    }

    // MARK: - Events

    fileprivate func handle(_ event: CKSyncEngine.Event) {
        switch event {
        case .stateUpdate(let update):
            metadata.update { $0.engineState = update.stateSerialization }

        case .accountChange(let change):
            handleAccountChange(change)

        case .fetchedDatabaseChanges(let changes):
            if changes.modifications.contains(where: { $0.zoneID == SyncKey.zoneID }) {
                confirmZone()
            }
            if changes.deletions.contains(where: { $0.zoneID == SyncKey.zoneID }) {
                if metadata.value.zoneConfirmed == true {
                    // Deleted from another device (or from iCloud settings). Keep local clips.
                    log.info("sync zone was deleted remotely; turning sync off")
                    disable()
                } else {
                    // A fresh engine is told about every past deletion, including the one
                    // from an earlier "Delete iCloud Data". Turning sync off here would
                    // make it impossible to turn back on; recreate the zone instead.
                    log.info("ignoring an earlier deletion of the sync zone")
                    engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncKey.zoneID))])
                }
            }

        case .sentDatabaseChanges(let sent):
            if sent.savedZones.contains(where: { $0.zoneID == SyncKey.zoneID }) {
                confirmZone()
            }

        case .fetchedRecordZoneChanges(let changes):
            if !changes.modifications.isEmpty { confirmZone() }
            applyRemote(modifications: changes.modifications.map(\.record), deletions: changes.deletions.map(\.recordID))

        case .sentRecordZoneChanges(let sent):
            handleSent(sent)

        case .willFetchChanges, .willSendChanges:
            phase = .syncing

        case .didFetchChanges, .didSendChanges:
            if engine?.state.pendingRecordZoneChanges.isEmpty ?? true {
                markSynced()
            }
            if case .didFetchChanges = event {
                // Also move the shared poll token forward after a push-driven fetch, so the
                // keyboard only has to fetch what arrived after this point.
                Task { try? await pollServer() }
            }

        case .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break

        @unknown default:
            break
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            enqueueEverything()
        case .signOut, .switchAccounts:
            // Never mix one account's clips into another. Local clips stay; sync turns off.
            disable()
            phase = .needsAccount
        @unknown default:
            break
        }
    }

    private func confirmZone() {
        guard metadata.value.zoneConfirmed != true else { return }
        metadata.update { $0.zoneConfirmed = true }
    }

    private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) {
        guard let engine else { return }
        if !sent.savedRecords.isEmpty { confirmZone() }
        for record in sent.savedRecords {
            metadata.remember(record)
            SyncImages.removeStaged(recordName: record.recordID.recordName)
        }
        for recordID in sent.deletedRecordIDs {
            metadata.forget(recordID)
        }
        var retry: [CKSyncEngine.PendingRecordZoneChange] = []
        var needsZone = false
        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            SyncImages.removeStaged(recordName: recordID.recordName)  // rebuilt on retry
            switch failure.error.code {
            case .serverRecordChanged:
                // Keep our values on top of the newer server record.
                if let server = failure.error.serverRecord {
                    metadata.remember(server)
                }
                retry.append(.saveRecord(recordID))
            case .zoneNotFound:
                metadata.forget(recordID)
                needsZone = true
                retry.append(.saveRecord(recordID))
            case .unknownItem:
                // Deleted on another device: deletes win over edits.
                metadata.forget(recordID)
                if let key = SyncKey(recordID: recordID) {
                    applyRemote(modifications: [], deletions: [key.recordID])
                }
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .requestRateLimited, .notAuthenticated, .operationCancelled:
                break // CKSyncEngine retries these on its own.
            default:
                log.error("record save failed: \(failure.error.localizedDescription, privacy: .public)")
                phase = .failed(failure.error.localizedDescription)
            }
        }
        if needsZone {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncKey.zoneID))])
        }
        if !retry.isEmpty {
            engine.state.add(pendingRecordZoneChanges: retry)
            // The engine backs off after a failed send; these are fixable right away
            // (zone recreated, server change tag refreshed), so send again now.
            // Hop through GCD: a task started here inherits the delegate-callback
            // context, and CKSyncEngine traps ("Cannot await a call into CKSyncEngine
            // from within a delegate callback") when that task calls back into it.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
                MainActor.assumeIsolated {
                    guard let engine = self?.engine else { return }
                    Task { try? await engine.sendChanges() }
                }
            }
        }
    }

    // MARK: - Remote changes -> local store

    private func applyRemote(modifications: [CKRecord], deletions: [CKRecord.ID]) {
        guard let context else { return }
        if !modifications.isEmpty || !deletions.isEmpty { lastActivityAt = Date() }
        applyingRemote = true
        defer { applyingRemote = false }

        var followUps: [CKSyncEngine.PendingRecordZoneChange] = []
        let byKind = Dictionary(grouping: modifications) { SyncKey(recordID: $0.recordID)?.kind }

        for record in byKind[.pinboard] ?? [] {
            metadata.remember(record)
            applyPinboard(record, context: context)
        }
        for record in byKind[.clip] ?? [] {
            metadata.remember(record)
            followUps += applyClip(record, context: context)
        }
        for record in byKind[.entry] ?? [] {
            metadata.remember(record)
            guard let key = SyncKey(recordID: record.recordID),
                  let values = SyncSchema.entryValues(record, id: key.id) else { continue }
            if !applyEntry(values, context: context) {
                metadata.update { $0.orphanEntries[values.id] = values }
            }
        }
        for recordID in deletions {
            metadata.forget(recordID)
            guard let key = SyncKey(recordID: recordID) else { continue }
            deleteLocal(key, context: context)
        }
        retryOrphans(context: context)
        try? context.save()

        if !followUps.isEmpty {
            engine?.state.add(pendingRecordZoneChanges: followUps)
        }
    }

    private func applyPinboard(_ record: CKRecord, context: ModelContext) {
        guard let key = SyncKey(recordID: record.recordID) else { return }
        let id = key.id
        let pinboard: Pinboard
        if let existing = try? context.fetch(FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == id })).first {
            pinboard = existing
        } else {
            pinboard = Pinboard(name: "", displayOrder: 0)
            pinboard.id = id
            context.insert(pinboard)
        }
        pinboard.name = record.encryptedValues[SyncSchema.PinboardField.name] as String? ?? pinboard.name
        pinboard.displayOrder = record[SyncSchema.PinboardField.order] as? Int ?? pinboard.displayOrder
        pinboard.createdAt = record[SyncSchema.PinboardField.createdAt] as? Date ?? pinboard.createdAt
    }

    /// Returns follow-up uploads needed to settle a duplicate.
    private func applyClip(_ record: CKRecord, context: ModelContext) -> [CKSyncEngine.PendingRecordZoneChange] {
        guard let key = SyncKey(recordID: record.recordID), let values = SyncSchema.clipValues(record) else { return [] }
        let id = key.id

        if let existing = try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == id })).first {
            update(existing, with: values)
            return []
        }

        // Same content already saved here under another ID (e.g. copied on both devices).
        if let twin = localTwin(of: values, excluding: id, context: context) {
            if SyncSchema.survivor(twin.id, id) == twin.id {
                twin.copiedAt = max(twin.copiedAt, values.copiedAt)
                // The other device will drop its copy once it sees this delete.
                return [.deleteRecord(key.recordID), .saveRecord(SyncKey(kind: .clip, id: twin.id).recordID)]
            }
            // The incoming ID wins. Keep the local clip under that ID rather than replacing
            // it with the record: text arrives as plain text, while the local copy may be
            // the original rich text or HTML.
            let oldKey = SyncKey(kind: .clip, id: twin.id)
            let entries = pinboardEntries(of: twin.id, context: context)
            twin.id = id
            twin.copiedAt = max(twin.copiedAt, values.copiedAt)
            if twin.userTitle == nil { twin.userTitle = values.title }
            index[twin.persistentModelID] = key
            // Entry records name their clip by ID, so they need to go up again.
            var followUps: [CKSyncEngine.PendingRecordZoneChange] = [.deleteRecord(oldKey.recordID)]
            for entry in entries {
                followUps.append(.saveRecord(SyncKey(kind: .entry, id: entry.id).recordID))
            }
            return followUps
        }

        insertClip(id: id, values: values, context: context)
        return []
    }

    /// Finds a local clip with the same content. Text is compared as text, because the
    /// devices hash different bytes for the same copy (HTML on the Mac, plain text on the
    /// iPhone). Images are compared by hash, then by picture: the Mac keeps TIFF while
    /// the iPhone saves PNG or JPEG of the same copy.
    private func localTwin(of values: SyncSchema.ClipValues, excluding id: UUID, context: ModelContext) -> ClipboardItem? {
        if values.type == .image {
            let hash = values.hash
            if !hash.isEmpty,
               let match = ((try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.contentHash == hash }))) ?? [])
                .first(where: { $0.id != id }) {
                return match
            }
            guard let data = values.imageData else { return nil }
            return ClipboardItem.recentImage(matching: data, excluding: id, in: context)
        }
        let text: String? = values.text
        let matches = (try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.textContent == text }))) ?? []
        return matches.first { $0.id != id && SyncSchema.isTextual($0.contentType) }
    }

    @discardableResult
    private func insertClip(id: UUID, values: SyncSchema.ClipValues, context: ModelContext) -> ClipboardItem {
        let isImage = values.type == .image
        let item = ClipboardItem(
            contentType: values.type,
            rawData: values.imageData ?? Data(values.text.utf8),
            textContent: isImage ? nil : values.text,
            thumbnailData: values.imageData.flatMap { SyncImages.thumbnail(for: $0) },
            sourceAppName: values.sourceApp,
            sourceAppBundleId: values.sourceBundle,
            contentHash: values.hash
        )
        item.id = id
        update(item, with: values)
        context.insert(item)
        return item
    }

    private func update(_ item: ClipboardItem, with values: SyncSchema.ClipValues) {
        item.copiedAt = values.copiedAt
        item.userTitle = values.title
        // Image bytes never change after capture; only text can be edited.
        if values.type != .image, item.textContent != values.text, SyncSchema.syncedType(item.contentType) == values.type {
            item.textContent = values.text
            item.rawData = Data(values.text.utf8)
        }
    }

    private func applyEntry(_ values: SyncSchema.EntryValues, context: ModelContext) -> Bool {
        let clipID = values.clipID
        let boardID = values.pinboardID
        let entryID = values.id
        guard let item = try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == clipID })).first,
              let pinboard = try? context.fetch(FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == boardID })).first else {
            return false
        }
        let entry: PinboardEntry
        if let existing = try? context.fetch(FetchDescriptor<PinboardEntry>(predicate: #Predicate { $0.id == entryID })).first {
            entry = existing
            entry.clipboardItem = item
            entry.pinboard = pinboard
        } else {
            entry = PinboardEntry(clipboardItem: item, pinboard: pinboard, displayOrder: values.order)
            entry.id = entryID
            context.insert(entry)
        }
        entry.displayOrder = values.order
        entry.addedAt = values.addedAt
        item.isPinned = true
        return true
    }

    private func retryOrphans(context: ModelContext) {
        let orphans = metadata.value.orphanEntries
        guard !orphans.isEmpty else { return }
        for (id, values) in orphans where applyEntry(values, context: context) {
            metadata.update { $0.orphanEntries.removeValue(forKey: id) }
        }
    }

    private func deleteLocal(_ key: SyncKey, context: ModelContext) {
        let id = key.id
        switch key.kind {
        case .clip:
            guard let item = try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == id })).first else { return }
            for entry in pinboardEntries(of: id, context: context) {
                context.delete(entry)
            }
            context.delete(item)
        case .pinboard:
            guard let pinboard = try? context.fetch(FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == id })).first else { return }
            let items = pinboard.entries.compactMap(\.clipboardItem)
            context.delete(pinboard)
            for item in items { refreshPinned(item, ignoring: pinboard.id, context: context) }
        case .entry:
            metadata.update { $0.orphanEntries.removeValue(forKey: id) }
            guard let entry = try? context.fetch(FetchDescriptor<PinboardEntry>(predicate: #Predicate { $0.id == id })).first else { return }
            let item = entry.clipboardItem
            let boardID = entry.pinboard?.id
            context.delete(entry)
            if let item { refreshPinned(item, ignoring: boardID, removingEntry: id, context: context) }
        }
    }

    private func pinboardEntries(of clipID: UUID, context: ModelContext) -> [PinboardEntry] {
        (try? context.fetch(FetchDescriptor<PinboardEntry>(predicate: #Predicate { $0.clipboardItem?.id == clipID }))) ?? []
    }

    private func refreshPinned(
        _ item: ClipboardItem,
        ignoring boardID: UUID?,
        removingEntry entryID: UUID? = nil,
        context: ModelContext
    ) {
        let remaining = pinboardEntries(of: item.id, context: context)
            .filter { $0.id != entryID && $0.pinboard?.id != boardID && !$0.isDeleted }
        item.isPinned = !remaining.isEmpty
    }
}

// MARK: - CKSyncEngineDelegate

extension ClipSync: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard syncEngine === engine else { return }
        handle(event)
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard syncEngine === engine else { return nil }
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !changes.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            await self.record(for: recordID)
        }
    }
}
