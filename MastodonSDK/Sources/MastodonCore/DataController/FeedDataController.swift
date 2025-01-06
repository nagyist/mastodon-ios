import Foundation
import UIKit
import Combine
import MastodonSDK
import os.log

@MainActor
final public class FeedDataController {
    private let logger = Logger(subsystem: "FeedDataController", category: "Data")
    private static let entryNotFoundMessage = "Failed to find suitable record. Depending on the context this might result in errors (data not being updated) or can be discarded (e.g. when there are mixed data sources where an entry might or might not exist)."

    @Published public private(set) var records: [MastodonFeed] = []
    
    private let authenticationBox: MastodonAuthenticationBox
    private let kind: MastodonFeed.Kind
    
    private var subscriptions = Set<AnyCancellable>()
    
    public init(authenticationBox: MastodonAuthenticationBox, kind: MastodonFeed.Kind) {
        self.authenticationBox = authenticationBox
        self.kind = kind
        
        StatusFilterService.shared.$activeFilterBox
            .sink { filterBox in
                if let filterBox {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.setRecordsAfterFiltering(self.records)
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    public func setRecordsAfterFiltering(_ newRecords: [MastodonFeed]) async {
        guard let filterBox = StatusFilterService.shared.activeFilterBox else { self.records = newRecords; return }
        let filtered = await self.filter(newRecords, forFeed: kind, with: filterBox)
        self.records = filtered.removingDuplicates()
    }
    
    public func appendRecordsAfterFiltering(_ additionalRecords: [MastodonFeed]) async {
        guard let filterBox = StatusFilterService.shared.activeFilterBox else { self.records += additionalRecords; return }
        let newRecords = await self.filter(additionalRecords, forFeed: kind, with: filterBox)
        self.records = (self.records + newRecords).removingDuplicates()
    }
    
    public func loadInitial(kind: MastodonFeed.Kind) {
        Task {
            let unfilteredRecords = try await load(kind: kind, maxID: nil)
            await setRecordsAfterFiltering(unfilteredRecords)
        }
    }
    
    public func loadNext(kind: MastodonFeed.Kind) {
        Task {
            guard let lastId = records.last?.status?.id else {
                return loadInitial(kind: kind)
            }

            let unfiltered = try await load(kind: kind, maxID: lastId)
            await self.appendRecordsAfterFiltering(unfiltered)
        }
    }
    
    private func filter(_ records: [MastodonFeed], forFeed feedKind: MastodonFeed.Kind, with filterBox: Mastodon.Entity.FilterBox) async -> [MastodonFeed] {
        
        let filteredRecords = records.filter { feedRecord in
            guard let status = feedRecord.status else { return true }
            let filterResult = filterBox.apply(to: status, in: feedKind.filterContext)
            switch filterResult {
            case .hide:
                return false
            default:
                return true
            }
        }
        return filteredRecords
    }
    
    @MainActor
    public func update(status: MastodonStatus, intent: MastodonStatus.UpdateIntent) {
        switch intent {
        case .delete:
            delete(status)
        case .edit:
            updateEdited(status)
        case let .bookmark(isBookmarked):
            updateBookmarked(status, isBookmarked)
        case let .favorite(isFavorited):
            updateFavorited(status, isFavorited)
        case let .reblog(isReblogged):
            updateReblogged(status, isReblogged)
        case let .toggleSensitive(isVisible):
            updateSensitive(status, isVisible)
        case .pollVote:
            updateEdited(status) // technically the data changed so refresh it to reflect the new data
        }
    }
    
    @MainActor
    private func delete(_ status: MastodonStatus) {
        records.removeAll { $0.id == status.id }
    }
    
    @MainActor
    private func updateEdited(_ status: MastodonStatus) {
        var newRecords = Array(records)
        guard let index = newRecords.firstIndex(where: { $0.id == status.id }) else {
            logger.warning("\(Self.entryNotFoundMessage)")
            return
        }
        let existingRecord = newRecords[index]
        let newStatus = status.inheritSensitivityToggled(from: existingRecord.status)
        newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
        records = newRecords
    }
    
    @MainActor
    private func updateBookmarked(_ status: MastodonStatus, _ isBookmarked: Bool) {
        var newRecords = Array(records)
        guard let index = newRecords.firstIndex(where: { $0.id == status.id }) else {
            logger.warning("\(Self.entryNotFoundMessage)")
            return
        }
        let existingRecord = newRecords[index]
        let newStatus = status.inheritSensitivityToggled(from: existingRecord.status)
        newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
        records = newRecords
    }
    
    @MainActor
    private func updateFavorited(_ status: MastodonStatus, _ isFavorited: Bool) {
        var newRecords = Array(records)
        if let index = newRecords.firstIndex(where: { $0.id == status.id }) {
            // Replace old status entity
            let existingRecord = newRecords[index]
            let newStatus = status.inheritSensitivityToggled(from: existingRecord.status).withOriginal(status: existingRecord.status?.originalStatus)
            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
        } else if let index = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.id }) {
            // Replace reblogged entity of old "parent" status
            let newStatus: MastodonStatus
            if let existingEntity = newRecords[index].status?.entity {
                newStatus = .fromEntity(existingEntity)
                newStatus.originalStatus = newRecords[index].status?.originalStatus
                newStatus.reblog = status
            } else {
                newStatus = status
            }
            newRecords[index] = .fromStatus(newStatus, kind: newRecords[index].kind)
        } else {
            logger.warning("\(Self.entryNotFoundMessage)")
        }
        records = newRecords
    }
    
    @MainActor
    private func updateReblogged(_ status: MastodonStatus, _ isReblogged: Bool) {
        var newRecords = Array(records)

        switch isReblogged {
        case true:
            let index: Int
            if let idx = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.reblog?.id }) {
                index = idx
            } else if let idx = newRecords.firstIndex(where: { $0.id == status.reblog?.id }) {
                index = idx
            } else {
                logger.warning("\(Self.entryNotFoundMessage)")
                return
            }
            let existingRecord = newRecords[index]
            newRecords[index] = .fromStatus(status.withOriginal(status: existingRecord.status), kind: existingRecord.kind)
        case false:
            let index: Int
            if let idx = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.id }) {
                index = idx
            } else if let idx = newRecords.firstIndex(where: { $0.status?.id == status.id }) {
                index = idx
            } else {
                logger.warning("\(Self.entryNotFoundMessage)")
                return
            }
            let existingRecord = newRecords[index]
            let newStatus = existingRecord.status?.originalStatus ?? status.inheritSensitivityToggled(from: existingRecord.status)
            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
        }
        records = newRecords
    }
    
    @MainActor
    private func updateSensitive(_ status: MastodonStatus, _ isVisible: Bool) {
        var newRecords = Array(records)
        if let index = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.id }), let existingEntity = newRecords[index].status?.entity {
            let existingRecord = newRecords[index]
            let newStatus: MastodonStatus = .fromEntity(existingEntity)
            newStatus.reblog = status
            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
        } else if let index = newRecords.firstIndex(where: { $0.id == status.id }), let existingEntity = newRecords[index].status?.entity {
            let existingRecord = newRecords[index]
            let newStatus: MastodonStatus = .fromEntity(existingEntity)
                .inheritSensitivityToggled(from: status)
            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
        } else {
            logger.warning("\(Self.entryNotFoundMessage)")
            return
        }
        records = newRecords
    }
}

