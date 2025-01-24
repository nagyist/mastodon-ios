//
//  NotificationTimelineViewController.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-21.
//

import UIKit
import Combine
import CoreDataStack
import MastodonCore
import MastodonSDK
import MastodonLocalization

class NotificationTimelineViewController: UIViewController, MediaPreviewableViewController {
    
    let mediaPreviewTransitionController = MediaPreviewTransitionController()

    var disposeBag = Set<AnyCancellable>()
    var observations = Set<NSKeyValueObservation>()

    let viewModel: NotificationTimelineViewModel

    private(set) lazy var refreshControl: RefreshControl = {
        let refreshControl = RefreshControl()
        refreshControl.addTarget(self, action: #selector(NotificationTimelineViewController.refreshControlValueChanged(_:)), for: .valueChanged)
        return refreshControl
    }()
    
    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .secondarySystemBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        return tableView
    }()
    
    let cellFrameCache = NSCache<NSNumber, NSValue>()

    init(viewModel: NotificationTimelineViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        title = viewModel.scope.title
        view.backgroundColor = .secondarySystemBackground
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func didActOnFollowRequest(_ notification: MastodonNotification, approved: Bool) {
        viewModel.didActOnFollowRequest(notification, approved: approved)
    }
}

extension NotificationTimelineViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.pinToParent()
        
        tableView.delegate = self
        viewModel.setupDiffableDataSource(
            tableView: tableView,
            notificationTableViewCellDelegate: self
        )

        // setup refresh control
        tableView.refreshControl = refreshControl
        viewModel.didLoadLatest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshControl.endRefreshing()
        tableView.deselectRow(with: transitionCoordinator, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewModel.isLoadingLatest {
            let now = Date()
            if let timestamp = viewModel.lastAutomaticFetchTimestamp {
                if now.timeIntervalSince(timestamp) > 60 {
                    Task {
                        await viewModel.loadLatest()
                    }
                    viewModel.lastAutomaticFetchTimestamp = now
                }
            } else {
                Task {
                    await viewModel.loadLatest()
                }
                viewModel.lastAutomaticFetchTimestamp = now
            }
        }
    }
    
}

// MARK: - CellFrameCacheContainer
extension NotificationTimelineViewController: CellFrameCacheContainer {
    func keyForCache(tableView: UITableView, indexPath: IndexPath) -> NSNumber? {
        guard let diffableDataSource = viewModel.diffableDataSource else { return nil }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return nil }
        let key = NSNumber(value: item.hashValue)
        return key
    }
}

extension NotificationTimelineViewController {

    @objc private func refreshControlValueChanged(_ sender: RefreshControl) {
        Task {
            guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
            let policy = try? await APIService.shared.notificationPolicy(authenticationBox: authBox)
            viewModel.notificationPolicy = policy?.value

            await viewModel.loadLatest()
        }
    }

}

// MARK: - AuthContextProvider
extension NotificationTimelineViewController: AuthContextProvider {
    var authenticationBox: MastodonAuthenticationBox { AuthenticationServiceProvider.shared.currentActiveUser.value! }
}

// MARK: - UITableViewDelegate
extension NotificationTimelineViewController: UITableViewDelegate, AutoGenerateTableViewDelegate {
    // sourcery:inline:NotificationTimelineViewController.AutoGenerateTableViewDelegate

    // Generated using Sourcery
    // DO NOT EDIT
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        aspectTableView(tableView, didSelectRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return aspectTableView(tableView, contextMenuConfigurationForRowAt: indexPath, point: point)
    }

    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return aspectTableView(tableView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }

    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return aspectTableView(tableView, previewForDismissingContextMenuWithConfiguration: configuration)
    }

    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        aspectTableView(tableView, willPerformPreviewActionForMenuWith: configuration, animator: animator)
    }

    // sourcery:end
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let frame = retrieveCellFrame(tableView: tableView, indexPath: indexPath) else {
            return 300
        }
        return ceil(frame.height)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let sectionCount = viewModel.diffableDataSource?.numberOfSections(in: tableView) ?? 0
        let rowCount = viewModel.diffableDataSource?.tableView(tableView, numberOfRowsInSection: indexPath.section) ?? 0
        
        let isLastItem = indexPath.section == sectionCount - 1 && indexPath.row == rowCount - 1
        
        guard isLastItem, let item = viewModel.diffableDataSource?.itemIdentifier(for: indexPath) else {
            return
        }
        Task {
            await viewModel.loadMore(olderThan: item, newerThan: nil)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cacheCellFrame(tableView: tableView, didEndDisplaying: cell, forRowAt: indexPath)
    }
    
}

// MARK: - NotificationTableViewCellDelegate
extension NotificationTimelineViewController: NotificationTableViewCellDelegate { }

// MARK: - ScrollViewContainer
extension NotificationTimelineViewController: ScrollViewContainer {
    var scrollView: UIScrollView { tableView }
}

