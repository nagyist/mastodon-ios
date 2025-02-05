// Copyright © 2025 Mastodon gGmbH. All rights reserved.
import SwiftUI
import MastodonSDK
import MastodonAsset
import MastodonLocalization
import MastodonCore
import Combine
import MetaTextKit
import MastodonMeta

// TODO: all strings need localization

@MainActor
struct GroupedNotificationRowView: View {
    @ObservedObject var viewModel: NotificationRowViewModel
    
    init(viewModel: NotificationRowViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
            HStack(alignment: .top) {
                if viewModel.type.shouldShowIcon(grouped: viewModel.grouped) {
                    NotificationIconView(NotificationIconInfo(notificationType: viewModel.type, isGrouped: viewModel.grouped))
                }
                VStack(alignment: .leading) {
                    contentView()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(alignment: .bottom, content: {
                Divider()
            })
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .background(viewModel.isUnread ? Color(asset: Asset.Colors.accent).opacity(0.1) : .clear)
    }
    
    @ViewBuilder func contentView() -> some View {
        // TODO: implement unread with Mastodon.Entity.Marker
        
        switch viewModel {
        case is StatusNotificationViewModel:
            if viewModel.type == .status {
                TimelinePostCell(viewModel.feedItemIdentifier, includePadding: false)
            } else {
                VStack {
                    AvatarGroupRow(avatars: viewModel.authorAvatarUrls)
                    Text("\(viewModel.authorsDescription) \(actionText(forType: viewModel.type)):")
                    if let postViewModel = viewModel.postViewModel {
                        InlinePostPreview(viewModel: postViewModel)
                    }
                }
            }
//        case is SeveredRelationshipsViewModel:
            //                    VStack(alignment: .leading, spacing: 8) {
            //                        Text("An admin from **example.social** has blocked **mastodon.social**, including 4 of your followers and 2 accounts you follow.")
            //                        Button("Learn More", action: {})
            //                            .buttonStyle(.plain)
            //                            .bold()
            //                            .foregroundStyle(Color(asset: Asset.Colors.accent))
            //                    }
//        case is PollResultsViewModel:
            //                    Text("\(item.authorName) ran a poll that you and ?? others voted in")
            //                    if let postViewModel = viewModel.postViewModel {
            //                        InlinePostPreview(viewModel: postViewModel)
            //                    }
        case is MissingNotificationViewModel:
            Text("missing notification info")
        default:
            Text("not yet implemented")
        }
    }

    func actionText(forType: Mastodon.Entity.NotificationType) -> String {
        switch viewModel.type {
        case .reblog:
            return "boosted"
        case .favourite:
            return "favourited"
        case .mention:
            return "mentioned you"
        default:
            assertionFailure("unexpected notification type")
            return ""
        }
    }
}

struct AvatarGroupRow: View {
    let avatars: [URL]
    @ScaledMetric private var imageSize: CGFloat = 32
    private let avatarShape = RoundedRectangle(cornerRadius: 8)
    
    var body: some View {
        HStack(alignment: .center) {
            ForEach(avatars, id: \.self) { avatarUrl in  // TODO: url of default image for missing avatar can occur multiple times, but id needs to be unique
                AsyncImage(
                    url: avatarUrl,
                    content: { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(avatarShape)
                    },
                    placeholder: {
                        avatarShape
                            .foregroundStyle(Color(UIColor.secondarySystemFill))
                    }
                )
                .frame(width: imageSize, height: imageSize)
            }
            Spacer(minLength: 0)
        }
    }
}

extension Mastodon.Entity.NotificationType {
    
    func shouldShowIcon(grouped: Bool) -> Bool {
        return iconSystemName(grouped: grouped) != nil
    }
    
    func iconSystemName(grouped: Bool = false) -> String? {
        switch self {
        case .favourite:
            return "star"
        case .reblog:
            return "arrow.2.squarepath"
        case .follow:
            if grouped {
                return "person.2.badge.plus.fill"
            } else {
                return "person.fill.badge.plus"
            }
        case .poll:
            return "chart.bar.yaxis"
        case .adminReport:
            return "info.circle"
        case .severedRelationships:
            return "person.badge.minus"
        case .moderationWarning:
            return "exclamationmark.shield.fill"
        case ._other:
            return "questionmark.square.dashed"
        case .mention:
            // TODO: make this nil when full status view is available
            return "quote.bubble.fill"
        case .status:
            // TODO: make this nil when full status view is available
            return "bell.fill"
        case .followRequest:
            return "person.fill.badge.plus"
        case .update:
            return "pencil"
        case .adminSignUp:
            return nil
        }
    }
    
    var iconColor: Color {
        switch self {
        case .favourite:
            return .orange
        case .reblog:
            return .green
        case .follow, .followRequest, .status, .mention, .update:
            return Color(asset: Asset.Colors.accent)
        case .poll, .severedRelationships, .moderationWarning,  .adminReport, .adminSignUp:
            return .secondary
        case ._other:
            return .gray
        }
    }
    
    enum AuthorName {
        case me
        case other(named: String)
        
        var string: String {
            switch self {
            case .me:
                return "You"
            case .other(let name):
                return name
            }
        }
    }
    func actionSummaryLabel(firstAuthor: AuthorName, totalAuthorCount: Int) -> AttributedString {
        // TODO: L10n strings
        switch firstAuthor {
        case .me:
            assert(totalAuthorCount == 1)
            assert(self == .poll)
            return "Your poll has ended"
        case .other(let firstAuthorName):
            let nameComponent = boldedNameStringComponent(firstAuthorName)
            var composedString: AttributedString
            if totalAuthorCount == 1 {
                switch self {
                case .favourite:
                    composedString = nameComponent + AttributedString(" favorited:")
                case .follow:
                    composedString = nameComponent + AttributedString(" followed you")
                case .followRequest:
                    composedString = nameComponent + AttributedString(" requested to follow you")
                case .reblog:
                    composedString = nameComponent + AttributedString(" boosted:")
                case .mention:
                    composedString = nameComponent + AttributedString(" mentioned you:")
                case .poll:
                    composedString = nameComponent + AttributedString(" ran a poll that you voted in") // TODO: add count of how many others voted
                case .status:
                    composedString = nameComponent + AttributedString(" posted:")
                case .adminSignUp:
                    composedString = nameComponent + AttributedString(" signed up")
                default:
                    composedString = nameComponent + AttributedString("did something?")
                }
            } else {
                switch self {
                case .favourite:
                    composedString = nameComponent + AttributedString(" and \(totalAuthorCount - 1) others favorited:")
                case .follow:
                    composedString = nameComponent + AttributedString(" and \(totalAuthorCount - 1) others followed you")
                case .reblog:
                    composedString = nameComponent + AttributedString(" and \(totalAuthorCount - 1) others boosted:")
                default:
                    composedString = nameComponent + AttributedString(" and \(totalAuthorCount - 1) others did something")
                }
            }
            let nameStyling = AttributeContainer.font(.system(.body, weight: .bold))
            let nameContainer = AttributeContainer.personNameComponent(.givenName)
            composedString.replaceAttributes(nameContainer, with: nameStyling)
            return composedString
        }
    }
}

extension Mastodon.Entity.Report {
    // TODO: localization (inc. plurals)
    // "Someone reported X posts from someone else for rule violation"
    var summary: AttributedString {
        if let targetedAccountName = targetAccount?.displayNameWithFallback {
            let boldedName = boldedNameStringComponent(targetedAccountName)
            if let postCount = flaggedStatusIDs?.count {
                return AttributedString("Someone reported \(postCount) posts from ") + boldedName + AttributedString(" for rule violation.")
            } else {
                    return AttributedString("Someone reported ") + boldedName + AttributedString(" for rule violation.")
            }
        } else {
            return AttributedString("RULE VIOLATION REPORT")
        }
    }
    var displayableComment: AttributedString? {
        if let comment {
            return AttributedString(comment)
        } else {
            return nil
        }
    }
}

var listFormatter = ListFormatter()

extension Mastodon.Entity.RelationshipSeveranceEvent {
    // TODO: details and localization
    // Ideal example: "An admin from a.b has blocked c.d, including x of your followers and y accounts you follow."
    // For now: "An admin action has blocked x of your followers and y accounts that you follow"
    var summary: AttributedString? {
        let baseString = "Your admins have blocked "
        let lostFollowersString = followersCount > 0 ? "\(followersCount) of your followers" : nil
        let lostFollowingString = followingCount > 0 ? "\(followingCount) accounts that you follow" : nil
        guard let followersAndFollowingString = listFormatter.string(from: [lostFollowersString, lostFollowingString].compactMap { $0 } ) else {
            return nil
        }
        return AttributedString(baseString + followersAndFollowingString + ".")
    }
}

@ViewBuilder
func NotificationIconView(_ info: NotificationIconInfo) -> some View {
    HStack {
        Image(systemName: info.notificationType.iconSystemName(grouped: info.isGrouped) ?? "questionmark.square.dashed")
            .foregroundStyle(info.notificationType.iconColor)
    }
    .font(.system(size: 25))
    .frame(width: 44)
    .symbolVariant(.fill)
    .fontWeight(.semibold)
}


enum RelationshipElement: Equatable {
    case noneNeeded
    case unfetched(Mastodon.Entity.NotificationType, accountID: String)
    case fetching
    case error(Error?)
    case followButton
    case requestButton
    case acceptRejectButtons(isFollowing: Bool)
    case acceptedLabel
    case rejectedLabel
    case mutualLabel
    case followingLabel
    case pendingRequestLabel
    
    var description: String {
        switch self {
        case .noneNeeded:
            return "noneNeeded"
        case .unfetched:
            return "unfetched"
        case .fetching:
            return "fetching"
        case .error:
            return "error"
        case .followButton:
            return "follow"
        case .requestButton:
            return "request"
        case .acceptRejectButtons:
            return "acceptReject"
        case .acceptedLabel:
            return "accepted"
        case .rejectedLabel:
            return "rejected"
        case .mutualLabel:
            return "mutual"
        case .followingLabel:
            return "following"
        case .pendingRequestLabel:
            return "pending"
        }
    }
    
    static func == (lhs: RelationshipElement, rhs: RelationshipElement) -> Bool {
        return lhs.description == rhs.description
    }
    
}

protocol NotificationInfo {
    var id: String { get }
    var newestNotificationID: String { get }
    var oldestNotificationID: String { get }
    var type: Mastodon.Entity.NotificationType { get }
    var isGrouped: Bool { get }
    var notificationsCount: Int { get }
    var authorsCount: Int { get }
    var primaryAuthorAccount: Mastodon.Entity.Account? { get }
    var authorName: Mastodon.Entity.NotificationType.AuthorName? { get }
    var authorAvatarUrls: [URL] { get }
    func availableRelationshipElement() async -> RelationshipElement?
    func fetchRelationshipElement() async -> RelationshipElement
    var ruleViolationReport: Mastodon.Entity.Report? { get }
    var relationshipSeveranceEvent: Mastodon.Entity.RelationshipSeveranceEvent? { get }
}
extension NotificationInfo {
    var authorsDescription: String? {
        switch authorName {
        case .me, .none:
            return nil
        case .other(let name):
            if authorsCount > 1 {
                return "\(name) and \(authorsCount - 1) others"
            } else {
                return name
            }
        }
    }
    var avatarCount: Int {
        min(authorsCount, 8)
    }
    var isGrouped: Bool {
        return authorsCount > 1
    }
}

struct GroupedNotificationInfo: NotificationInfo {
    func availableRelationshipElement() async -> RelationshipElement? {
        return relationshipElement
    }
    
    func fetchRelationshipElement() async -> RelationshipElement {
        return relationshipElement
    }
    
    let id: String
    let oldestNotificationID: String
    let newestNotificationID: String
    
    let type: MastodonSDK.Mastodon.Entity.NotificationType
    
    let authorsCount: Int
    
    let notificationsCount: Int
    
    let primaryAuthorAccount: MastodonSDK.Mastodon.Entity.Account?
    
    let authorName: Mastodon.Entity.NotificationType.AuthorName?
    
    let authorAvatarUrls: [URL]
    
    var relationshipElement: RelationshipElement {
        switch type {
        case .follow, .followRequest:
            if let primaryAuthorAccount {
                return .unfetched(type, accountID: primaryAuthorAccount.id)
            } else {
                return .error(nil)
            }
        default:
            return .noneNeeded
        }
    }
    
    let statusViewModel: Mastodon.Entity.Status.ViewModel?
    let ruleViolationReport: Mastodon.Entity.Report?
    let relationshipSeveranceEvent: Mastodon.Entity.RelationshipSeveranceEvent?
}

extension Mastodon.Entity.Notification: NotificationInfo {
    
    var oldestNotificationID: String {
        return id
    }
    var newestNotificationID: String {
        return id
    }
    
    var authorsCount: Int { 1 }
    var notificationsCount: Int { 1 }
    var primaryAuthorAccount: Mastodon.Entity.Account? { account }
    var authorName: Mastodon.Entity.NotificationType.AuthorName? {
        .other(named: account.displayNameWithFallback)
    }
    var authorAvatarUrls: [URL] {
        if let domain = account.domain {
            return [account.avatarImageURLWithFallback(domain: domain)]
        } else if let url = account.avatarImageURL() {
            return [url]
        } else {
            return []
        }
    }
    
    @MainActor
    func availableRelationshipElement() -> RelationshipElement? {
        if let relationship = MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: account.id) {
            return relationship.relationshipElement
        }
        return nil
    }
    
    @MainActor
    func fetchRelationshipElement() async -> RelationshipElement {
        do {
            try await fetchRelationship()
            if let available = availableRelationshipElement() {
                return available
            } else {
                return .noneNeeded
            }
        } catch {
            return .error(error)
        }
    }
    private func fetchRelationship() async throws {
        guard let authBox = await AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
        let relationship = try await APIService.shared.relationship(forAccounts: [account], authenticationBox: authBox)
        await MastodonFeedItemCacheManager.shared.addToCache(relationship)
    }
}

extension Mastodon.Entity.NotificationGroup: NotificationInfo {
    
