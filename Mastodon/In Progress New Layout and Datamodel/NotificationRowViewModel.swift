// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import Combine
import Foundation
import MastodonCore
import MastodonSDK

class NotificationRowViewModel: ObservableObject {
    let identifier: MastodonFeedItemIdentifier
    let oldestID: String?
    let newestID: String?
    let type: Mastodon.Entity.NotificationType
    let navigateToScene:
        (SceneCoordinator.Scene, SceneCoordinator.Transition) -> Void
    let presentError: (Error) -> Void
    let defaultNavigation: (() -> Void)?
    public let iconInfo: NotificationIconInfo?
    @Published public var headerComponents: [NotificationViewComponent] = []
    public var contentComponents: [NotificationViewComponent] = []

    private(set) var avatarRow: NotificationViewComponent? {
        didSet {
            resetHeaderComponents()
        }
    }
    private(set) var headerTextComponents: [NotificationViewComponent] = [] {
        didSet {
            resetHeaderComponents()
        }
    }

    private func resetHeaderComponents() {
        headerComponents = ([avatarRow] + headerTextComponents).compactMap {
            $0
        }
    }

    init(
        _ notificationInfo: GroupedNotificationInfo,
        navigateToScene: @escaping (
            SceneCoordinator.Scene, SceneCoordinator.Transition
        ) -> Void, presentError: @escaping (Error) -> Void
    ) {

        self.identifier = .notificationGroup(id: notificationInfo.id)
        self.oldestID = notificationInfo.oldestNotificationID
        self.newestID = notificationInfo.newestNotificationID
        self.type = notificationInfo.type
        self.iconInfo = NotificationIconInfo(
            notificationType: notificationInfo.type,
            isGrouped: notificationInfo.isGrouped,
            visibility: notificationInfo.statusViewModel?.visibility)
        self.navigateToScene = navigateToScene
        self.presentError = presentError
        self.defaultNavigation = notificationInfo.defaultNavigation

        switch notificationInfo.type {

        case .follow, .followRequest:
            let avatarRowAdditionalElement: RelationshipElement
            if let account = notificationInfo.primaryAuthorAccount {
                avatarRowAdditionalElement = .unfetched(
                    notificationInfo.type, accountID: account.id)
            } else {
                avatarRowAdditionalElement = .error(nil)
            }
            avatarRow = .avatarRow(
                NotificationSourceAccounts(
                    primaryAuthorAccount: notificationInfo.primaryAuthorAccount,
                    avatarUrls: notificationInfo.authorAvatarUrls,
                    totalActorCount: notificationInfo.authorsCount),
                avatarRowAdditionalElement)
            if let accountName = notificationInfo.primaryAuthorAccount?
                .displayNameWithFallback
            {
                headerTextComponents = [
                    .text(
                        notificationInfo.type.actionSummaryLabel(
                            firstAuthor: .other(named: accountName),
                            totalAuthorCount: notificationInfo.authorsCount))
                ]
            }
        case .mention, .status:
            // TODO: eventually make this full status style, not inline
            // TODO: distinguish mentions from replies
            if let primaryAuthorAccount = notificationInfo.primaryAuthorAccount,
                let statusViewModel =
                    notificationInfo.statusViewModel
            {
                avatarRow = .avatarRow(
                    NotificationSourceAccounts(
                        primaryAuthorAccount: primaryAuthorAccount,
                        avatarUrls: notificationInfo.authorAvatarUrls,
                        totalActorCount: notificationInfo.authorsCount),
                    .noneNeeded)
                headerTextComponents = [
                    .text(
                        notificationInfo.type.actionSummaryLabel(
                            firstAuthor: .other(
                                named: primaryAuthorAccount
                                    .displayNameWithFallback),
                            totalAuthorCount: notificationInfo.authorsCount))
                ]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [._other("POST BY UNKNOWN ACCOUNT")]
            }
        case .reblog, .favourite:
            if let primaryAuthorAccount = notificationInfo.primaryAuthorAccount,
                let statusViewModel = notificationInfo.statusViewModel
            {
                avatarRow = .avatarRow(
                    NotificationSourceAccounts(
                        primaryAuthorAccount: primaryAuthorAccount,
                        avatarUrls: notificationInfo.authorAvatarUrls,
                        totalActorCount: notificationInfo.authorsCount),
                    .noneNeeded)
                headerTextComponents = [
                    .text(
                        notificationInfo.type.actionSummaryLabel(
                            firstAuthor: .other(
                                named: primaryAuthorAccount
                                    .displayNameWithFallback),
                            totalAuthorCount: notificationInfo.authorsCount))
                ]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [
                    ._other("REBLOGGED/FAVOURITED BY UNKNOWN ACCOUNT")
                ]
            }
        case .poll, .update:
            if let author = notificationInfo.authorName,
                let statusViewModel =
                    notificationInfo.statusViewModel
            {
                headerTextComponents = [
                    .text(
                        notificationInfo.type.actionSummaryLabel(
                            firstAuthor: author,
                            totalAuthorCount: notificationInfo.authorsCount))
                ]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [
                    ._other("POLL/UPDATE FROM UNKNOWN ACCOUNT")
                ]
            }
        case .adminSignUp:
            if let primaryAuthorAccount = notificationInfo.primaryAuthorAccount,
                let authorName = notificationInfo.authorName
            {
                avatarRow = .avatarRow(
                    NotificationSourceAccounts(
                        primaryAuthorAccount: primaryAuthorAccount,
                        avatarUrls: notificationInfo.authorAvatarUrls,
                        totalActorCount: notificationInfo.authorsCount),
                    .noneNeeded)
                headerTextComponents = [
                    .text(
                        notificationInfo.type.actionSummaryLabel(
                            firstAuthor: authorName,
                            totalAuthorCount: notificationInfo.authorsCount))
                ]
            } else {
                headerTextComponents = [._other("ADMIN_SIGNUP NOTIFICATION")]
            }
        case .adminReport:
            if let summary = notificationInfo.ruleViolationReport?.summary {
                headerTextComponents = [.text(summary)]
            }
            if let comment = notificationInfo.ruleViolationReport?
                .displayableComment
            {
                contentComponents = [.text(comment)]
            }
        case .severedRelationships:
            if let summary = notificationInfo.relationshipSeveranceEvent?
                .summary
            {
                headerTextComponents = [.text(summary)]
            } else {
                headerTextComponents = [
                    ._other(
                        "An admin action removed some of your followers or accounts that you followed."
                    )
                ]
            }
            contentComponents = [
                .hyperlinkButton("Learn more about server blocks", nil)
            ]  // TODO: localization and go somewhere
        case .moderationWarning:
            headerTextComponents = [
                .text(
                    AttributedString(
                        "Your account has received a moderation warning."))
            ]  // TODO: localization
            contentComponents = [.hyperlinkButton("Learn more", nil)]  // TODO: localization and go somewhere
        case ._other(let text):
            headerTextComponents = [
                ._other("UNEXPECTED NOTIFICATION TYPE: \(text)")
            ]
        }
        resetHeaderComponents()
    }