private extension FeedDataController {

    func load(kind: MastodonFeed.Kind, maxID: MastodonStatus.ID?) async throws -> [MastodonFeed] {
        switch kind {
        case .home(let timeline):
            await AuthenticationServiceProvider.shared.fetchAccounts(onlyIfItHasBeenAwhile: true)

            let response: Mastodon.Response.Content<[Mastodon.Entity.Status]>

            switch timeline {
            case .home:
                response = try await APIService.shared.homeTimeline(
                    maxID: maxID,
                    authenticationBox: authenticationBox
                )
            case .public:
                response = try await APIService.shared.publicTimeline(
                    query: .init(local: true, maxID: maxID),
                    authenticationBox: authenticationBox
                )
            case let .list(id):
                response = try await APIService.shared.listTimeline(
                    id: id,
                    query: .init(maxID: maxID),
                    authenticationBox: authenticationBox
                )
            case let .hashtag(tag):
                response = try await APIService.shared.hashtagTimeline(
                    hashtag: tag,
                    authenticationBox: authenticationBox
                )
            }

            return response.value.compactMap { entity in
                let status = MastodonStatus.fromEntity(entity)
                return .fromStatus(status, kind: .home)
            }
        case .notificationAll:
            return try await getFeeds(with: .everything)
        case .notificationMentions:
            return try await getFeeds(with: .mentions)
        case .notificationAccount(let accountID):
            return try await getFeeds(with: nil, accountID: accountID)
        }
    }

    private func getFeeds(with scope: APIService.MastodonNotificationScope?, accountID: String? = nil) async throws -> [MastodonFeed] {

        let notifications = try await APIService.shared.notifications(maxID: nil, accountID: accountID, scope: scope, authenticationBox: authenticationBox).value

        let accounts = notifications.map { $0.account }
        let relationships = try await APIService.shared.relationship(forAccounts: accounts, authenticationBox: authenticationBox).value

        let notificationsWithRelationship: [(notification: Mastodon.Entity.Notification, relationship: Mastodon.Entity.Relationship?)] = notifications.compactMap { notification in
            guard let relationship = relationships.first(where: {$0.id == notification.account.id }) else { return (notification: notification, relationship: nil)}

            return (notification: notification, relationship: relationship)
        }

        let feeds = notificationsWithRelationship.compactMap({ (notification: Mastodon.Entity.Notification, relationship: Mastodon.Entity.Relationship?) in
            MastodonFeed.fromNotification(notification, relationship: relationship, kind: .notificationAll)
        })

        return feeds
    }
}

extension MastodonFeed.Kind {
    var filterContext: Mastodon.Entity.FilterContext {
        switch self {
        case .home(let timeline): // TODO: take timeline into account. See iOS-333.
            return .home
        case .notificationAccount, .notificationAll, .notificationMentions:
            return .notifications
        }
    }
}