    var newestNotificationID: String {
        return pageNewestID ?? "\(mostRecentNotificationID)"
    }
    var oldestNotificationID: String {
        return pageOldestID ?? "\(mostRecentNotificationID)"
    }
    
    @MainActor
    var primaryAuthorAccount: Mastodon.Entity.Account? {
        guard let firstAccountID = sampleAccountIDs.first else { return nil }
        return MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID)
    }
    
    var authorsCount: Int { notificationsCount }
    
    @MainActor
    var authorName: Mastodon.Entity.NotificationType.AuthorName? {
        guard let firstAccountID = sampleAccountIDs.first, let firstAccount = MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID) else { return .none }
        return .other(named: firstAccount.displayNameWithFallback)
    }
    
    @MainActor
    var authorAvatarUrls: [URL] {
        return sampleAccountIDs
            .prefix(avatarCount)
            .compactMap { accountID in
                let account: NotificationAuthor? = MastodonFeedItemCacheManager.shared.fullAccount(accountID) ?? MastodonFeedItemCacheManager.shared.partialAccount(accountID)
                return account?.avatarURL
            }
    }
    
    @MainActor
    var firstAccount: NotificationAuthor? {
        guard let firstAccountID = sampleAccountIDs.first else { return nil }
        let firstAccount: NotificationAuthor? = MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID) ?? MastodonFeedItemCacheManager.shared.partialAccount(firstAccountID)
        return firstAccount
    }
    
    @MainActor
    func availableRelationshipElement() -> RelationshipElement? {
        guard authorsCount == 1 && type == .follow else { return .noneNeeded }
        guard let firstAccountID = sampleAccountIDs.first else { return .noneNeeded }
        if let relationship = MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: firstAccountID) {
            return relationship.relationshipElement
        }
        return nil
    }
    
    @MainActor
    func fetchRelationshipElement() async -> RelationshipElement {
        do {
            try await fetchRelationship()
            if let available = availableRelationshipElement() {
                return available
            } else {
                return .noneNeeded
            }
        } catch {
            return .error(error)
        }
    }
    
    func fetchRelationship() async throws {
        assert(notificationsCount == 1, "one relationship cannot be assumed representative of \(notificationsCount) notifications")
        guard let firstAccountId = sampleAccountIDs.first, let authBox = await AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
        if let relationship = try await APIService.shared.relationship(forAccountIds: [firstAccountId], authenticationBox: authBox).value.first {
            await MastodonFeedItemCacheManager.shared.addToCache(relationship)
        }
    }
    
    var statusViewModel: MastodonSDK.Mastodon.Entity.Status.ViewModel? {
        return nil
    }
}

