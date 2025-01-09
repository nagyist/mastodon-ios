//
//  NotificationView+ViewModel.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-21.
//

import UIKit
import Combine
import CoreDataStack
import MastodonSDK
import MastodonCore

extension NotificationTableViewCell {

    func configure(
        tableView: UITableView,
        notificationIdentifier: MastodonFeedItemIdentifier,
        delegate: NotificationTableViewCellDelegate?,
        authenticationBox: MastodonAuthenticationBox
    ) {
        if notificationView.frame == .zero {
            // set status view width
            notificationView.frame.size.width = tableView.frame.width - containerViewHorizontalMargin

            notificationView.statusView.frame.size.width = tableView.frame.width - containerViewHorizontalMargin
            notificationView.quoteStatusView.frame.size.width = tableView.frame.width - containerViewHorizontalMargin   // the as same width as statusView
        }
        
        notificationView.configure(notificationItem: notificationIdentifier)
        
        self.delegate = delegate
    }
    
}
