//
//  GroupedNotificationFeedLoader.swift
//  MastodonSDK
//
//  Created by Shannon Hughes on 1/31/25.
//

import Combine
import Foundation
import MastodonCore
import MastodonSDK
import UIKit
import os.log

@MainActor
final public class GroupedNotificationFeedLoader {
    
    struct FeedLoadResult {
        let allRecords: [_NotificationViewModel]
        let canLoadOlder: Bool
    }

    struct FeedLoadRequest: Equatable {
        let olderThan: String?
        let newerThan: String?

        var resultsInsertionPoint: InsertLocation {
            if olderThan != nil {
                return .end
            } else if newerThan != nil {
                return .start
            } else {
                return .replace
            }
        }
        enum InsertLocation {
            case start
            case end
            case replace
        }
    }

    private let logger = Logger(
        subsystem: "GroupedNotificationFeedLoader", category: "Data")
    private static let entryNotFoundMessage =
        "Failed to find suitable record. Depending on the context this might result in errors (data not being updated) or can be discarded (e.g. when there are mixed data sources where an entry might or might not exist)."

    @Published private(set) var records: FeedLoadResult = FeedLoadResult(allRecords: [], canLoadOlder: true)

    private let kind: MastodonFeedKind
    private let presentError: (Error) -> Void

    private var activeFilterBoxSubscription: AnyCancellable?

    public init(kind: MastodonFeedKind, presentError: @escaping (Error) -> Void)
    {
        self.kind = kind
        self.presentError = presentError

        activeFilterBoxSubscription = StatusFilterService.shared
            .$activeFilterBox
            .sink { filterBox in
                if filterBox != nil {
                    Task { [weak self] in
                        guard let self else { return }
                        let curAllRecords = self.records.allRecords
                        let curCanLoadOlder = self.records.canLoadOlder
                        await self.setRecordsAfterFiltering(curAllRecords, canLoadOlder: curCanLoadOlder)
                    }
                }
            }
    }

    public func loadMore(
        olderThan: String?,
        newerThan: String?
    ) {
        let request = FeedLoadRequest(
            olderThan: olderThan, newerThan: newerThan)
        Task {
            let unfiltered = try await load(request)
            await insertRecordsAfterFiltering(
                at: request.resultsInsertionPoint, additionalRecords: unfiltered
            )
        }
    }
    
    public func asyncLoadMore(
        olderThan: String?,
        newerThan: String?
    ) async {
        let request = FeedLoadRequest(
            olderThan: olderThan, newerThan: newerThan)
        do {
            let unfiltered = try await load(request)
            await insertRecordsAfterFiltering(
                at: request.resultsInsertionPoint, additionalRecords: unfiltered
            )
        } catch {
            presentError(error)
        }
    }

    private func load(_ request: FeedLoadRequest) async throws
        -> [_NotificationViewModel]
    {
        switch kind {
        case .notificationsAll:
            return try await loadNotifications(
                withScope: .everything, olderThan: request.olderThan)
        case .notificationsMentionsOnly:
            return try await loadNotifications(
                withScope: .mentions, olderThan: request.olderThan)
        case .notificationsWithAccount(let accountID):
            return try await loadNotifications(
                withAccountID: accountID, olderThan: request.olderThan)
        }
    }
}

// MARK: - Filtering
extension GroupedNotificationFeedLoader {
    private func setRecordsAfterFiltering(
        _ newRecords: [_NotificationViewModel],
        canLoadOlder: Bool
    ) async {
        guard let filterBox = StatusFilterService.shared.activeFilterBox else {
            self.records = FeedLoadResult(allRecords: newRecords.removingDuplicates(), canLoadOlder: canLoadOlder)
            return
        }
        let filtered = await self.filter(
            newRecords, forFeed: kind, with: filterBox)
        self.records = FeedLoadResult(allRecords: filtered.removingDuplicates(), canLoadOlder: canLoadOlder)
    }