extension Mastodon.Entity.Relationship {
    @MainActor
    var relationshipElement: RelationshipElement? {
        switch (following, followedBy) {
        case (true, true):
            return .mutualLabel
        case (true, false):
            return .followingLabel
        case (false, true):
            if let account: NotificationAuthor = MastodonFeedItemCacheManager.shared.fullAccount(id) ?? MastodonFeedItemCacheManager.shared.partialAccount(id),
               account.locked
            {
                if requested {
                    return .pendingRequestLabel
                } else {
                    return .requestButton
                }
            }
            return .followButton
        case (false, false):
            return nil
        }
    }
}

struct NotificationIconInfo {
    let notificationType: Mastodon.Entity.NotificationType
    let isGrouped: Bool
}

struct NotificationSourceAccounts {
    let primaryAuthorAccount: Mastodon.Entity.Account?
    var firstAccountID: String? {
        return primaryAuthorAccount?.id
    }
    let avatarUrls: [URL]
    let totalActorCount: Int
    
    init(primaryAuthorAccount: Mastodon.Entity.Account?, avatarUrls: [URL], totalActorCount: Int) {
        self.primaryAuthorAccount = primaryAuthorAccount
        self.avatarUrls = avatarUrls.removingDuplicates()
        self.totalActorCount = totalActorCount
    }
}

