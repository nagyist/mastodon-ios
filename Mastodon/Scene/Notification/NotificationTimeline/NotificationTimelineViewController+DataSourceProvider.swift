//
//  NotificationTimelineViewController+DataSourceProvider.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-26.
//

import UIKit
import MastodonSDK

extension NotificationTimelineViewController: DataSourceProvider {
    var filterContext: MastodonSDK.Mastodon.Entity.FilterContext? {
        return .notifications
    }
    
    func didToggleContentWarningDisplayStatus(status: MastodonSDK.MastodonStatus) {
        tableView.reloadData()
    }
    
    func item(from source: DataSourceItem.Source) async -> DataSourceItem? {
        var _indexPath = source.indexPath
        if _indexPath == nil, let cell = source.tableViewCell {
            _indexPath = await self.indexPath(for: cell)
        }
        guard let indexPath = _indexPath else { return nil }
        
        guard let item = viewModel.diffableDataSource?.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        switch item {
        case .notification(let notificationItem):
            switch notificationItem {
            case .notification, .notificationGroup:
                let item: DataSourceItem? = {
                    //                guard feed.kind == .notificationAll || feed.kind == .notificationMentions else { return nil }
                    
                    if let notification = MastodonFeedItemCacheManager.shared.cachedItem(notificationItem) as? Mastodon.Entity.Notification {
                        let mastodonNotification = MastodonNotification.fromEntity(notification, relationship: nil)
                        return .notification(record: mastodonNotification)
                    } else {
                        return nil
                    }
                }()
                return item
            case .status:
                assertionFailure("unexpected item in notifications feed")
                return nil
            }
        case .filteredNotificationsInfo(let policy):
            return DataSourceItem.notificationBanner(policy: policy)
        case .bottomLoader, .feedLoader:
            return nil
        }
    }
    
    func update(status: MastodonStatus, intent: MastodonStatus.UpdateIntent) {
        Task {
            await viewModel.loadLatest()
        }
    }
    
    @MainActor
    private func indexPath(for cell: UITableViewCell) async -> IndexPath? {
        return tableView.indexPath(for: cell)
    }
}