    public func prepareForDisplay() {
        if let avatarRow {
            switch avatarRow {
            case .avatarRow(let sourceAccounts, let additionalElement):
                switch additionalElement {
                case .unfetched:
                    fetchRelationshipElement(sourceAccounts: sourceAccounts)
                default:
                    break
                }
            case .text, .weightedText, .status, .hyperlinkButton, ._other:
                break
            }
        }

    }

    private func fetchRelationshipElement(
        sourceAccounts: NotificationSourceAccounts
    ) {
        switch type {
        case .follow, .followRequest:
            guard let accountID = sourceAccounts.firstAccountID else { return }
            avatarRow = .avatarRow(sourceAccounts, .fetching)

            Task { @MainActor in
                let element: RelationshipElement
                do {
                    if let relationship = try await fetchRelationship(
                        to: accountID)
                    {

                        switch (type, relationship.following) {
                        case (.follow, true):
                            element = .mutualLabel
                        case (.follow, false):
                            element = .followButton
                        case (.followRequest, _):
                            element = .acceptRejectButtons(
                                isFollowing: relationship.following)
                        default:
                            element = .noneNeeded
                        }
                    } else {
                        element = .noneNeeded
                    }
                } catch {
                    element = .error(error)
                }

                avatarRow = .avatarRow(sourceAccounts, element)
            }
        default:
            avatarRow = .avatarRow(sourceAccounts, .noneNeeded)
        }
    }

    private func fetchRelationship(to accountID: String) async throws
        -> Mastodon.Entity.Relationship?
    {
        guard
            let authBox = await AuthenticationServiceProvider.shared
                .currentActiveUser.value
        else { return nil }
        if let relationship = try await APIService.shared.relationship(
            forAccountIds: [accountID], authenticationBox: authBox
        ).value.first {
            return relationship
        } else {
            return nil
        }
    }

    func navigateToProfile(_ account: Mastodon.Entity.Account) async throws {
        guard
            let me = await AuthenticationServiceProvider.shared
                .currentActiveUser.value?.cachedAccount
        else { return }
        if me.id == account.id {
            navigateToScene(.profile(.me(me)), .show)
        } else {
            let relationship = try await fetchRelationship(to: account.id)
            navigateToScene(
                .profile(
                    .notMe(
                        me: me, displayAccount: account,
                        relationship: relationship)), .show)
        }
    }
}