struct _NotificationRowView: View {
    @ObservedObject var viewModel: _NotificationViewModel
    
    var body: some View {
        HStack {
            if let iconInfo = viewModel.iconInfo {
                // LEFT GUTTER WITH TOP-ALIGNED ICON
                VStack {
                    Spacer()
                    NotificationIconView(iconInfo)
                    Spacer().frame(maxHeight: .infinity)
                }
            }
            
            // VSTACK OF HEADER AND CONTENT COMPONENT VIEWS
            VStack() {
                ForEach(viewModel.headerComponents) {
                    componentView($0)
                }
                ForEach(viewModel.contentComponents) {
                    componentView($0)
                }
            }
        }
    }
    
    @ViewBuilder
    func componentView(_ component: NotificationViewComponent) -> some View {
        switch component {
        case .avatarRow(let accountInfo, let addition):
            avatarRow(accountInfo: accountInfo, trailingElement: addition)
                .onTapGesture {
                    if accountInfo.totalActorCount == 1, let primaryAuthorAccount = accountInfo.primaryAuthorAccount {
                        Task {
                            do {
                                try await viewModel.navigateToProfile(primaryAuthorAccount)
                            } catch {
                                viewModel.presentError(error)
                            }
                        }
                    }
                }
        case .text(let string):
            Text(string)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .status(let viewModel):
            InlinePostPreview(viewModel: viewModel)
                .onTapGesture {
                    viewModel.navigateToStatus()
                }
        case .hyperlinkButton(let label, let url):
            Button(label) {
                // TODO: open url
            }
            .bold()
            .tint(Color(asset: Asset.Colors.accent))
        case ._other(let string):
            Text(string)
        }
    }
    
