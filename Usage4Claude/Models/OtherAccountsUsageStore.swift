//
//  OtherAccountsUsageStore.swift
//  Usage4Claude
//
//  Usage of the Claude accounts other than the active one, shown as extra
//  side-by-side columns in the popover. The menu bar icon, notifications,
//  smart refresh and fetch backoff stay tied to the active account only.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Combine

/// The latest fetch result of one non-active Claude account
struct AccountUsageSnapshot {
    /// Last successful data; kept on transient errors so the column does not go blank
    var usageData: UsageData?
    var errorMessage: String?
    /// Whether `errorMessage` needs the user to fix credentials (vs. a transient rate limit / network error)
    var errorRequiresAuthAction = false
    /// When `usageData` was fetched (shown next to a warning while it is stale)
    var fetchedAt: Date?
}

/// Usage of every Claude account except the active one, keyed by account id
final class OtherAccountsUsageStore: ObservableObject {
    @Published private(set) var snapshots: [UUID: AccountUsageSnapshot] = [:]

    func snapshot(for accountId: UUID) -> AccountUsageSnapshot? {
        snapshots[accountId]
    }

    func recordSuccess(_ data: UsageData, at date: Date = Date(), for accountId: UUID) {
        snapshots[accountId] = AccountUsageSnapshot(usageData: data, fetchedAt: date)
    }

    /// Last known data restored from disk, before the first fetch of this launch
    func seed(_ data: UsageData, fetchedAt: Date, for accountId: UUID) {
        guard snapshots[accountId] == nil else { return }
        snapshots[accountId] = AccountUsageSnapshot(usageData: data, fetchedAt: fetchedAt)
    }

    func recordFailure(_ message: String, requiresAuthAction: Bool, for accountId: UUID) {
        var snapshot = snapshots[accountId] ?? AccountUsageSnapshot()
        snapshot.errorMessage = message
        snapshot.errorRequiresAuthAction = requiresAuthAction
        snapshots[accountId] = snapshot
    }

    /// Drops accounts that were removed or became the active one
    func retain(only accountIds: Set<UUID>) {
        snapshots = snapshots.filter { accountIds.contains($0.key) }
    }

    func removeAll() {
        snapshots = [:]
    }
}
