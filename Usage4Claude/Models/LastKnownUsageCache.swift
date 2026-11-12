//
//  LastKnownUsageCache.swift
//  Usage4Claude
//
//  The last successful usage of every Claude account, persisted so the popover and
//  the menu bar show the last known numbers (with a warning) instead of an error
//  screen after a relaunch or while an account's requests fail.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// One account's last successful fetch
struct LastKnownUsage: Codable {
    let data: UsageData
    let fetchedAt: Date
}

/// UserDefaults-backed store of the last successful usage per Claude account.
/// Usage percentages and reset times are not credentials, so UserDefaults is fine.
enum LastKnownUsageCache {
    #if DEBUG
    private static let key = "DEBUG_lastKnownClaudeUsage"
    #else
    private static let key = "lastKnownClaudeUsage"
    #endif

    static func load(defaults: UserDefaults = .standard) -> [UUID: LastKnownUsage] {
        guard let raw = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: LastKnownUsage].self, from: raw) else { return [:] }
        var entries: [UUID: LastKnownUsage] = [:]
        for (id, entry) in decoded {
            if let uuid = UUID(uuidString: id) { entries[uuid] = entry }
        }
        return entries
    }

    static func entry(for accountId: UUID, defaults: UserDefaults = .standard) -> LastKnownUsage? {
        load(defaults: defaults)[accountId]
    }

    static func save(_ data: UsageData, for accountId: UUID, at date: Date = Date(), defaults: UserDefaults = .standard) {
        var entries = load(defaults: defaults)
        entries[accountId] = LastKnownUsage(data: data, fetchedAt: date)
        write(entries, defaults: defaults)
    }

    /// Drops entries of accounts that no longer exist
    static func retain(only accountIds: Set<UUID>, defaults: UserDefaults = .standard) {
        let entries = load(defaults: defaults)
        let kept = entries.filter { accountIds.contains($0.key) }
        guard kept.count != entries.count else { return }
        write(kept, defaults: defaults)
    }

    private static func write(_ entries: [UUID: LastKnownUsage], defaults: UserDefaults) {
        let encodable = Dictionary(uniqueKeysWithValues: entries.map { ($0.key.uuidString, $0.value) })
        if let raw = try? JSONEncoder().encode(encodable) {
            defaults.set(raw, forKey: key)
        }
    }
}