    func displayableAvatarCount(totalAvatarCount: Int, totalActorCount: Int) -> Int {
        // Make space for the "+ more" label
        // Unfortunately, using GeometryReader to avoid using a default max count resulted in weird layout side-effects.
        var maxAvatarCount = 8
        if maxAvatarCount < totalActorCount {
            maxAvatarCount = maxAvatarCount - 2
        }
        return maxAvatarCount
    }
    
    @ScaledMetric private var smallAvatarSize: CGFloat = 32
    private let avatarSpacing: CGFloat = 8
    private let avatarShape = RoundedRectangle(cornerRadius: 8)
    
    @ViewBuilder
    func avatarRow(accountInfo: NotificationSourceAccounts, trailingElement: RelationshipElement) -> some View {
            let maxAvatarCount = displayableAvatarCount( totalAvatarCount: accountInfo.avatarUrls.count, totalActorCount: accountInfo.totalActorCount)
            let needsMoreLabel = accountInfo.totalActorCount > maxAvatarCount
            HStack(alignment: .center) {
                ForEach(accountInfo.avatarUrls.prefix(maxAvatarCount), id: \.self) {
                    AsyncImage(
                        url: $0,
                        content: { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(avatarShape)
                        },
                        placeholder: {
                            avatarShape
                                .foregroundStyle(Color(UIColor.secondarySystemFill))
                        }
                    )
                    .frame(width: smallAvatarSize, height: smallAvatarSize)
                }
                if needsMoreLabel {
                    Text("+ more")
                        .fixedSize()
                        .lineLimit(1)
                }
                Spacer().frame(minWidth: 0, maxWidth: .infinity)
                avatarRowTrailingElement(trailingElement, grouped: accountInfo.totalActorCount > 1)
            }
    }
    
