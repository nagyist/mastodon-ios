// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonCore
import MastodonSDK
import MastodonLocalization

protocol AccountNotificationTimelineViewControllerDelegate: AnyObject {
    func acceptRequest(_ viewController: AccountNotificationTimelineViewController, request: Mastodon.Entity.NotificationRequest)
    func dismissRequest(_ viewController: AccountNotificationTimelineViewController, request: Mastodon.Entity.NotificationRequest)
}

class AccountNotificationTimelineViewController: NotificationTimelineViewController {

    let request: Mastodon.Entity.NotificationRequest
    weak var delegate: AccountNotificationTimelineViewControllerDelegate?

    init(viewModel: NotificationTimelineViewModel, notificationRequest: Mastodon.Entity.NotificationRequest) {
        self.request = notificationRequest

        super.init(viewModel: viewModel)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil, image: UIImage(systemName: "ellipsis.circle"), target: nil, action: nil, menu: menu())
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Actions

    func menu() -> UIMenu {
        let menu = UIMenu(children: [
            UIAction(title: L10n.Scene.Notification.FilteredNotification.accept, image: UIImage(systemName: "checkmark")) { [weak self] _ in
                guard let self else { return }

                self.sceneCoordinator?.showLoading()
                self.navigationController?.popViewController(animated: true)
                self.delegate?.acceptRequest(self, request: request)
                self.sceneCoordinator?.hideLoading()
            },
            UIAction(title: L10n.Scene.Notification.FilteredNotification.dismiss, image: NotificationRequestConstants.dismissIcon) { [weak self] _ in
                guard let self else { return }

                self.sceneCoordinator?.showLoading()
                self.navigationController?.popViewController(animated: true)
                self.delegate?.dismissRequest(self, request: request)
                self.sceneCoordinator?.hideLoading()
            }
        ])

        return menu
    }
}
