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
        viewModel.navigateToScene = { [weak self] scene, transition in
            guard let self else { return }
            self.sceneCoordinator?.present(scene: scene, from: self, transition: transition)
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
                        .onTapGesture {
                            didTap(item: item)
                        }
                }
            }
            .listStyle(.plain)
        }
        
    }
    
    @ViewBuilder func rowView(_ notificationListItem: NotificationListItem) -> some View {
        switch notificationListItem {
        case .bottomLoader, .middleLoader:
            Text("loader not yet implemented")
        case .filteredNotificationsInfo:
            Text("filtered notifications not yet implemented")
        case .notification(let feedItemIdentifier):
            // TODO: implement unread using Mastodon.Entity.Marker
            let viewModel = NotificationRowViewModel.viewModel(feedItemIdentifier: feedItemIdentifier, isUnread: false)
            GroupedNotificationRowView(viewModel: viewModel)
        }
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
                    viewModel.navigateToScene?(.profile(.notMe(me: me, displayAccount: notificationAuthor, relationship: MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: notificationAuthor.id))), .show)
                case (.follow, true):
                    viewModel.navigateToScene?(.follower(viewModel: FollowerListViewModel(authenticationBox: authBox, domain: me.domain, userID: me.id)), .show)
                default:
                    break
                }
            }
        default:
            return
        }
    }
}

@MainActor
fileprivate class NotificationListViewModel: ObservableObject {
    
    var navigateToScene: ((SceneCoordinator.Scene, SceneCoordinator.Transition)->())?
    
    @Published var displayedNotifications: ListType = .everything {
        didSet {
            createNewFeedLoader()
        }
    }
    @Published var notificationItems: [NotificationListItem] = []
    
    private var feedSubscription: AnyCancellable?
    private var feedLoader = MastodonFeedLoader(kind: .notificationsAll)
    
    init() {
        createNewFeedLoader()
    }
    
    private func createNewFeedLoader() {
        feedLoader = MastodonFeedLoader(kind: displayedNotifications.feedKind)
        feedSubscription = feedLoader.$records
            .receive(on: DispatchQueue.main)
            .sink { [weak self] records in
                // TODO: add middle loader and bottom loader?
                let updatedItems = records.compactMap {
                    NotificationListItem.fromMastodonFeedItemIdentifier($0)
                }
                // TODO: add the filtered notifications announcement if needed
                self?.notificationItems = updatedItems
            }
        feedLoader.loadMore(olderThan: nil, newerThan: nil)
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
