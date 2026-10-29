//
//  AccountIdentityTests.swift
//  Usage4ClaudeCoreTests
//
//  覆盖「用户 + 组织」账户身份判定。核心回归场景：同一组织的两个成员先后登录，
//  后者曾经因为只按组织去重而覆盖前者。
//

import XCTest
@testable import Usage4ClaudeCore

final class AccountIdentityTests: XCTestCase {

    private let org = "org-agidesk"

    private func makeAccount(
        sessionKey: String,
        organizationId: String? = nil,
        organizationName: String = "Agidesk",
        accountUuid: String? = nil,
        email: String? = nil
    ) -> Account {
        Account(
            sessionKey: sessionKey,
            organizationId: organizationId ?? org,
            organizationName: organizationName,
            accountUuid: accountUuid,
            email: email
        )
    }

    // MARK: - 同组织不同成员

    func testDifferentUsersInSameOrgAreDistinctByUuid() {
        let a = makeAccount(sessionKey: "key-a", accountUuid: "uuid-a", email: "a@agidesk.com.br")
        let b = makeAccount(sessionKey: "key-b", accountUuid: "uuid-b", email: "b@agidesk.com.br")
        XCTAssertFalse(AccountIdentity.isSameAccount(a, b))
        XCTAssertNil(AccountIdentity.indexOfExisting(b, in: [a]))
    }

    func testDifferentUsersInSameOrgAreDistinctByEmail() {
        let a = makeAccount(sessionKey: "key-a", email: "filipe.pereira@agidesk.com.br")
        let b = makeAccount(sessionKey: "key-b", email: "filipe.claude@agidesk.com.br")
        XCTAssertFalse(AccountIdentity.isSameAccount(a, b))
    }

    // MARK: - 同一用户重新登录

    func testSameUserSameOrgMatchesByUuid() {
        let existing = makeAccount(sessionKey: "old", accountUuid: "UUID-A")
        let relogin = makeAccount(sessionKey: "new", accountUuid: "uuid-a")
        XCTAssertTrue(AccountIdentity.isSameAccount(existing, relogin))
    }

    func testSameUserSameOrgMatchesByEmailIgnoringCase() {
        let existing = makeAccount(sessionKey: "old", email: "Filipe.Claude@agidesk.com.br")
        let relogin = makeAccount(sessionKey: "new", email: "filipe.claude@agidesk.com.br ")
        XCTAssertTrue(AccountIdentity.isSameAccount(existing, relogin))
    }

    func testSameUserDifferentOrgsAreDistinct() {
        let a = makeAccount(sessionKey: "key", organizationId: "org-1", accountUuid: "uuid-a")
        let b = makeAccount(sessionKey: "key", organizationId: "org-2", accountUuid: "uuid-a")
        XCTAssertFalse(AccountIdentity.isSameAccount(a, b))
    }

    // MARK: - 旧版条目（无身份）

    func testLegacyEntryWithSameCredentialMatches() {
        let legacy = makeAccount(sessionKey: "same-key")
        let relogin = makeAccount(sessionKey: "same-key", accountUuid: "uuid-a")
        XCTAssertTrue(AccountIdentity.isSameAccount(legacy, relogin))
    }

    func testLegacyEntryWithDifferentCredentialIsKeptSeparate() {
        // 身份未知时不能假定是同一个人：宁可多一个条目，也不覆盖另一个成员的凭据
        let legacy = makeAccount(sessionKey: "key-a")
        let other = makeAccount(sessionKey: "key-b", accountUuid: "uuid-b", email: "b@agidesk.com.br")
        XCTAssertFalse(AccountIdentity.isSameAccount(legacy, other))
    }

    func testLegacyOAuthEntryInfersEmailFromOrganizationName() {
        // 旧版 OAuth 条目把 email 存在 organizationName 里
        let legacy = makeAccount(sessionKey: "sk-ant-ort01-old", organizationName: "filipe.pereira@agidesk.com.br")
        XCTAssertEqual(AccountIdentity.effectiveEmail(of: legacy), "filipe.pereira@agidesk.com.br")

        let sameUser = makeAccount(sessionKey: "sk-ant-ort01-new", email: "filipe.pereira@agidesk.com.br")
        let otherUser = makeAccount(sessionKey: "sk-ant-ort01-b", email: "filipe.claude@agidesk.com.br")
        XCTAssertTrue(AccountIdentity.isSameAccount(legacy, sameUser))
        XCTAssertFalse(AccountIdentity.isSameAccount(legacy, otherUser))
    }

    // MARK: - merge

