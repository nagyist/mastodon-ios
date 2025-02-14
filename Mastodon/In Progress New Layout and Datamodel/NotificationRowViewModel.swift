// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import Combine
import Foundation
import MastodonCore
import MastodonLocalization
import MastodonSDK

class NotificationRowViewModel: ObservableObject {
    let identifier: MastodonFeedItemIdentifier
    let oldestID: String?
    let newestID: String?
    let type: GroupedNotificationType
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
        myAccountDomain: String,
        navigateToScene: @escaping (
            SceneCoordinator.Scene, SceneCoordinator.Transition
        ) -> Void, presentError: @escaping (Error) -> Void
    ) {

        self.identifier = .notificationGroup(id: notificationInfo.id)
        self.oldestID = notificationInfo.oldestNotificationID
        self.newestID = notificationInfo.newestNotificationID
        self.type = notificationInfo.groupedNotificationType
        self.iconInfo = NotificationIconInfo(
            notificationType: notificationInfo.groupedNotificationType,
            isGrouped: notificationInfo.sourceAccounts.totalActorCount > 1,
            visibility: notificationInfo.statusViewModel?.visibility)
        self.navigateToScene = navigateToScene
        self.presentError = presentError
        self.defaultNavigation = notificationInfo.defaultNavigation

        switch notificationInfo.groupedNotificationType {

        case .follow, .followRequest:
            let avatarRowAdditionalElement: RelationshipElement
            if let account = notificationInfo.sourceAccounts
                .primaryAuthorAccount
            {
                avatarRowAdditionalElement = .unfetched(
                    notificationInfo.groupedNotificationType)
            } else {
                avatarRowAdditionalElement = .error(nil)
            }
            avatarRow = .avatarRow(
                notificationInfo.sourceAccounts,
                avatarRowAdditionalElement)
            if let accountName = notificationInfo.sourceAccounts
                .primaryAuthorAccount?
                .displayNameWithFallback
            {
                headerTextComponents = [
                    .text(
                        notificationInfo.groupedNotificationType
                            .actionSummaryLabel(notificationInfo.sourceAccounts)
                            ?? "")
                ]
            }
        case .mention, .status:
            // TODO: eventually make this full status style, not inline
            // TODO: distinguish mentions from replies
            if let statusViewModel =
                notificationInfo.statusViewModel
            {
                avatarRow = .avatarRow(
                    notificationInfo.sourceAccounts,
                    .noneNeeded)
                headerTextComponents = [
                    .text(
                        notificationInfo.groupedNotificationType
                            .actionSummaryLabel(notificationInfo.sourceAccounts)
                            ?? "")
                ]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [._other("POST BY UNKNOWN ACCOUNT")]
            }
        case .reblog, .favourite:
            if let statusViewModel = notificationInfo.statusViewModel {
                avatarRow = .avatarRow(
                    notificationInfo.sourceAccounts,
                    .noneNeeded)
                headerTextComponents = [
                    .text(
                        notificationInfo.groupedNotificationType
                            .actionSummaryLabel(notificationInfo.sourceAccounts)
                            ?? "")
                ]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [
                    ._other("REBLOGGED/FAVOURITED BY UNKNOWN ACCOUNT")
                ]
            }
        case .poll, .update:
            if let statusViewModel =
                notificationInfo.statusViewModel
            {
                headerTextComponents = [
                    .text(
                        notificationInfo.groupedNotificationType
                            .actionSummaryLabel(notificationInfo.sourceAccounts)
                            ?? "")
                ]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [
                    ._other("POLL/UPDATE FROM UNKNOWN ACCOUNT")
                ]
            }
        case .adminSignUp:
            avatarRow = .avatarRow(
                notificationInfo.sourceAccounts,
                .noneNeeded)
            headerTextComponents = [
                .text(
                    notificationInfo.groupedNotificationType.actionSummaryLabel(
                        notificationInfo.sourceAccounts) ?? "")
            ]
        case .adminReport(let report):
            if let summary = report?.summary {
                headerTextComponents = [.text(summary)]
            }
            if let comment = report?
                .displayableComment
            {
                contentComponents = [.text(comment)]
            }
        case .severedRelationships(let severanceEvent):
            if let summary = severanceEvent?.summary(myDomain: myAccountDomain)
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
                .hyperlinkButton(
                    L10n.Scene.Notification.learnMoreAboutServerBlocks,
                    notificationInfo.groupedNotificationType.learnMoreUrl(
                        forDomain: myAccountDomain,
                        notificationID: notificationInfo.newestNotificationID))
            ]
        case .moderationWarning(let accountWarning):
            headerTextComponents = [
                .weightedText(
                    (accountWarning?.action ?? .none).actionDescription,
                    .regular)
            ]

            let learnMoreButton = NotificationViewComponent.hyperlinkButton(
                L10n.Scene.Notification.Warning.learnMore,
                notificationInfo.groupedNotificationType.learnMoreUrl(
                    forDomain: myAccountDomain,
                    notificationID: accountWarning?.id ?? notificationInfo.newestNotificationID))

            if let accountWarningText = accountWarning?.text {
                contentComponents = [
                    .weightedText(accountWarningText, .regular),
                    learnMoreButton,
                ]
            } else {
                contentComponents = [
                    learnMoreButton
                ]
            }

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
            guard let accountID = sourceAccounts.firstAccountID,
                let accountIsLocked = sourceAccounts.primaryAuthorAccount?
                    .locked
            else { return }
            avatarRow = .avatarRow(sourceAccounts, .fetching)

            Task { @MainActor in
                let element: RelationshipElement
                do {
                    if let relationship = try await fetchRelationship(
                        to: accountID)
                    {

                        switch (type, relationship.following) {
                        case (.follow, true):
                            element = .iFollowThem(theyFollowMe: true)
                        case (.follow, false):
                            element = .iDoNotFollowThem(
                                theirAccountIsLocked: accountIsLocked)
                        case (.followRequest, _):
                            element = .theyHaveRequestedToFollowMe(
                                iFollowThem: relationship.following)
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
                case .iDoNotFollowThem, .iFollowThem,
                    .iHaveRequestedToFollowThem:
                    await doFollowAction(
                        relationshipElement.followAction,
                        notificationSourceAccounts: accountInfo)
                case .theyHaveRequestedToFollowMe:
                    await doAnswerFollowRequest(accountInfo, accept: accept)
                default:
                    return
                }
            default:
                return
            }
        }
    }

    @MainActor
    private func doFollowAction(
        _ action: RelationshipElement.FollowAction,
        notificationSourceAccounts: NotificationSourceAccounts
    ) async {
        guard let accountID = notificationSourceAccounts.firstAccountID,
            let theirAccountIsLocked = notificationSourceAccounts
                .primaryAuthorAccount?.locked,
            let authBox = AuthenticationServiceProvider.shared.currentActiveUser
                .value
        else { return }
        let startingAvatarRow = avatarRow
        avatarRow = .avatarRow(notificationSourceAccounts, .fetching)
        do {
            let updatedElement: RelationshipElement
            let response: Mastodon.Entity.Relationship
            switch action {
            case .follow:
                response = try await APIService.shared.follow(
                    accountID, authenticationBox: authBox)
            case .unfollow:
                response = try await APIService.shared.unfollow(
                    accountID, authenticationBox: authBox)
            case .noAction:
                throw AppError.unexpected(
                    "action attempted for relationship element that has no action"
                )
            }
            if response.following {
                updatedElement = .iFollowThem(theyFollowMe: response.followedBy)
            } else if response.requested {
                updatedElement = .iHaveRequestedToFollowThem
            } else {
                updatedElement = .iDoNotFollowThem(
                    theirAccountIsLocked: theirAccountIsLocked)
            }
            avatarRow = .avatarRow(notificationSourceAccounts, updatedElement)
        } catch {
            presentError(error)
            avatarRow = startingAvatarRow
        }
    }

    @MainActor
    private func doAnswerFollowRequest(
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
                accountInfo,
                .iHaveAnsweredTheirRequestToFollowMe(didAccept: accept))
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

            let sourceAccounts = NotificationSourceAccounts(
                myAccountID: myAccountID, primaryAuthorAccount: primaryAccount,
                avatarUrls: avatarUrls,
                totalActorCount: group.notificationsCount)

            let status = group.statusID == nil ? nil : statuses[group.statusID!]

            let type = GroupedNotificationType(
                group, sourceAccounts: sourceAccounts, status: status)

            let info = GroupedNotificationInfo(
                id: group.id,
                oldestNotificationID: group.pageNewestID ?? "",
                newestNotificationID: group.pageOldestID ?? "",
                groupedNotificationType: type,
                sourceAccounts: sourceAccounts,
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
                defaultNavigation: {
                    guard
                        let navigation = defaultNavigation(
                            group.type, isGrouped: group.notificationsCount > 1,
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
                info, myAccountDomain: myAccountDomain,
                navigateToScene: navigateToScene,
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
            let sourceAccounts = NotificationSourceAccounts(
                myAccountID: myAccountID,
                primaryAuthorAccount: notification.account,
                avatarUrls: notification.authorAvatarUrls, totalActorCount: 1)
            
            let statusViewModel = notification.status?.viewModel(
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
                })
            
            let info = GroupedNotificationInfo(
                id: notification.id,
                oldestNotificationID: notification.id,
                newestNotificationID: notification.id,
                groupedNotificationType: GroupedNotificationType(
                    notification, sourceAccounts: sourceAccounts),
                sourceAccounts: sourceAccounts,
                statusViewModel: statusViewModel,
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
                info, myAccountDomain: myAccountDomain,
                navigateToScene: navigateToScene,
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

extension GroupedNotificationType {
    init(
        _ notification: Mastodon.Entity.Notification,
        sourceAccounts: NotificationSourceAccounts
    ) {
        switch notification.typeFromServer {
        case .follow:
            self = .follow(from: sourceAccounts)
        case .followRequest:
            if let account = sourceAccounts.primaryAuthorAccount {
                self = .followRequest(from: account)
            } else {
                self = ._other("Follow request from unknown account")
            }
        case .mention:
            self = .mention(notification.status)
        case .reblog:
            self = .mention(notification.status)
        case .favourite:
            self = .favourite(notification.status)
        case .poll:
            self = .poll(notification.status)
        case .status:
            self = .status(notification.status)
        case .update:
            self = .update(notification.status)
        case .adminSignUp:
            self = .adminSignUp
        case .adminReport:
            self = .adminReport(notification.ruleViolationReport)
        case .severedRelationships:
            self = .severedRelationships(
                notification.relationshipSeveranceEvent)
        case .moderationWarning:
            self = .moderationWarning(notification.accountWarning)
        case ._other(let string):
            self = ._other(string)
        }
    }

    init(
        _ notificationGroup: Mastodon.Entity.NotificationGroup,
        sourceAccounts: NotificationSourceAccounts,
        status: Mastodon.Entity.Status?
    ) {
        switch notificationGroup.type {
        case .follow:
            self = .follow(from: sourceAccounts)
        case .followRequest:
            if let account = sourceAccounts.primaryAuthorAccount {
                self = .followRequest(from: account)
            } else {
                self = ._other("Follow request from unknown account")
            }
        case .mention:
            self = .mention(status)
        case .reblog:
            self = .mention(status)
        case .favourite:
            self = .favourite(status)
        case .poll:
            self = .poll(status)
        case .status:
            self = .status(status)
        case .update:
            self = .update(status)
        case .adminSignUp:
            self = .adminSignUp
        case .adminReport:
            self = .adminReport(notificationGroup.ruleViolationReport)
        case .severedRelationships:
            self = .severedRelationships(
                notificationGroup.relationshipSeveranceEvent)
        case .moderationWarning:
            self = .moderationWarning(notificationGroup.accountWarning)
        case ._other(let string):
            self = ._other(string)
        }
    }
}

extension NotificationSourceAccounts {
    var authorsDescription: String? {
        switch authorName {
        case .me, .none:
            return nil
        case .other(let name):
            if totalActorCount > 1 {
                return "\(name) and \(totalActorCount - 1) others"
            } else {
                return name
            }
        }
    }
}

extension GroupedNotificationType {
    func learnMoreUrl(forDomain domain: String, notificationID: String) -> URL?
    {
        let trailingPathComponents: [String]
        switch self {
        case .severedRelationships:
            trailingPathComponents = ["severed_relationships"]
        case .moderationWarning:
            trailingPathComponents = [
                "disputes",
                "strikes",
                notificationID,
            ]
        default:
            return nil
        }
        var url = URL(string: "https://" + domain)
        for component in trailingPathComponents {
            url?.append(component: component)
        }
        return url
    }
}

extension Mastodon.Entity.AccountWarning.Action {
    var actionDescription: String {
        switch self {
        case .none:
            return L10n.Scene.Notification.Warning.none
        case .disable:
            return L10n.Scene.Notification.Warning.disable
        case .markStatusesAsSensitive:
            return L10n.Scene.Notification.Warning.markStatusesAsSensitive
        case .deleteStatuses:
            return L10n.Scene.Notification.Warning.deleteStatuses
        case .sensitive:
            return L10n.Scene.Notification.Warning.sensitive
        case .silence:
            return L10n.Scene.Notification.Warning.silence
        case .suspend:
            return L10n.Scene.Notification.Warning.suspend
        }
    }
}
