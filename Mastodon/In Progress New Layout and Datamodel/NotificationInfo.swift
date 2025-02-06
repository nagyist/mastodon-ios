// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import Foundation
import MastodonCore
import MastodonSDK

protocol NotificationInfo {
    var id: String { get }
    var newestNotificationID: String { get }
    var oldestNotificationID: String { get }
    var type: Mastodon.Entity.NotificationType { get }
    var isGrouped: Bool { get }
    var notificationsCount: Int { get }
    var authorsCount: Int { get }
    var primaryAuthorAccount: Mastodon.Entity.Account? { get }
    var authorName: Mastodon.Entity.NotificationType.AuthorName? { get }
    var authorAvatarUrls: [URL] { get }
    func availableRelationshipElement() async -> RelationshipElement?
    func fetchRelationshipElement() async -> RelationshipElement
    var ruleViolationReport: Mastodon.Entity.Report? { get }
    var relationshipSeveranceEvent: Mastodon.Entity.RelationshipSeveranceEvent?
    { get }
}
extension NotificationInfo {
    var authorsDescription: String? {
        switch authorName {
        case .me, .none:
            return nil
        case .other(let name):
            if authorsCount > 1 {
                return "\(name) and \(authorsCount - 1) others"
            } else {
                return name
            }
        }
    }
    var avatarCount: Int {
        min(authorsCount, 8)
    }
    var isGrouped: Bool {
        return authorsCount > 1
    }
}

struct GroupedNotificationInfo: NotificationInfo {
    func availableRelationshipElement() async -> RelationshipElement? {
        return relationshipElement
    }

    func fetchRelationshipElement() async -> RelationshipElement {
        return relationshipElement
    }

    let id: String
    let oldestNotificationID: String
    let newestNotificationID: String

    let type: MastodonSDK.Mastodon.Entity.NotificationType

    let authorsCount: Int

    let notificationsCount: Int

    let primaryAuthorAccount: MastodonSDK.Mastodon.Entity.Account?

    let authorName: Mastodon.Entity.NotificationType.AuthorName?

    let authorAvatarUrls: [URL]

    var relationshipElement: RelationshipElement {
        switch type {
        case .follow, .followRequest:
            if let primaryAuthorAccount {
                return .unfetched(type, accountID: primaryAuthorAccount.id)
            } else {
                return .error(nil)
            }
        default:
            return .noneNeeded
        }
    }

    let statusViewModel: Mastodon.Entity.Status.ViewModel?
    let ruleViolationReport: Mastodon.Entity.Report?
    let relationshipSeveranceEvent: Mastodon.Entity.RelationshipSeveranceEvent?

    let defaultNavigation: (() -> Void)?
}

extension Mastodon.Entity.Notification: NotificationInfo {

    var oldestNotificationID: String {
        return id
    }
    var newestNotificationID: String {
        return id
    }

    var authorsCount: Int { 1 }
    var notificationsCount: Int { 1 }
    var primaryAuthorAccount: Mastodon.Entity.Account? { account }
    var authorName: Mastodon.Entity.NotificationType.AuthorName? {
        .other(named: account.displayNameWithFallback)
    }
    var authorAvatarUrls: [URL] {
        if let domain = account.domain {
            return [account.avatarImageURLWithFallback(domain: domain)]
        } else if let url = account.avatarImageURL() {
            return [url]
        } else {
            return []
        }
    }

    @MainActor
    func availableRelationshipElement() -> RelationshipElement? {
        if let relationship = MastodonFeedItemCacheManager.shared
            .currentRelationship(toAccount: account.id)
        {
            return relationship.relationshipElement
        }
        return nil
    }

    @MainActor
    func fetchRelationshipElement() async -> RelationshipElement {
        do {
            try await fetchRelationship()
            if let available = availableRelationshipElement() {
                return available
            } else {
                return .noneNeeded
            }
        } catch {
            return .error(error)
        }
    }
    private func fetchRelationship() async throws {
        guard
            let authBox = await AuthenticationServiceProvider.shared
                .currentActiveUser.value
        else { return }
        let relationship = try await APIService.shared.relationship(
            forAccounts: [account], authenticationBox: authBox)
        await MastodonFeedItemCacheManager.shared.addToCache(relationship)
    }
}

extension Mastodon.Entity.NotificationGroup: NotificationInfo {

    var newestNotificationID: String {
        return pageNewestID ?? "\(mostRecentNotificationID)"
    }
    var oldestNotificationID: String {
        return pageOldestID ?? "\(mostRecentNotificationID)"
    }

    @MainActor
    var primaryAuthorAccount: Mastodon.Entity.Account? {
        guard let firstAccountID = sampleAccountIDs.first else { return nil }
        return MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID)
    }

    var authorsCount: Int { notificationsCount }

    @MainActor
    var authorName: Mastodon.Entity.NotificationType.AuthorName? {
        guard let firstAccountID = sampleAccountIDs.first,
            let firstAccount = MastodonFeedItemCacheManager.shared.fullAccount(
                firstAccountID)
        else { return .none }
        return .other(named: firstAccount.displayNameWithFallback)
    }

    @MainActor
    var authorAvatarUrls: [URL] {
        return
            sampleAccountIDs
            .prefix(avatarCount)
            .compactMap { accountID in
                let account: NotificationAuthor? =
                    MastodonFeedItemCacheManager.shared.fullAccount(accountID)
                    ?? MastodonFeedItemCacheManager.shared.partialAccount(
                        accountID)
                return account?.avatarURL
            }
    }

    @MainActor
    var firstAccount: NotificationAuthor? {
        guard let firstAccountID = sampleAccountIDs.first else { return nil }
        let firstAccount: NotificationAuthor? =
            MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID)
            ?? MastodonFeedItemCacheManager.shared.partialAccount(
                firstAccountID)
        return firstAccount
    }

    @MainActor
    func availableRelationshipElement() -> RelationshipElement? {
        guard authorsCount == 1 && type == .follow else { return .noneNeeded }
        guard let firstAccountID = sampleAccountIDs.first else {
            return .noneNeeded
        }
        if let relationship = MastodonFeedItemCacheManager.shared
            .currentRelationship(toAccount: firstAccountID)
        {
            return relationship.relationshipElement
        }
        return nil
    }

    @MainActor
    func fetchRelationshipElement() async -> RelationshipElement {
        do {
            try await fetchRelationship()
            if let available = availableRelationshipElement() {
                return available
            } else {
                return .noneNeeded
            }
        } catch {
            return .error(error)
        }
    }

    func fetchRelationship() async throws {
        assert(
            notificationsCount == 1,
            "one relationship cannot be assumed representative of \(notificationsCount) notifications"
        )
        guard let firstAccountId = sampleAccountIDs.first,
            let authBox = await AuthenticationServiceProvider.shared
                .currentActiveUser.value
        else { return }
        if let relationship = try await APIService.shared.relationship(
            forAccountIds: [firstAccountId], authenticationBox: authBox
        ).value.first {
            await MastodonFeedItemCacheManager.shared.addToCache(relationship)
        }
    }

    var statusViewModel: MastodonSDK.Mastodon.Entity.Status.ViewModel? {
        return nil
    }
}