extension NotificationRowViewModel: Equatable {
    public static func == (
        lhs: NotificationRowViewModel, rhs: NotificationRowViewModel
    ) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension NotificationRowViewModel {

    public func doAvatarRowButtonAction(_ accept: Bool = true) {
        guard let avatarRow else { return }
        FeedbackGenerator.shared.generate(.selectionChanged)
        Task {
            switch avatarRow {
            case .avatarRow(let accountInfo, let relationshipElement):
                switch relationshipElement {
                case .followButton, .requestButton:
                    await doFollow(accountInfo)
                case .acceptRejectButtons:
                    await doAcceptFollowRequest(accountInfo, accept: accept)
                default:
                    return
                }
            default:
                return
            }
        }
    }

    @MainActor
    private func doFollow(_ accountInfo: NotificationSourceAccounts) async {
        guard let accountID = accountInfo.firstAccountID,
            let authBox = AuthenticationServiceProvider.shared.currentActiveUser
                .value
        else { return }
        let startingAvatarRow = avatarRow
        avatarRow = .avatarRow(accountInfo, .fetching)
        do {
            let updatedElement: RelationshipElement
            let response = try await APIService.shared.follow(
                accountID, authenticationBox: authBox)
            if response.following {
                updatedElement = .followingLabel
            } else if response.requested {
                updatedElement = .pendingRequestLabel
            } else {
                updatedElement = .error(nil)
            }
            avatarRow = .avatarRow(accountInfo, updatedElement)
        } catch {
            presentError(error)
            avatarRow = startingAvatarRow
        }
    }

    @MainActor
    private func doAcceptFollowRequest(
        _ accountInfo: NotificationSourceAccounts, accept: Bool
    ) async {
        guard let accountID = accountInfo.firstAccountID,
            let authBox = AuthenticationServiceProvider.shared.currentActiveUser
                .value
        else { return }
        let startingAvatarRow = avatarRow
        avatarRow = .avatarRow(accountInfo, .fetching)
        do {
            let expectedFollowedByResult = accept
            let newRelationship = try await APIService.shared.followRequest(
                userID: accountID,
                query: accept ? .accept : .reject,
                authenticationBox: authBox
            ).value
            guard newRelationship.followedBy == expectedFollowedByResult else {
                self.avatarRow = .avatarRow(accountInfo, .error(nil))
                return
            }
            self.avatarRow = .avatarRow(
                accountInfo, accept ? .acceptedLabel : .rejectedLabel)
        } catch {
            presentError(error)
            self.avatarRow = startingAvatarRow
        }
    }
}

extension NotificationRowViewModel {
    static func viewModelsFromGroupedNotificationResults(
        _ results: Mastodon.Entity.GroupedNotificationsResults,
        myAccountID: String,
        myAccountDomain: String,
        navigateToScene: @escaping (
            SceneCoordinator.Scene, SceneCoordinator.Transition
        ) -> Void, presentError: @escaping (Error) -> Void
    ) -> [NotificationRowViewModel] {
        let fullAccounts = results.accounts.reduce(
            into: [String: Mastodon.Entity.Account]()
        ) { partialResult, account in
            partialResult[account.id] = account
        }
        let partialAccounts = results.partialAccounts?.reduce(
            into: [String: Mastodon.Entity.PartialAccountWithAvatar]()
        ) { partialResult, account in
            partialResult[account.id] = account
        }

        let statuses = results.statuses.reduce(
            into: [String: Mastodon.Entity.Status](),
            { partialResult, status in
                partialResult[status.id] = status
            })

        return results.notificationGroups.map { group in
            var primaryAccount: Mastodon.Entity.Account? = nil
            for accountID in group.sampleAccountIDs {
                if let fullAccount = fullAccounts[accountID] {
                    primaryAccount = fullAccount
                    break
                }
            }

            let avatarUrls = group.sampleAccountIDs.compactMap { accountID in
                return fullAccounts[accountID]?.avatarURL
                    ?? partialAccounts?[accountID]?.avatarURL
            }

            let authorName: Mastodon.Entity.NotificationType.AuthorName?
            if primaryAccount?.id == myAccountID {
                authorName = .me
            } else if let name = primaryAccount?.displayNameWithFallback {
                authorName = .other(named: name)
            } else {
                authorName = nil
            }

            let status = group.statusID == nil ? nil : statuses[group.statusID!]

            let info = GroupedNotificationInfo(
                id: group.id,
                oldestNotificationID: group.oldestNotificationID,
                newestNotificationID: group.newestNotificationID,
                type: group.type,
                authorsCount: group.authorsCount,
                notificationsCount: group.notificationsCount,
                primaryAuthorAccount: primaryAccount,
                authorName: authorName,
                authorAvatarUrls: avatarUrls,
                statusViewModel: status?.viewModel(
                    myDomain: myAccountDomain,
                    navigateToStatus: {
                        Task {
                            guard
                                let authBox =
                                    await AuthenticationServiceProvider.shared
                                    .currentActiveUser.value, let status
                            else { return }
                            await navigateToScene(
                                .thread(
                                    viewModel: ThreadViewModel(
                                        authenticationBox: authBox,
                                        optionalRoot: .root(
                                            context: .init(
                                                status: MastodonStatus(
                                                    entity: status,
                                                    showDespiteContentWarning:
                                                        false))))), .show)
                        }
                    }),
                ruleViolationReport: group.ruleViolationReport,
                relationshipSeveranceEvent: group.relationshipSeveranceEvent,
                defaultNavigation: {
                    guard
                        let navigation = defaultNavigation(
                            group.type, isGrouped: group.isGrouped,
                            primaryAccount: primaryAccount)
                    else { return }
                    Task {
                        guard let scene = await navigation.destinationScene()
                        else { return }
                        navigateToScene(scene, .show)
                    }
                }
            )

            return NotificationRowViewModel(
                info, navigateToScene: navigateToScene,
                presentError: presentError)
        }
    }

