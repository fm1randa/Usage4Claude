//
//  AccountIdentity.swift
//  Usage4Claude
//
//  账户身份判定：一个 Claude 账户由「用户身份 + 组织」唯一确定，而不是只看组织。
//  同一组织下的两个成员（不同 email / 账号 uuid）必须能共存；同一用户在同一组织
//  重新登录时则复用并刷新原条目，不产生重复。纯函数，便于 SwiftPM 单测覆盖。
//

import Foundation

enum AccountIdentity {

    /// 去掉首尾空白，空字符串视为 nil（存储用，保留原始大小写）
    static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// 比较用的规范形式：去空白 + 小写
    static func comparable(_ value: String?) -> String? {
        normalized(value)?.lowercased()
    }

    /// 账户的有效 email。旧版 OAuth 账户没有 email 字段，但把 email 存进了
    /// organizationName（作为显示名），这里据此推断，免得旧条目在回填前无法区分。
    static func effectiveEmail(of account: Account) -> String? {
        if let email = normalized(account.email) { return email }
        if let name = normalized(account.organizationName), looksLikeEmail(name) {
            return name
        }
        return nil
    }

    static func looksLikeEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !value.contains(" ")
    }

    /// 未设别名时的显示名：知道 email 且与组织名不同则附在组织名后，
    /// 让同组织的多个成员在菜单/设置里可区分，例如 "Agidesk (filipe.claude@agidesk.com.br)"
    static func defaultDisplayName(organizationName: String, email: String?) -> String {
        guard let email = normalized(email) else { return organizationName }
        guard let org = normalized(organizationName) else { return email }
        if org.lowercased() == email.lowercased() { return org }
        return "\(org) (\(email))"
    }

    /// 两个条目是否代表同一个账户（同一用户 + 同一组织）
    ///
    /// - 组织不同 → 不同账户
    /// - 双方都有账号 uuid → 以 uuid 为准
    /// - 双方都有 email → 以 email 为准（忽略大小写）
    /// - 身份信息不全（旧条目尚未回填）→ 只有凭据完全相同才视为同一账户；
    ///   否则保守地当成不同账户：多一个可手动删除的条目，远好过把另一个成员的凭据覆盖掉
    static func isSameAccount(_ lhs: Account, _ rhs: Account) -> Bool {
        guard let lhsOrg = comparable(lhs.organizationId),
              let rhsOrg = comparable(rhs.organizationId),
              lhsOrg == rhsOrg else {
            return false
        }
        if let a = comparable(lhs.accountUuid), let b = comparable(rhs.accountUuid) {
            return a == b
        }
        if let a = comparable(effectiveEmail(of: lhs)), let b = comparable(effectiveEmail(of: rhs)) {
            return a == b
        }
        return !lhs.sessionKey.isEmpty && lhs.sessionKey == rhs.sessionKey
    }

    /// 在已有列表中查找与候选条目代表同一账户的位置
    static func indexOfExisting(_ candidate: Account, in accounts: [Account]) -> Int? {
        accounts.firstIndex { isSameAccount($0, candidate) }
    }

    /// 把新登录得到的条目合并进已有条目：保留 id / 别名 / 创建时间，
    /// 更新凭据与组织名，身份字段只用非空值覆盖（不会把已知身份清空）
    static func merge(_ incoming: Account, into existing: Account) -> Account {
        var merged = existing
        merged.sessionKey = incoming.sessionKey
        merged.organizationId = incoming.organizationId
        if let name = normalized(incoming.organizationName) {
            merged.organizationName = name
        }
        if let uuid = normalized(incoming.accountUuid) {
            merged.accountUuid = uuid
        }
        if let email = normalized(incoming.email) {
            merged.email = email
        }
        merged.provider = incoming.provider
        return merged
    }

    /// 回填身份信息（旧条目在下一次成功刷新后调用）。
    /// - Parameter organizationName: 真实组织名；仅当原组织名为空或只是 email 占位（旧版 OAuth 条目）时才替换
    /// - Returns: 更新后的条目；没有任何变化时返回 nil
    static func backfill(
        _ account: Account,
        accountUuid: String?,
        email: String?,
        organizationName: String?
    ) -> Account? {
        var updated = account
        if updated.accountUuid == nil, let uuid = normalized(accountUuid) {
            updated.accountUuid = uuid
        }
        if updated.email == nil, let email = normalized(email) {
            updated.email = email
        }
        if let name = normalized(organizationName), !looksLikeEmail(name) {
            let current = normalized(account.organizationName)
            if current == nil || current.map(looksLikeEmail) == true {
                updated.organizationName = name
            }
        }
        let changed = updated.accountUuid != account.accountUuid
            || updated.email != account.email
            || updated.organizationName != account.organizationName
        return changed ? updated : nil
    }

    /// 账户缺少身份信息（需要回填）
    static func needsBackfill(_ account: Account) -> Bool {
        account.accountUuid == nil || account.email == nil
    }
}