    @ViewBuilder
    func avatarRowTrailingElement(_ elementType: RelationshipElement, grouped: Bool) -> some View {
        switch (elementType, grouped) {
        case (.fetching, false):
            ProgressView().progressViewStyle(.circular)
        case (.followButton, false):
            Button(L10n.Common.Controls.Friendship.follow) {
                viewModel.doAvatarRowButtonAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .bold()
        case (.requestButton, false):
            Button(L10n.Common.Controls.Friendship.request) {
                viewModel.doAvatarRowButtonAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .bold()
        case (.acceptRejectButtons(let isFollowing), false):
            HStack {
                
                if isFollowing {
                    Text(L10n.Common.Controls.Friendship.following)
                }
                
                Button(L10n.Scene.Notification.FollowRequest.reject) {
                    viewModel.doAvatarRowButtonAction(false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .bold()
                
                Button(L10n.Scene.Notification.FollowRequest.accept) {
                    viewModel.doAvatarRowButtonAction(true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .bold()
            }
        case (.acceptedLabel, false):
            Text(L10n.Scene.Notification.FollowRequest.accepted)
        case (.rejectedLabel, false):
            Text(L10n.Scene.Notification.FollowRequest.rejected)
        case (.mutualLabel, false):
            Text(L10n.Common.Controls.Friendship.mutual)
        case (.followingLabel, false):
            Text(L10n.Common.Controls.Friendship.following)
        case (.pendingRequestLabel, false):
            Text(L10n.Common.Controls.Friendship.pending)
        case (.error(_), _):
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.gray)
        default:
            Spacer().frame(width: 0)
        }
    }
}

enum NotificationViewComponent: Identifiable {
    case avatarRow(NotificationSourceAccounts, RelationshipElement)
    case text(AttributedString)
    case status(Mastodon.Entity.Status.ViewModel)
    case hyperlinkButton(String, URL?)
    case _other(String)
    
    var id: String {
        switch self {
        case .avatarRow:
            return "avatar_row"
        case .text(let string):
            return string.description
        case .status:
            return "status"
        case .hyperlinkButton(let text, _):
            return text
        case ._other(let string):
            return string
        }
    }
}

class _NotificationViewModel: ObservableObject {
    let identifier: MastodonFeedItemIdentifier
    let oldestID: String?
    let newestID: String?
    let type: Mastodon.Entity.NotificationType
    let navigateToScene: (SceneCoordinator.Scene, SceneCoordinator.Transition)->()
    let presentError: (Error) -> ()
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
        headerComponents = ([avatarRow] + headerTextComponents).compactMap { $0 }
    }
    
    init(_ notificationInfo: NotificationInfo, navigateToScene: @escaping (SceneCoordinator.Scene, SceneCoordinator.Transition)->(), presentError: @escaping (Error)->()) {
        
        self.identifier = .notificationGroup(id: notificationInfo.id)
        self.oldestID = notificationInfo.oldestNotificationID
        self.newestID = notificationInfo.newestNotificationID
        self.type = notificationInfo.type
        self.iconInfo = NotificationIconInfo(notificationType: notificationInfo.type, isGrouped: notificationInfo.isGrouped)
        self.navigateToScene = navigateToScene
        self.presentError = presentError
        
        switch notificationInfo.type {
            
        case .follow, .followRequest:
            let avatarRowAdditionalElement: RelationshipElement
            let accountID: String?
            if let account = notificationInfo.primaryAuthorAccount {
                accountID = account.id
                avatarRowAdditionalElement = .unfetched(notificationInfo.type, accountID: account.id)
            } else {
                accountID = nil
                avatarRowAdditionalElement = .error(nil)
            }
            avatarRow = .avatarRow(NotificationSourceAccounts(primaryAuthorAccount: notificationInfo.primaryAuthorAccount, avatarUrls: notificationInfo.authorAvatarUrls, totalActorCount: notificationInfo.authorsCount), avatarRowAdditionalElement)
            if let accountName = notificationInfo.primaryAuthorAccount?.displayNameWithFallback {
                headerTextComponents = [.text(notificationInfo.type.actionSummaryLabel(firstAuthor: .other(named: accountName), totalAuthorCount: notificationInfo.authorsCount))]
            }
        case .mention, .status:
            // TODO: eventually make this full status style, not inline
            // TODO: distinguish mentions from replies
            if let primaryAuthorAccount = notificationInfo.primaryAuthorAccount, let statusViewModel = (notificationInfo as? GroupedNotificationInfo)?.statusViewModel {
                avatarRow = .avatarRow(NotificationSourceAccounts(primaryAuthorAccount: primaryAuthorAccount, avatarUrls: notificationInfo.authorAvatarUrls, totalActorCount: notificationInfo.authorsCount), .noneNeeded)
                headerTextComponents = [.text(notificationInfo.type.actionSummaryLabel(firstAuthor: .other(named: primaryAuthorAccount.displayNameWithFallback), totalAuthorCount: notificationInfo.authorsCount))]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [._other("POST BY UNKNOWN ACCOUNT")]
            }
        case .reblog, .favourite:
            if let primaryAuthorAccount = notificationInfo.primaryAuthorAccount, let statusViewModel = (notificationInfo as? GroupedNotificationInfo)?.statusViewModel {
                avatarRow = .avatarRow(NotificationSourceAccounts(primaryAuthorAccount: primaryAuthorAccount, avatarUrls: notificationInfo.authorAvatarUrls, totalActorCount: notificationInfo.authorsCount), .noneNeeded)
                headerTextComponents = [.text(notificationInfo.type.actionSummaryLabel(firstAuthor: .other(named: primaryAuthorAccount.displayNameWithFallback), totalAuthorCount: notificationInfo.authorsCount))]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [._other("REBLOGGED/FAVOURITED BY UNKNOWN ACCOUNT")]
            }
        case .poll, .update:
            if let author = notificationInfo.authorName, let statusViewModel = (notificationInfo as? GroupedNotificationInfo)?.statusViewModel {
                headerTextComponents = [.text(notificationInfo.type.actionSummaryLabel(firstAuthor: author, totalAuthorCount: notificationInfo.authorsCount))]
                contentComponents = [.status(statusViewModel)]
            } else {
                headerTextComponents = [._other("POLL/UPDATE FROM UNKNOWN ACCOUNT")]
            }
        case .adminSignUp:
            if let primaryAuthorAccount = notificationInfo.primaryAuthorAccount, let authorName = notificationInfo.authorName {
                avatarRow = .avatarRow(NotificationSourceAccounts(primaryAuthorAccount: primaryAuthorAccount, avatarUrls: notificationInfo.authorAvatarUrls, totalActorCount: notificationInfo.authorsCount), .noneNeeded)
                headerTextComponents = [.text(notificationInfo.type.actionSummaryLabel(firstAuthor: authorName, totalAuthorCount: notificationInfo.authorsCount))]
            } else {
                headerTextComponents = [._other("ADMIN_SIGNUP NOTIFICATION")]
            }
        case .adminReport:
            if let summary = notificationInfo.ruleViolationReport?.summary {
                headerTextComponents = [.text(summary)]
            }
            if let comment = notificationInfo.ruleViolationReport?.displayableComment {
                contentComponents = [.text(comment)]
            }
        case .severedRelationships:
            if let summary = notificationInfo.relationshipSeveranceEvent?.summary {
                headerTextComponents = [.text(summary)]
            } else {
                headerTextComponents = [._other("An admin action removed some of your followers or accounts that you followed.")]
            }
            contentComponents = [.hyperlinkButton("Learn more about server blocks", nil)] // TODO: localization and go somewhere
        case .moderationWarning:
            headerTextComponents = [.text(AttributedString("Your account has received a moderation warning."))] // TODO: localization
            contentComponents = [.hyperlinkButton("Learn more", nil)] // TODO: localization and go somewhere
        case ._other(let text):
            headerTextComponents = [._other("UNEXPECTED NOTIFICATION TYPE: \(text)")]
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
            case .text, .status, .hyperlinkButton, ._other:
                break
            }
        }
        
    }
    
    private func fetchRelationshipElement(sourceAccounts: NotificationSourceAccounts) {
        switch type {
        case .follow, .followRequest:
            guard let accountID = sourceAccounts.firstAccountID else { return }
            avatarRow = .avatarRow(sourceAccounts, .fetching)
            
            Task { @MainActor in
                let element: RelationshipElement
                do {
                    if let relationship = try await fetchRelationship(to: accountID) {
                        
                        switch (type, relationship.following) {
                        case (.follow, true):
                            element = .mutualLabel
                        case (.follow, false):
                            element = .followButton
                        case (.followRequest, _):
                            element = .acceptRejectButtons(isFollowing: relationship.following)
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
    
    private func fetchRelationship(to accountID: String) async throws -> Mastodon.Entity.Relationship? {
        guard let authBox = await AuthenticationServiceProvider.shared.currentActiveUser.value else { return nil }
        if let relationship = try await APIService.shared.relationship(forAccountIds: [accountID], authenticationBox: authBox).value.first {
            return relationship
        } else {
            return nil
        }
    }
    
    func navigateToProfile(_ account: Mastodon.Entity.Account) async throws {
        guard let me = await AuthenticationServiceProvider.shared.currentActiveUser.value?.cachedAccount else { return }
        if me.id == account.id {
            navigateToScene(.profile(.me(me)), .show)
        } else {
            let relationship = try await fetchRelationship(to: account.id)
            navigateToScene(.profile(.notMe(me: me, displayAccount: account, relationship: relationship)), .show)
        }
    }
}

extension _NotificationViewModel: Equatable {
    public static func ==(lhs: _NotificationViewModel, rhs: _NotificationViewModel) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
    
extension _NotificationViewModel {
    
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
        guard let accountID = accountInfo.firstAccountID, let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
        let startingAvatarRow = avatarRow
        avatarRow = .avatarRow(accountInfo, .fetching)
        do {
            let updatedElement: RelationshipElement
            let response = try await APIService.shared.follow(accountID, authenticationBox: authBox)
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
    private func doAcceptFollowRequest(_ accountInfo: NotificationSourceAccounts, accept: Bool) async {
        guard let accountID = accountInfo.firstAccountID, let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { return }
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
            self.avatarRow = .avatarRow(accountInfo, accept ? .acceptedLabel : .rejectedLabel)
        } catch {
            presentError(error)
            self.avatarRow = startingAvatarRow
        }
    }
}

extension _NotificationViewModel {
    static func viewModelsFromGroupedNotificationResults(_ results: Mastodon.Entity.GroupedNotificationsResults, myAccountID: String, navigateToScene: @escaping (SceneCoordinator.Scene, SceneCoordinator.Transition)->(), presentError: @escaping (Error)->()) -> [_NotificationViewModel] {
        let fullAccounts = results.accounts.reduce(into: [String : Mastodon.Entity.Account]()) { partialResult, account in
            partialResult[account.id] = account
        }
        let partialAccounts = results.partialAccounts? .reduce(into: [String : Mastodon.Entity.PartialAccountWithAvatar]()) { partialResult, account in
            partialResult[account.id] = account
        }
        
        let statuses = results.statuses.reduce(into: [String: Mastodon.Entity.Status](), { partialResult, status in
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
                return fullAccounts[accountID]?.avatarURL ?? partialAccounts?[accountID]?.avatarURL
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
                    navigateToStatus: {
                        Task {
                            guard let authBox = await AuthenticationServiceProvider.shared.currentActiveUser.value, let status else { return }
                            await navigateToScene(.thread(viewModel: ThreadViewModel(authenticationBox: authBox, optionalRoot: .root(context: .init(status: MastodonStatus(entity: status, showDespiteContentWarning: false))))), .show)
                        }
                    }),
                ruleViolationReport: group.ruleViolationReport,
                relationshipSeveranceEvent: group.relationshipSeveranceEvent
            )
            
            return _NotificationViewModel(info, navigateToScene: navigateToScene, presentError: presentError)
        }
    }
}

func boldedNameStringComponent(_ name: String) -> AttributedString {
    let nameComponent = PersonNameComponents(givenName: name).formatted(.name(style: .long).attributed)
    return nameComponent
}

let metaTextForHtmlToAttributedStringConversion = MetaText()
func attributedString(fromHtml html: String, emojis: [MastodonContent.Shortcode : String]) -> AttributedString {
    let content = MastodonContent(content: html, emojis: emojis)
    metaTextForHtmlToAttributedStringConversion.reset()
    do {
        let metaContent = try MastodonMetaContent.convert(document: content)
        metaTextForHtmlToAttributedStringConversion.configure(content: metaContent)
        guard let nsAttributedString = metaTextForHtmlToAttributedStringConversion.textView.attributedText else { throw AppError.unexpected("could not get attributed string from html") }
        return AttributedString(nsAttributedString)
    } catch {
        return AttributedString(html)
    }
}

public extension Mastodon.Entity.Status {
    struct ViewModel {
        public let content: AttributedString?
        public let isPinned: Bool
        public let accountDisplayName: String?
        public let accountFullName: String?
        public let accountAvatarUrl: URL?
        public var needsUserAttribution: Bool {
            return accountDisplayName != nil || accountFullName != nil
        }
        public let navigateToStatus: ()->()
    }
    
    func viewModel(navigateToStatus: @escaping ()->()) -> ViewModel {
        let displayableContent: AttributedString
        if let content {
            displayableContent = attributedString(fromHtml: content, emojis: account.emojis.asDictionary)
        } else {
            displayableContent = AttributedString()
        }
        return ViewModel(content: displayableContent, isPinned: false, accountDisplayName: account.displayName, accountFullName: account.acctWithDomain, accountAvatarUrl: account.avatarImageURL(), navigateToStatus: navigateToStatus)
    }
}
