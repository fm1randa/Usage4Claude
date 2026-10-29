//
//  Account.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-02-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    var sessionKey: String
    var organizationId: String
    var organizationName: String
    var alias: String?
    let createdAt: Date
    var provider: ProviderType
    /// 登录用户的账号 uuid（与 organizationId 一起唯一标识一个账户；旧数据为 nil，下次刷新时回填）
    var accountUuid: String?
    /// 登录用户的 email（同上；同组织多个成员时用于区分显示）
    var email: String?

    var displayName: String {
        if let alias = alias, !alias.isEmpty {
            return alias
        }
        return AccountIdentity.defaultDisplayName(organizationName: organizationName, email: AccountIdentity.effectiveEmail(of: self))
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id, sessionKey, organizationId, organizationName, alias, createdAt, provider, accountUuid, email
    }

    // MARK: - Codable

    // 自定义解码：旧版 JSON 不含 provider 字段时默认为 .claude，确保旧账号数据零迁移
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionKey = try container.decode(String.self, forKey: .sessionKey)
        organizationId = try container.decode(String.self, forKey: .organizationId)
        organizationName = try container.decode(String.self, forKey: .organizationName)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        provider = try container.decodeIfPresent(ProviderType.self, forKey: .provider) ?? .claude
        // 旧版 JSON 不含身份字段：保持 nil，由刷新路径回填
        accountUuid = try container.decodeIfPresent(String.self, forKey: .accountUuid)
        email = try container.decodeIfPresent(String.self, forKey: .email)
    }

    // MARK: - Initialization

    init(
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        alias: String? = nil,
        provider: ProviderType = .claude,
        accountUuid: String? = nil,
        email: String? = nil
    ) {
        self.id = UUID()
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.alias = alias
        self.createdAt = Date()
        self.provider = provider
        self.accountUuid = AccountIdentity.normalized(accountUuid)
        self.email = AccountIdentity.normalized(email)
    }

    init(
        id: UUID,
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        alias: String?,
        createdAt: Date,
        provider: ProviderType = .claude,
        accountUuid: String? = nil,
        email: String? = nil
    ) {
        self.id = id
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.alias = alias
        self.createdAt = createdAt
        self.provider = provider
        self.accountUuid = AccountIdentity.normalized(accountUuid)
        self.email = AccountIdentity.normalized(email)
    }

    // MARK: - Equatable

    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }
}
