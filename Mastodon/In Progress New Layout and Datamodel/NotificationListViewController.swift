// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import SwiftUI
import MastodonCore
import MastodonSDK
import Combine

class NotificationListViewController: UIHostingController<NotificationListView> {
    
    init() {
        let viewModel = NotificationListViewModel()
        let root = NotificationListView(viewModel: viewModel)
        super.init(rootView: root)
        
        viewModel.presentError = { error in
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.sceneCoordinator?.rootViewController?.topMost?.present(alert, animated: true)
        }
        
        viewModel.navigateToScene = { [weak self] scene, transition in
            guard let self else { return }
            Task { @MainActor in
                self.sceneCoordinator?.present(scene: scene, from: self, transition: transition)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented for NotificationListViewController")
    }
}

fileprivate enum ListType {
    case everything
    case mentions
    
    var pickerLabel: String {
        switch self {
        case .everything:
            "EVERYTHING"
        case .mentions:
            "MENTIONS"
        }
    }
    
    var feedKind: MastodonFeedKind {
        switch self {
        case .everything:
            return .notificationsAll
        case .mentions:
            return .notificationsMentionsOnly
        }
    }
}
extension ListType: Identifiable {
    var id: String {
        return pickerLabel
    }
}

struct NotificationListView: View {
    @ObservedObject private var viewModel: NotificationListViewModel
    
    fileprivate init(viewModel: NotificationListViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Picker(selection: $viewModel.displayedNotifications) {
                    ForEach(
                        [ListType.everything, .mentions]
                    ) {
                        Text($0.pickerLabel)
                            .tag($0)
                    }
                } label: {
                }
                .pickerStyle(.segmented)
                Spacer()
            }
            
            List {
                ForEach(viewModel.notificationItems) { item in
                    rowView(item)
                        .onAppear {
                            switch item {
                            case .groupedNotification(let viewModel):
                                viewModel.prepareForDisplay()
                            case .bottomLoader:
                                loadMore()
                            default:
                                break
                            }
                        }
                        .onTapGesture {
                            didTap(item: item)
                        }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.refreshFeedFromTop()
            }
        }
        
    }
    
    @ViewBuilder func rowView(_ notificationListItem: NotificationListItem) -> some View {
        switch notificationListItem {
        case .bottomLoader:
            HStack {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            }
        case .filteredNotificationsInfo:
            Text("filtered notifications not yet implemented")
        case .notification(let feedItemIdentifier):
            Text("obsolete item")
        case .groupedNotification(let viewModel):
            // TODO: implement unread using Mastodon.Entity.Marker
            _NotificationRowView(viewModel: viewModel)
        }
    }
    
    func loadMore() {
        viewModel.loadOlder()
    }
    
    func didTap(item: NotificationListItem) {
        switch item {
        case .filteredNotificationsInfo:
            return
        case .notification(let identifier):
            if let notificationInfo =
                MastodonFeedItemCacheManager.shared.cachedItem(identifier) as? NotificationInfo {
                guard let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value, let me = authBox.cachedAccount else { return }
                switch (notificationInfo.type, notificationInfo.isGrouped) {
                case (.follow, false):
                    guard let notificationAuthor = notificationInfo.primaryAuthorAccount else { return }
                    viewModel.navigateToScene(.profile(.notMe(me: me, displayAccount: notificationAuthor, relationship: MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: notificationAuthor.id))), .show)
                case (.follow, true):
                    viewModel.navigateToScene(.follower(viewModel: FollowerListViewModel(authenticationBox: authBox, domain: me.domain, userID: me.id)), .show)
                default:
                    break
                }
            }
        case .groupedNotification(let notificationViewModel):
            notificationViewModel.defaultNavigation?()
        default:
            return
        }
    }
}

@MainActor
fileprivate class NotificationListViewModel: ObservableObject {
    
    
    @Published var displayedNotifications: ListType = .everything {
        didSet {
            createNewFeedLoader()
        }
    }
    @Published var notificationItems: [NotificationListItem] = []
    
    private var feedSubscription: AnyCancellable?
    private var feedLoader = GroupedNotificationFeedLoader(kind: .notificationsAll, navigateToScene: { _, _ in }, presentError: { _ in })
    
    fileprivate var navigateToScene: ((SceneCoordinator.Scene, SceneCoordinator.Transition)->()) = { _,_ in }
    {
        didSet {
            createNewFeedLoader()
        }
    }
    fileprivate var presentError: ((Error)->()) = { _ in } {
        didSet {
            createNewFeedLoader()
        }
    }
    
    private func createNewFeedLoader() {
        feedLoader = GroupedNotificationFeedLoader(kind: displayedNotifications.feedKind, navigateToScene: navigateToScene, presentError: presentError)
        feedSubscription = feedLoader.$records
            .receive(on: DispatchQueue.main)
            .sink { [weak self] records in
                var updatedItems = records.allRecords.map {
                    NotificationListItem.groupedNotification($0)
                }
                if records.canLoadOlder {
                    updatedItems.append(.bottomLoader)
                }
                // TODO: add the filtered notifications announcement if needed
                self?.notificationItems = updatedItems
            }
        feedLoader.loadMore(olderThan: nil, newerThan: nil)
    }
    
    public func refreshFeedFromTop() async {
        let newestKnown = feedLoader.records.allRecords.first?.newestID
        await feedLoader.asyncLoadMore(olderThan: nil, newerThan: newestKnown)
    }
    
    public func loadOlder() {
        let oldestKnown = feedLoader.records.allRecords.last?.oldestID
        feedLoader.loadMore(olderThan: oldestKnown, newerThan: nil)
    }
}

extension NotificationListItem {
    static func fromMastodonFeedItemIdentifier(_ feedItem: MastodonFeedItemIdentifier) -> NotificationListItem? {
        switch feedItem {
        case .notification, .notificationGroup:
            return .notification(feedItem)
        case .status:
            return nil
        }
    }
}