    static func viewModelsFromUngroupedNotifications(
        _ notifications: [Mastodon.Entity.Notification],
        myAccountID: String,
        myAccountDomain: String,
        navigateToScene: @escaping (
            SceneCoordinator.Scene, SceneCoordinator.Transition
        ) -> Void, presentError: @escaping (Error) -> Void
    ) -> [NotificationRowViewModel] {

        return notifications.map { notification in
            let info = GroupedNotificationInfo(
                id: notification.id,
                oldestNotificationID: notification.id,
                newestNotificationID: notification.id,
                type: notification.type,
                authorsCount: notification.authorsCount,
                notificationsCount: 1,
                primaryAuthorAccount: notification.account,
                authorName: notification.authorName,
                authorAvatarUrls: notification.authorAvatarUrls,
                statusViewModel: notification.status?.viewModel(
                    myDomain: myAccountDomain,
                    navigateToStatus: {
                        Task {
                            guard
                                let authBox =
                                    await AuthenticationServiceProvider.shared
                                    .currentActiveUser.value,
                                let status = notification.status
                            else { return }
                            await navigateToScene(
                                .thread(
                                    viewModel: ThreadViewModel(
                                        authenticationBox: authBox,
                                        optionalRoot: .root(
                                            context: .init(
                                                status: MastodonStatus(
                                                    entity: status,
                                                    showDespiteContentWarning:
                                                        false))))), .show)
                        }
                    }),
                ruleViolationReport: notification.ruleViolationReport,
                relationshipSeveranceEvent: notification.relationshipSeveranceEvent,
                defaultNavigation: {
                    guard
                        let navigation = defaultNavigation(
                            notification.type, isGrouped: false,
                            primaryAccount: notification.primaryAuthorAccount)
                    else { return }
                    Task {
                        guard let scene = await navigation.destinationScene()
                        else { return }
                        navigateToScene(scene, .show)
                    }
                }
            )

            return NotificationRowViewModel(
                info, navigateToScene: navigateToScene,
                presentError: presentError)
        }
    }

    enum NotificationNavigation {
        case myFollowers
        case profile(Mastodon.Entity.Account)

        func destinationScene() async -> SceneCoordinator.Scene? {
            guard
                let authBox = await AuthenticationServiceProvider.shared
                    .currentActiveUser.value,
                let myAccount = await authBox.cachedAccount
            else { return nil }
            switch self {
            case .myFollowers:
                return .follower(
                    viewModel: FollowerListViewModel(
                        authenticationBox: authBox, domain: myAccount.domain,
                        userID: myAccount.id))
            case .profile(let account):
                if myAccount.id == account.id {
                    return .profile(.me(account))
                } else {
                    return .profile(
                        .notMe(
                            me: myAccount, displayAccount: account,
                            relationship: nil))
                }
            }
        }
    }

    static func defaultNavigation(
        _ notificationType: Mastodon.Entity.NotificationType, isGrouped: Bool,
        primaryAccount: Mastodon.Entity.Account?
    ) -> NotificationNavigation? {

        switch notificationType {
        case .favourite, .mention, .reblog, .poll, .status, .update:
            break  // The status will go to the status. The actor, if only one, will go to their profile.
        case .follow:
            if isGrouped {
                return .myFollowers
            } else if let primaryAccount {
                return .profile(primaryAccount)
            }
        case .followRequest, .adminSignUp:
            if let primaryAccount {
                return .profile(primaryAccount)
            }
        case .adminReport:
            break
        case .severedRelationships:
            return .myFollowers
        case .moderationWarning:
            break
        case ._other(_):
            break
        }
        return nil
    }
}