extension NotificationTimelineViewController {
    override var keyCommands: [UIKeyCommand]? {
        return navigationKeyCommands
    }
}

extension NotificationTimelineViewController: TableViewControllerNavigateable {
    
    func navigate(direction: TableViewNavigationDirection) {
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            // navigate up/down on the current selected item
            navigateToStatus(direction: direction, indexPath: indexPathForSelectedRow)
        } else {
            // set first visible item selected
            navigateToFirstVisibleStatus()
        }
    }
    
    private func navigateToStatus(direction: TableViewNavigationDirection, indexPath: IndexPath) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let items = diffableDataSource.snapshot().itemIdentifiers
        guard let selectedItem = diffableDataSource.itemIdentifier(for: indexPath),
              let selectedItemIndex = items.firstIndex(of: selectedItem) else {
            return
        }

        let _navigateToItem: NotificationListItem? = {
            var index = selectedItemIndex
            while 0..<items.count ~= index {
                index = {
                    switch direction {
                    case .up:   return index - 1
                    case .down: return index + 1
                    }
                }()
                guard 0..<items.count ~= index else { return nil }
                let item = items[index]
                
                guard Self.validNavigateableItem(item) else { continue }
                return item
            }
            return nil
        }()
        
        guard let item = _navigateToItem, let indexPath = diffableDataSource.indexPath(for: item) else { return }
        let scrollPosition: UITableView.ScrollPosition = overrideNavigationScrollPosition ?? Self.navigateScrollPosition(tableView: tableView, indexPath: indexPath)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: scrollPosition)
    }
    
    private func navigateToFirstVisibleStatus() {
        guard let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows else { return }
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        
        var visibleItems: [NotificationListItem] = indexPathsForVisibleRows.sorted().compactMap { indexPath in
            guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return nil }
            guard Self.validNavigateableItem(item) else { return nil }
            return item
        }
        if indexPathsForVisibleRows.first?.row != 0, visibleItems.count > 1 {
            // drop first when visible not the first cell of table
            visibleItems.removeFirst()
        }
        guard let item = visibleItems.first, let indexPath = diffableDataSource.indexPath(for: item) else { return }
        let scrollPosition: UITableView.ScrollPosition = overrideNavigationScrollPosition ?? Self.navigateScrollPosition(tableView: tableView, indexPath: indexPath)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: scrollPosition)
    }
    
    static func validNavigateableItem(_ item: NotificationListItem) -> Bool {
        switch item {
        case .notification:
            return true
        default:
            return false
        }
    }
    
    func open() {
        guard let indexPathForSelectedRow = tableView.indexPathForSelectedRow else { return }
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        guard let item = diffableDataSource.itemIdentifier(for: indexPathForSelectedRow) else { return }
        
        Task { @MainActor in
            switch item {
            case .notification(let notificationItem):
                let status: Mastodon.Entity.Status?
                let account: Mastodon.Entity.Account?
                switch notificationItem {
                case .notification:
                    guard let notification = MastodonFeedItemCacheManager.shared.cachedItem(notificationItem) as? Mastodon.Entity.Notification  else {
                        status = nil
                        account = nil
                        break
                    }
                    status = notification.status
                    account = notification.account
                    
                case .notificationGroup:
                    guard let notificationGroup = MastodonFeedItemCacheManager.shared.cachedItem(notificationItem) as? Mastodon.Entity.NotificationGroup  else {
                        status = nil
                        account = nil
                        break
                    }
                    if let statusID = notificationGroup.statusID {
                        status = MastodonFeedItemCacheManager.shared.cachedItem(.status(id: statusID)) as? Mastodon.Entity.Status
                    } else {
                        status = nil
                    }
                    if notificationGroup.sampleAccountIDs.count == 1, let theOneAccountID = notificationGroup.sampleAccountIDs.first {
                        account = MastodonFeedItemCacheManager.shared.fullAccount(theOneAccountID)
                    } else {
                        account = nil
                    }
                case .status:
                    assertionFailure("unexpected element in notifications feed")
                    status = nil
                    account = nil
                    break
                }
                
                if let status {
                    let threadViewModel = ThreadViewModel(
                        authenticationBox: self.authenticationBox,
                        optionalRoot: .root(context: .init(status: .fromEntity(status)))
                    )
                    _ = self.sceneCoordinator?.present(
                        scene: .thread(viewModel: threadViewModel),
                        from: self,
                        transition: .show
                    )
                } else if let account {
                    await DataSourceFacade.coordinateToProfileScene(provider: self, account: account)
                }
            default:
                break
            }
        }   // end Task
    }
    
    func navigateKeyCommandHandlerRelay(_ sender: UIKeyCommand) {
        navigateKeyCommandHandler(sender)
    }

}

//MARK: - UIScrollViewDelegate

extension NotificationTimelineViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        Self.scrollViewDidScrollToEnd(scrollView) {
            viewModel.loadOldestStateMachine.enter(NotificationTimelineViewModel.LoadOldestState.Loading.self)
        }
    }
}