    func testMergeKeepsIdAndAliasAndReplacesCredential() {
        var existing = makeAccount(sessionKey: "old", organizationName: "a@agidesk.com.br")
        existing.alias = "Work"
        let incoming = makeAccount(sessionKey: "new", accountUuid: "uuid-a", email: "a@agidesk.com.br")

        let merged = AccountIdentity.merge(incoming, into: existing)

        XCTAssertEqual(merged.id, existing.id)
        XCTAssertEqual(merged.alias, "Work")
        XCTAssertEqual(merged.sessionKey, "new")
        XCTAssertEqual(merged.organizationName, "Agidesk")
        XCTAssertEqual(merged.accountUuid, "uuid-a")
        XCTAssertEqual(merged.email, "a@agidesk.com.br")
    }

    func testMergeNeverClearsKnownIdentity() {
        let existing = makeAccount(sessionKey: "old", accountUuid: "uuid-a", email: "a@agidesk.com.br")
        let incoming = makeAccount(sessionKey: "old")
        let merged = AccountIdentity.merge(incoming, into: existing)
        XCTAssertEqual(merged.accountUuid, "uuid-a")
        XCTAssertEqual(merged.email, "a@agidesk.com.br")
    }

    // MARK: - backfill

    func testBackfillFillsMissingIdentityAndReplacesEmailPlaceholderName() {
        let legacy = makeAccount(sessionKey: "sk-ant-ort01-x", organizationName: "a@agidesk.com.br")
        let updated = AccountIdentity.backfill(legacy, accountUuid: "uuid-a", email: "a@agidesk.com.br", organizationName: "Agidesk")
        XCTAssertEqual(updated?.id, legacy.id)
        XCTAssertEqual(updated?.accountUuid, "uuid-a")
        XCTAssertEqual(updated?.email, "a@agidesk.com.br")
        XCTAssertEqual(updated?.organizationName, "Agidesk")
    }

    func testBackfillKeepsRealOrganizationName() {
        let legacy = makeAccount(sessionKey: "key", organizationName: "Agidesk")
        let updated = AccountIdentity.backfill(legacy, accountUuid: "uuid-a", email: "a@agidesk.com.br", organizationName: "Other")
        XCTAssertEqual(updated?.organizationName, "Agidesk")
    }

    func testBackfillReturnsNilWhenNothingChanges() {
        let account = makeAccount(sessionKey: "key", accountUuid: "uuid-a", email: "a@agidesk.com.br")
        XCTAssertNil(AccountIdentity.backfill(account, accountUuid: "uuid-z", email: "z@x.com", organizationName: nil))
        XCTAssertFalse(AccountIdentity.needsBackfill(account))
    }

    // MARK: - 显示名

    func testDisplayNameIncludesEmailWhenKnown() {
        let account = makeAccount(sessionKey: "key", email: "filipe.claude@agidesk.com.br")
        XCTAssertEqual(account.displayName, "Agidesk (filipe.claude@agidesk.com.br)")
    }

    func testDisplayNameWithoutIdentityIsOrganizationName() {
        XCTAssertEqual(makeAccount(sessionKey: "key").displayName, "Agidesk")
    }

    func testDisplayNameForLegacyOAuthEntryIsJustTheEmail() {
        let legacy = makeAccount(sessionKey: "key", organizationName: "a@agidesk.com.br")
        XCTAssertEqual(legacy.displayName, "a@agidesk.com.br")
    }

    func testAliasWins() {
        var account = makeAccount(sessionKey: "key", email: "a@agidesk.com.br")
        account.alias = "Mine"
        XCTAssertEqual(account.displayName, "Mine")
    }

    // MARK: - 持久化兼容

    func testLegacyJSONDecodesWithoutIdentityFields() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","sessionKey":"key","organizationId":"org","organizationName":"Agidesk","createdAt":0}
        """
        let account = try JSONDecoder().decode(Account.self, from: Data(json.utf8))
        XCTAssertNil(account.accountUuid)
        XCTAssertNil(account.email)
        XCTAssertEqual(account.provider, .claude)
        XCTAssertTrue(AccountIdentity.needsBackfill(account))
    }

    func testIdentityRoundTripsThroughCodable() throws {
        let account = makeAccount(sessionKey: "key", accountUuid: "uuid-a", email: "a@agidesk.com.br")
        let decoded = try JSONDecoder().decode(Account.self, from: JSONEncoder().encode(account))
        XCTAssertEqual(decoded.accountUuid, "uuid-a")
        XCTAssertEqual(decoded.email, "a@agidesk.com.br")
    }
}
