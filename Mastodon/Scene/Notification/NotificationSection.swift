//
//  NotificationSection.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/13.
//

import Combine
import CoreData
import CoreDataStack
import Foundation
import MastodonSDK
import UIKit
import MetaTextKit
import MastodonMeta
import MastodonAsset
import MastodonCore
import MastodonUI
import MastodonLocalization

enum NotificationSection: Equatable, Hashable {
    case main
}

extension NotificationSection {
    
    struct Configuration {
        let authenticationBox: MastodonAuthenticationBox
        weak var notificationTableViewCellDelegate: NotificationTableViewCellDelegate?
        let filterContext: Mastodon.Entity.FilterContext?
    }
    
    static func diffableDataSource(
        tableView: UITableView,
        configuration: Configuration
    ) -> UITableViewDiffableDataSource<NotificationSection, NotificationListItem> {
        tableView.register(NotificationTableViewCell.self, forCellReuseIdentifier: String(describing: NotificationTableViewCell.self))
        tableView.register(AccountWarningNotificationCell.self, forCellReuseIdentifier: AccountWarningNotificationCell.reuseIdentifier)
        tableView.register(TimelineBottomLoaderTableViewCell.self, forCellReuseIdentifier: String(describing: TimelineBottomLoaderTableViewCell.self))
        tableView.register(NotificationFilteringBannerTableViewCell.self, forCellReuseIdentifier: NotificationFilteringBannerTableViewCell.reuseIdentifier)

        return UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, item -> UITableViewCell? in
            switch item {
            case .notification(let notificationItem):
                if let notification = MastodonFeedItemCacheManager.shared.cachedItem(notificationItem) as? Mastodon.Entity.Notification, let accountWarning = notification.accountWarning {
                    let cell = tableView.dequeueReusableCell(withIdentifier: AccountWarningNotificationCell.reuseIdentifier, for: indexPath) as! AccountWarningNotificationCell
                    cell.configure(with: accountWarning)
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: NotificationTableViewCell.self), for: indexPath) as! NotificationTableViewCell
                    configure(
                        tableView: tableView,
                        cell: cell,
                        itemIdentifier: notificationItem,
                        configuration: configuration
                    )
                    return cell
                }

            case .middleLoader:
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelineBottomLoaderTableViewCell.self), for: indexPath) as! TimelineBottomLoaderTableViewCell
                cell.activityIndicatorView.startAnimating()
                return cell
            case .bottomLoader:
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelineBottomLoaderTableViewCell.self), for: indexPath) as! TimelineBottomLoaderTableViewCell
                cell.activityIndicatorView.startAnimating()
                return cell

            case .filteredNotificationsInfo(let policy):
                let cell = tableView.dequeueReusableCell(withIdentifier: NotificationFilteringBannerTableViewCell.reuseIdentifier, for: indexPath) as! NotificationFilteringBannerTableViewCell
                cell.configure(with: policy)

                return cell
            }
        }
    }
}

extension NotificationSection {
    
    @MainActor
    static func configure(
        tableView: UITableView,
        cell: NotificationTableViewCell,
        itemIdentifier: MastodonFeedItemIdentifier,
        configuration: Configuration
    ) {
        guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { assertionFailure(); return }
        StatusSection.setupStatusPollDataSource(
            authenticationBox: configuration.authenticationBox,
            statusView: cell.notificationView.statusView
        )
        
        StatusSection.setupStatusPollDataSource(
            authenticationBox: configuration.authenticationBox,
            statusView: cell.notificationView.quoteStatusView
        )
        
        cell.configure(
            tableView: tableView,
            notificationIdentifier: itemIdentifier,
            delegate: configuration.notificationTableViewCellDelegate,
            authenticationBox: configuration.authenticationBox
        )
    }
    
}

