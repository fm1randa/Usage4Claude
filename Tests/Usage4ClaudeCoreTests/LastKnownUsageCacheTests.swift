import XCTest
@testable import Usage4ClaudeCore

/// `LastKnownUsageCache` keeps each Claude account's last successful usage across
/// relaunches, so the UI can show it instead of an error screen.
final class LastKnownUsageCacheTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "LastKnownUsageCacheTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func sample(fiveHour: Double) -> UsageData {
        UsageData(
            fiveHour: .init(percentage: fiveHour, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: .init(percentage: 65, resetsAt: nil),
            weeklyModels: [.init(modelName: "Fable", limit: .init(percentage: 3, resetsAt: nil))],
            extraUsage: ExtraUsageData(enabled: true, used: 5, limit: 100, currency: "USD")
        )
    }

    func testEmptyWhenNothingSaved() {
        XCTAssertTrue(LastKnownUsageCache.load(defaults: defaults).isEmpty)
    }

    func testRoundTripKeepsEveryField() throws {
        let id = UUID()
        let fetchedAt = Date(timeIntervalSince1970: 1_790_000_000)
        LastKnownUsageCache.save(sample(fiveHour: 36), for: id, at: fetchedAt, defaults: defaults)

        let entry = try XCTUnwrap(LastKnownUsageCache.entry(for: id, defaults: defaults))
        XCTAssertEqual(entry.fetchedAt, fetchedAt)
        XCTAssertEqual(entry.data.fiveHour?.percentage, 36)
        XCTAssertEqual(entry.data.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(entry.data.sevenDay?.percentage, 65)
        XCTAssertNil(entry.data.sevenDay?.resetsAt)
        XCTAssertEqual(entry.data.weeklyModels.first?.modelName, "Fable")
        XCTAssertEqual(entry.data.extraUsage?.currency, "USD")
    }

    func testAccountsAreKeptApartAndOverwritten() {
        let a = UUID(), b = UUID()
        LastKnownUsageCache.save(sample(fiveHour: 10), for: a, defaults: defaults)
        LastKnownUsageCache.save(sample(fiveHour: 20), for: b, defaults: defaults)
        LastKnownUsageCache.save(sample(fiveHour: 30), for: a, defaults: defaults)

        let entries = LastKnownUsageCache.load(defaults: defaults)
        XCTAssertEqual(entries[a]?.data.fiveHour?.percentage, 30)
        XCTAssertEqual(entries[b]?.data.fiveHour?.percentage, 20)
    }

    func testRetainDropsRemovedAccounts() {
        let kept = UUID(), removed = UUID()
        LastKnownUsageCache.save(sample(fiveHour: 10), for: kept, defaults: defaults)
        LastKnownUsageCache.save(sample(fiveHour: 20), for: removed, defaults: defaults)

        LastKnownUsageCache.retain(only: [kept], defaults: defaults)

        let entries = LastKnownUsageCache.load(defaults: defaults)
        XCTAssertNotNil(entries[kept])
        XCTAssertNil(entries[removed])
    }
}
