// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonCore
import MastodonSDK

protocol AccountNotificationTimelineViewControllerDelegate: AnyObject {
    func acceptRequest(_ viewController: AccountNotificationTimelineViewController, request: Mastodon.Entity.NotificationRequest, completion: @escaping (() -> Void))
    func dismissRequest(_ viewController: AccountNotificationTimelineViewController, request: Mastodon.Entity.NotificationRequest, completion: @escaping (() -> Void))
}

class AccountNotificationTimelineViewController: NotificationTimelineViewController {

    let request: Mastodon.Entity.NotificationRequest
    weak var delegate: AccountNotificationTimelineViewControllerDelegate?

    init(viewModel: NotificationTimelineViewModel, context: AppContext, coordinator: SceneCoordinator, notificationRequest: Mastodon.Entity.NotificationRequest) {
        self.request = notificationRequest

        super.init(viewModel: viewModel, context: context, coordinator: coordinator)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil, image: UIImage(systemName: "ellipsis.circle"), target: nil, action: nil, menu: menu())
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Actions

    //TODO: Localization
    func menu() -> UIMenu {
        let menu = UIMenu(children: [
            UIAction(title: "Accept", image: UIImage(systemName: "checkmark")) { [weak self] _ in
                guard let self else { return }

                coordinator.showLoading()
                self.delegate?.acceptRequest(self, request: request) {
                    self.navigationController?.popViewController(animated: true)
                }
                coordinator.hideLoading()
            },
            UIAction(title: "Dismiss", image: UIImage(systemName: "speaker.slash")) { [weak self] _ in
                guard let self else { return }

                coordinator.showLoading()
                self.delegate?.dismissRequest(self, request: request) {
                    self.navigationController?.popViewController(animated: true)
                }
                coordinator.hideLoading()
            }
        ])

        return menu
    }
}