    private func insertRecordsAfterFiltering(
        at insertionPoint: FeedLoadRequest.InsertLocation,
        additionalRecords: [_NotificationViewModel]
    ) async {
        let newRecords: [_NotificationViewModel]
        if let filterBox = StatusFilterService.shared.activeFilterBox {
            newRecords = await self.filter(
                additionalRecords, forFeed: kind, with: filterBox)
        } else {
            newRecords = additionalRecords
        }
        var canLoadOlder = self.records.canLoadOlder
        var combinedRecords = self.records.allRecords
        switch insertionPoint {
        case .start:
            combinedRecords = (newRecords + combinedRecords).removingDuplicates()
        case .end:
            let prevLast = combinedRecords.last
            combinedRecords = (combinedRecords + newRecords).removingDuplicates()
            let curLast = combinedRecords.last
            canLoadOlder = !(prevLast == curLast)
        case .replace:
            combinedRecords = newRecords.removingDuplicates()
        }
        self.records = FeedLoadResult(allRecords: combinedRecords, canLoadOlder: canLoadOlder)
    }

    private func filter(
        _ records: [_NotificationViewModel], forFeed feedKind: MastodonFeedKind,
        with filterBox: Mastodon.Entity.FilterBox
    ) async -> [_NotificationViewModel] {
        return records
    }
}

// MARK: - Notifications
extension GroupedNotificationFeedLoader {
    private func loadNotifications(
        withScope scope: APIService.MastodonNotificationScope,
        olderThan maxID: String? = nil
    ) async throws -> [_NotificationViewModel] {
        let useGroupedNotifications = UserDefaults.standard
            .useGroupedNotifications
        if useGroupedNotifications {
            return try await _getGroupedNotifications(
                withScope: scope, olderThan: maxID)
        } else {
            return try await _getUngroupedNotifications(
                withScope: scope, olderThan: maxID)
        }
    }

    private func loadNotifications(
        withAccountID accountID: String, olderThan maxID: String? = nil
    ) async throws -> [_NotificationViewModel] {
        let useGroupedNotifications = UserDefaults.standard
            .useGroupedNotifications
        if useGroupedNotifications {
            return try await _getGroupedNotifications(
                accountID: accountID, olderThan: maxID)
        } else {
            return try await _getUngroupedNotifications(
                accountID: accountID, olderThan: maxID)
        }
    }

    private func _getUngroupedNotifications(
        withScope scope: APIService.MastodonNotificationScope? = nil,
        accountID: String? = nil, olderThan maxID: String? = nil
    ) async throws -> [_NotificationViewModel] {

        assert(scope != nil || accountID != nil, "need a scope or an accountID")
        guard
            let authenticationBox = AuthenticationServiceProvider.shared
                .currentActiveUser.value
        else { throw APIService.APIError.implicit(.authenticationMissing) }

        let notifications = try await APIService.shared.notifications(
            olderThan: maxID, fromAccount: accountID, scope: scope,
            authenticationBox: authenticationBox
        ).value

        return notifications.map {
            _NotificationViewModel(
                $0,
                presentError: { [weak self] error in self?.presentError(error) }
            )
        }
    }

    private func _getGroupedNotifications(
        withScope scope: APIService.MastodonNotificationScope? = nil,
        accountID: String? = nil, olderThan maxID: String? = nil
    ) async throws -> [_NotificationViewModel] {

        assert(scope != nil || accountID != nil, "need a scope or an accountID")

        guard
            let authenticationBox = AuthenticationServiceProvider.shared
                .currentActiveUser.value
        else { throw APIService.APIError.implicit(.authenticationMissing) }

        let results = try await APIService.shared.groupedNotifications(
            olderThan: maxID, fromAccount: accountID, scope: scope,
            authenticationBox: authenticationBox
        ).value

        return
            _NotificationViewModel
            .viewModelsFromGroupedNotificationResults(
                results,
                myAccountID: authenticationBox.userID,
                presentError: { [weak self] error in self?.presentError(error) }
            )
    }

    private func _getGroupedNotificationResults(
        withScope scope: APIService.MastodonNotificationScope? = nil,
        accountID: String? = nil, olderThan maxID: String? = nil
    ) async throws -> Mastodon.Entity.GroupedNotificationsResults {

        assert(scope != nil || accountID != nil, "need a scope or an accountID")

        guard
            let authenticationBox = AuthenticationServiceProvider.shared
                .currentActiveUser.value
        else { throw APIService.APIError.implicit(.authenticationMissing) }

        let results = try await APIService.shared.groupedNotifications(
            olderThan: maxID, fromAccount: accountID, scope: scope,
            authenticationBox: authenticationBox
        ).value

        return results
    }
}


extension _NotificationViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
