import CloudKit
import Foundation

/// Sync bookkeeping kept next to (not inside) the clip store: the engine state, the last
/// known server system fields of each record, and pinboard entries that arrived before
/// their clip or pinboard.
struct SyncMetadata: Codable {
    var engineState: CKSyncEngine.State.Serialization?
    var systemFields: [String: Data] = [:]
    var orphanEntries: [UUID: SyncSchema.EntryValues] = [:]
    var lastSyncedAt: Date?
    /// Set once images that were skipped (sync on before image support) are queued.
    var imagesBackfilled: Bool?
    /// Change token for the on-screen poller, separate from the engine's own state.
    var pollToken: Data?
    /// True once this device has seen the sync zone exist (saved it, or saved or fetched
    /// records in it) since sync was turned on. A zone deletion reported before that is
    /// an old one, from an earlier "Delete iCloud Data", not a reason to turn sync off.
    var zoneConfirmed: Bool?
    /// The CloudKit environment this was written against ("development" for Debug builds,
    /// "production" otherwise). Nil in metadata written before 1.5.1.
    var environment: String?
}

@MainActor
final class SyncMetadataStore {
    private(set) var value: SyncMetadata
    private let url: URL
    private var pendingSave: Task<Void, Never>?

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipbaraSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("metadata.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(SyncMetadata.self, from: data) {
            value = decoded
        } else {
            value = SyncMetadata()
        }
    }

    func update(_ change: (inout SyncMetadata) -> Void) {
        change(&value)
        scheduleSave()
    }

    func reset() {
        value = SyncMetadata()
        saveNow()
    }

    func saveNow() {
        pendingSave?.cancel()
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    // MARK: - System fields

    func record(for key: SyncKey) -> CKRecord {
        if let data = value.systemFields[key.recordName], let record = Self.decodeSystemFields(data) {
            return record
        }
        return CKRecord(recordType: key.kind.recordType, recordID: key.recordID)
    }

    func remember(_ record: CKRecord) {
        update { $0.systemFields[record.recordID.recordName] = Self.encodeSystemFields(record) }
    }

    func forget(_ recordID: CKRecord.ID) {
        update { $0.systemFields.removeValue(forKey: recordID.recordName) }
    }

    static func encodeSystemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func decodeSystemFields(_ data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }
}
