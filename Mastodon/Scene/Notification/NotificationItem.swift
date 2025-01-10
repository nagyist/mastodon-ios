//
//  NotificationItem.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/13.
//

import CoreData
import Foundation
import MastodonSDK

enum NotificationItem: Hashable {
    case filteredNotificationsInfo(policy: Mastodon.Entity.NotificationPolicy)
    case notification(MastodonFeedItemIdentifier)
    case feedLoader(MastodonFeedItemIdentifier)
    case bottomLoader
}
