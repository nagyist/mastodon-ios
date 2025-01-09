//
//  NotificationTimelineViewModel.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-21.
//

import UIKit
import Combine
import CoreDataStack
import GameplayKit
import MastodonSDK
import MastodonCore
import MastodonLocalization

@MainActor
final class NotificationTimelineViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let authenticationBox: MastodonAuthenticationBox
    let scope: Scope
    var notificationPolicy: Mastodon.Entity.NotificationPolicy?
    let feedLoader: MastodonFeedLoader
    @Published var isLoadingLatest = false
    @Published var lastAutomaticFetchTimestamp: Date?
    
    // output
    var diffableDataSource: UITableViewDiffableDataSource<NotificationSection, NotificationItem>?
    var didLoadLatest = PassthroughSubject<Void, Never>()

    // bottom loader
    private(set) lazy var loadOldestStateMachine: GKStateMachine = {
        // exclude timeline middle fetcher state
        let stateMachine = GKStateMachine(states: [
            LoadOldestState.Initial(viewModel: self),
            LoadOldestState.Loading(viewModel: self),
            LoadOldestState.Fail(viewModel: self),
            LoadOldestState.Idle(viewModel: self),
            LoadOldestState.NoMore(viewModel: self),
        ])
        stateMachine.enter(LoadOldestState.Initial.self)
        return stateMachine
    }()
    
    @MainActor
    init(
        authenticationBox: MastodonAuthenticationBox,
        scope: Scope,
        notificationPolicy: Mastodon.Entity.NotificationPolicy? = nil
    ) {
        self.authenticationBox = authenticationBox
        self.scope = scope
        let useGroupedNotifications = false
        self.feedLoader = MastodonFeedLoader(authenticationBox: authenticationBox, kind: scope.feedKind, dedupePolicy: useGroupedNotifications ? .removeOldest : .omitNewest)
        self.notificationPolicy = notificationPolicy

        NotificationCenter.default.addObserver(self, selector: #selector(Self.notificationFilteringChanged(_:)), name: .notificationFilteringChanged, object: nil)
    }

    //MARK: - Notifications

    @objc func notificationFilteringChanged(_ notification: Notification) {
        Task { [weak self] in
            guard let self else { return }

            let policy = try await APIService.shared.notificationPolicy(authenticationBox: self.authenticationBox)
            self.notificationPolicy = policy.value

            await self.loadLatest()
        }
    }
}

extension NotificationTimelineViewModel {
    enum Scope: Hashable {
        case everything
        case mentions
        case fromAccount(Mastodon.Entity.Account)

        var title: String {
            switch self {
            case .everything:
                return L10n.Scene.Notification.Title.everything
            case .mentions:
                return L10n.Scene.Notification.Title.mentions
            case .fromAccount(let account):
                return "Notifications from \(account.displayName)"
            }
        }
        
        var feedKind: MastodonFeedKind {
            switch self {
            case .everything:
                return .notificationsAll
            case .mentions:
                return .notificationsMentionsOnly
            case .fromAccount(let account):
                return .notificationsWithAccount(account.id)
            }
        }
    }
}

extension NotificationTimelineViewModel {
    
    // load lastest
    func loadLatest() async {
        isLoadingLatest = true
        defer { isLoadingLatest = false }
        feedLoader.loadInitial(kind: scope.feedKind)
        didLoadLatest.send()
    }
    
    // load timeline gap
    func loadMore(item: NotificationItem) async {
        feedLoader.loadNext(kind: scope.feedKind)
    }
}
