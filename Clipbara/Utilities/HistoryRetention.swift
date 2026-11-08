import Foundation
import SwiftData

/// How long history is kept (Settings > General > Keep History).
///
/// Clips on a pinboard are never removed, and neither are pinned clips. The
/// default keeps everything, so updating never deletes anyone's history.
enum HistoryRetention: Int, CaseIterable, Identifiable {
    case day = 1
    case week = 7
    case month = 30
    case year = 365
    case forever = 0

    static let defaultsKey = "historyRetentionDays"

    var id: Int { rawValue }

    /// The setting as stored, or keep everything when it was never changed.
    static var current: HistoryRetention {
        HistoryRetention(rawValue: UserDefaults.standard.integer(forKey: defaultsKey)) ?? .forever
    }

    var title: String {
        switch self {
        case .day: String(localized: "1 Day")
        case .week: String(localized: "1 Week")
        case .month: String(localized: "1 Month")
        case .year: String(localized: "1 Year")
        case .forever: String(localized: "Forever")
        }
    }

    /// Clips copied before this date are past the limit. nil keeps everything.
    func cutoff(now: Date = .now) -> Date? {
        guard self != .forever else { return nil }
        return Calendar.current.date(byAdding: .day, value: -rawValue, to: now)
    }

    /// Clips past the limit that may be removed: not pinned and on no pinboard.
    @MainActor
    static func expiredItems(for retention: HistoryRetention, in context: ModelContext, now: Date = .now) -> [ClipboardItem] {
        guard let cutoff = retention.cutoff(now: now) else { return [] }
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.copiedAt < cutoff && !$0.isPinned }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []
        guard !candidates.isEmpty else { return [] }
        let onPinboards = pinboardItemIDs(in: context)
        return candidates.filter { !onPinboards.contains($0.id) }
    }

    /// Removes the clips past the limit and saves. Returns how many went.
    @MainActor
    @discardableResult
    static func deleteExpired(for retention: HistoryRetention = .current, in context: ModelContext, now: Date = .now) -> Int {
        let items = expiredItems(for: retention, in: context, now: now)
        guard !items.isEmpty else { return 0 }
        for item in items {
            context.delete(item)
        }
        try? context.save()
        return items.count
    }

    /// Every clip that isn't on a pinboard, which is what clearing history removes.
    @MainActor
    static func clearableItems(in context: ModelContext) -> [ClipboardItem] {
        let all = (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        let onPinboards = pinboardItemIDs(in: context)
        return all.filter { !onPinboards.contains($0.id) }
    }

    @MainActor
    private static func pinboardItemIDs(in context: ModelContext) -> Set<UUID> {
        let entries = (try? context.fetch(FetchDescriptor<PinboardEntry>())) ?? []
        return Set(entries.compactMap { $0.clipboardItem?.id })
    }
}
