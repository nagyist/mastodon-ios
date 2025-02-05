// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import Foundation
import Combine
import MastodonSDK

@MainActor
class NotificationRowViewModel: ObservableObject {
    let feedItemIdentifier: MastodonFeedItemIdentifier
    let type: Mastodon.Entity.NotificationType
    let postViewModel: Mastodon.Entity.Status.ViewModel?
    @Published var isUnread: Bool
    fileprivate let notificationInfo: NotificationInfo?
    let grouped: Bool
    let authorAvatarUrls: [URL]
    let authorsDescription: String
    let authorName: Mastodon.Entity.NotificationType.AuthorName?
    
    static func viewModel(feedItemIdentifier: MastodonFeedItemIdentifier, isUnread: Bool) -> NotificationRowViewModel {
        guard let notificationInfo = MastodonFeedItemCacheManager.shared.cachedItem(feedItemIdentifier) as? NotificationInfo else { return MissingNotificationViewModel(nil, feedItemIdentifier: feedItemIdentifier, isUnread: false) }
        switch notificationInfo.type {
//        case .follow:
//            return FollowNotificationViewModel(notificationInfo, feedItemIdentifier: feedItemIdentifier, isUnread: isUnread)
        case .status, .reblog, .mention, .favourite:
            return StatusNotificationViewModel(notificationInfo, feedItemIdentifier: feedItemIdentifier, isUnread: isUnread)
        default:
            return NotificationRowViewModel(notificationInfo, feedItemIdentifier: feedItemIdentifier, isUnread: isUnread)
        }
    }
    
    init(_ notification: NotificationInfo?, feedItemIdentifier: MastodonFeedItemIdentifier, isUnread: Bool) {
        self.notificationInfo = notification
        self.type = notification?.type ?? ._other("missing")
        self.feedItemIdentifier = feedItemIdentifier
        self.postViewModel = nil //MastodonFeedItemCacheManager.shared.statusViewModel(associatedWith: feedItemIdentifier)
        self.isUnread = isUnread
        let item = MastodonFeedItemCacheManager.shared.cachedItem(feedItemIdentifier) as? NotificationInfo
        grouped = item?.isGrouped ?? false
        authorName = item?.authorName
        authorsDescription = item?.authorsDescription ?? ""
        authorAvatarUrls = item?.authorAvatarUrls ?? []
    }
}

class MissingNotificationViewModel: NotificationRowViewModel {
}

//class FollowNotificationViewModel: NotificationRowViewModel {
//    @Published var followButtonAction: RelationshipElement = .unfetched(<#Mastodon.Entity.NotificationType#>, accountID: <#String#>)
//
//    init(_ notification: NotificationInfo, feedItemIdentifier: MastodonFeedItemIdentifier, isUnread: Bool) {
//        assert(notification.type == .follow)
//        super.init(notification, feedItemIdentifier: feedItemIdentifier, isUnread: isUnread)
//        if notification.type == .follow && !notification.isGrouped {
//            followButtonAction = .fetching
//            print("about to fetch for \(notification.authorName)")
//            updateAvailableFollowAction()
//        } else {
//            followButtonAction = .noneNeeded
//        }
//    }
//    
//    private func updateAvailableFollowAction() {
//        Task {
//            guard let notificationInfo else { followButtonAction = .noneNeeded; return }
//            if let followAction = await notificationInfo.availableFollowAction() {
//                print("had cached answer for \(notificationInfo.authorName)")
//                followButtonAction = followAction
//            } else {
//                print("fetching relationship to derive answer for \(notificationInfo.authorName)")
//                followButtonAction = await notificationInfo.fetchAvailableFollowAction()
//            }
//        }
//    }
//}

class StatusNotificationViewModel: NotificationRowViewModel {
    let postedContent: Mastodon.Entity.Status? // TODO: make this non-optional eventually
    
    override init(_ notification: (any NotificationInfo)?, feedItemIdentifier: MastodonFeedItemIdentifier, isUnread: Bool) {
        postedContent = MastodonFeedItemCacheManager.shared.filterableStatus(associatedWith: feedItemIdentifier)
        assert(postedContent != nil)
        super.init(notification, feedItemIdentifier: feedItemIdentifier, isUnread: isUnread)
    }
}

