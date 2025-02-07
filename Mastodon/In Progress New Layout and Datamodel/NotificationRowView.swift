// Copyright © 2025 Mastodon gGmbH. All rights reserved.
import Combine
import MastodonAsset
import MastodonCore
import MastodonLocalization
import MastodonMeta
import MastodonSDK
import MetaTextKit
import SwiftUI

// TODO: all strings need localization

extension Mastodon.Entity.NotificationType {

    func shouldShowIcon(grouped: Bool) -> Bool {
        return iconSystemName(grouped: grouped) != nil
    }

    func iconSystemName(grouped: Bool = false) -> String? {
        switch self {
        case .favourite:
            return "star.fill"
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
        case .poll, .severedRelationships, .moderationWarning, .adminReport,
            .adminSignUp:
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
    func actionSummaryLabel(firstAuthor: AuthorName, totalAuthorCount: Int)
        -> AttributedString
    {
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
                    composedString =
                        nameComponent + AttributedString(" favorited:")
                case .follow:
                    composedString =
                        nameComponent + AttributedString(" followed you")
                case .followRequest:
                    composedString =
                        nameComponent
                        + AttributedString(" requested to follow you")
                case .reblog:
                    composedString =
                        nameComponent + AttributedString(" boosted:")
                case .mention:
                    composedString =
                        nameComponent + AttributedString(" mentioned you:")
                case .poll:
                    composedString =
                        nameComponent
                        + AttributedString(" ran a poll that you voted in")  // TODO: add count of how many others voted
                case .status:
                    composedString =
                        nameComponent + AttributedString(" posted:")
                case .adminSignUp:
                    composedString =
                        nameComponent + AttributedString(" signed up")
                default:
                    composedString =
                        nameComponent + AttributedString("did something?")
                }
            } else {
                switch self {
                case .favourite:
                    composedString =
                        nameComponent
                        + AttributedString(
                            " and \(totalAuthorCount - 1) others favorited:")
                case .follow:
                    composedString =
                        nameComponent
                        + AttributedString(
                            " and \(totalAuthorCount - 1) others followed you")
                case .reblog:
                    composedString =
                        nameComponent
                        + AttributedString(
                            " and \(totalAuthorCount - 1) others boosted:")
                default:
                    composedString =
                        nameComponent
                        + AttributedString(
                            " and \(totalAuthorCount - 1) others did something")
                }
            }
            let nameStyling = AttributeContainer.font(
                .system(.body, weight: .bold))
            let nameContainer = AttributeContainer.personNameComponent(
                .givenName)
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
                return AttributedString(
                    "Someone reported \(postCount) posts from ") + boldedName
                    + AttributedString(" for rule violation.")
            } else {
                return AttributedString("Someone reported ") + boldedName
                    + AttributedString(" for rule violation.")
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
        let lostFollowersString =
            followersCount > 0 ? "\(followersCount) of your followers" : nil
        let lostFollowingString =
            followingCount > 0
            ? "\(followingCount) accounts that you follow" : nil
        guard
            let followersAndFollowingString = listFormatter.string(
                from: [lostFollowersString, lostFollowingString].compactMap {
                    $0
                })
        else {
            return nil
        }
        return AttributedString(baseString + followersAndFollowingString + ".")
    }
}

@ViewBuilder
func NotificationIconView(_ info: NotificationIconInfo) -> some View {
    HStack {
        Image(
            systemName: info.notificationType.iconSystemName(
                grouped: info.isGrouped) ?? "questionmark.square.dashed"
        )
        .foregroundStyle(info.notificationType.iconColor)
    }
    .font(.system(size: 25))
    .frame(width: 44)
    .fontWeight(.semibold)
}

@ViewBuilder
func NotificationIconView(systemName: String) -> some View {
    HStack {
        Image(
            systemName: systemName
        )
        .foregroundStyle(.secondary)
    }
    .font(.system(size: 25))
    .frame(width: 44)
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

    static func == (lhs: RelationshipElement, rhs: RelationshipElement) -> Bool
    {
        return lhs.description == rhs.description
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
            if let account: NotificationAuthor = MastodonFeedItemCacheManager
                .shared.fullAccount(id)
                ?? MastodonFeedItemCacheManager.shared.partialAccount(id),
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

    init(
        primaryAuthorAccount: Mastodon.Entity.Account?, avatarUrls: [URL],
        totalActorCount: Int
    ) {
        self.primaryAuthorAccount = primaryAuthorAccount
        self.avatarUrls = avatarUrls.removingDuplicates()
        self.totalActorCount = totalActorCount
    }
}

struct FilteredNotificationsRowView: View {
    class ViewModel: ObservableObject {
        @Published var isPreparingToNavigate: Bool = false
        @Published var componentViews: [NotificationViewComponent] = []
        var shouldShow: Bool = false

        init(policy: Mastodon.Entity.NotificationPolicy?) {
            if let policy {
                update(policy: policy)
            }
        }

        func update(policy: Mastodon.Entity.NotificationPolicy?) {
            guard let policy else {
                shouldShow = false
                return
            }
            componentViews = [
                .weightedText(
                    L10n.Scene.Notification.FilteredNotification.title, .bold),
                .weightedText(
                    L10n.Plural.FilteredNotificationBanner.subtitle(
                        policy.summary.pendingRequestsCount), .regular),
            ]
            shouldShow = policy.summary.pendingRequestsCount > 0
        }
    }

    @ObservedObject var viewModel: ViewModel

    init(_ viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        HStack {
            // LEFT GUTTER WITH TOP-ALIGNED ICON
            VStack {
                Spacer()
                NotificationIconView(systemName: "archivebox")
                Spacer().frame(maxHeight: .infinity)
            }
            
            // TEXT COMPONENTS
            VStack {
                ForEach(viewModel.componentViews) { component in
                    switch component {
                    case .weightedText(let string, let weight):
                        textComponent(string, fontWeight: weight)
                    default:
                        textComponent(component.id, fontWeight: .light)
                    }
                }
            }
            
            // DISCLOSURE INDICATOR (OR SPINNER)
            VStack {
                Spacer()
                if viewModel.isPreparingToNavigate {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    NotificationIconView(systemName: "chevron.forward")
                }
                Spacer()
            }
        }
    }
}

struct NotificationRowView: View {
    @ObservedObject var viewModel: NotificationRowViewModel

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
            VStack {
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
                    if accountInfo.totalActorCount == 1,
                        let primaryAuthorAccount = accountInfo
                            .primaryAuthorAccount
                    {
                        Task {
                            do {
                                try await viewModel.navigateToProfile(
                                    primaryAuthorAccount)
                            } catch {
                                viewModel.presentError(error)
                            }
                        }
                    }
                }
        case .text(let string):
            Text(string)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .weightedText(let string, let weight):
            textComponent(string, fontWeight: weight)
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

    func displayableAvatarCount(totalAvatarCount: Int, totalActorCount: Int)
        -> Int
    {
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
    func avatarRow(
        accountInfo: NotificationSourceAccounts,
        trailingElement: RelationshipElement
    ) -> some View {
        let maxAvatarCount = displayableAvatarCount(
            totalAvatarCount: accountInfo.avatarUrls.count,
            totalActorCount: accountInfo.totalActorCount)
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
            avatarRowTrailingElement(
                trailingElement, grouped: accountInfo.totalActorCount > 1)
        }
    }

    @ViewBuilder
    func avatarRowTrailingElement(
        _ elementType: RelationshipElement, grouped: Bool
    ) -> some View {
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

@ViewBuilder
func textComponent(_ string: String, fontWeight: SwiftUICore.Font.Weight?)
    -> some View
{
    Text(string)
        .fontWeight(fontWeight)
        .frame(maxWidth: .infinity, alignment: .leading)
}

enum NotificationViewComponent: Identifiable {
    case avatarRow(NotificationSourceAccounts, RelationshipElement)
    case text(AttributedString)
    case weightedText(String, SwiftUICore.Font.Weight)
    case status(Mastodon.Entity.Status.ViewModel)
    case hyperlinkButton(String, URL?)
    case _other(String)

    var id: String {
        switch self {
        case .avatarRow:
            return "avatar_row"
        case .text(let string):
            return string.description
        case .weightedText(let string, _):
            return string
        case .status:
            return "status"
        case .hyperlinkButton(let text, _):
            return text
        case ._other(let string):
            return string
        }
    }
}

func boldedNameStringComponent(_ name: String) -> AttributedString {
    let nameComponent = PersonNameComponents(givenName: name).formatted(
        .name(style: .long).attributed)
    return nameComponent
}

let metaTextForHtmlToAttributedStringConversion = MetaText()
func attributedString(
    fromHtml html: String, emojis: [MastodonContent.Shortcode: String]
) -> AttributedString {
    let content = MastodonContent(content: html, emojis: emojis)
    metaTextForHtmlToAttributedStringConversion.reset()
    do {
        let metaContent = try MastodonMetaContent.convert(document: content)
        metaTextForHtmlToAttributedStringConversion.configure(
            content: metaContent)
        guard
            let nsAttributedString = metaTextForHtmlToAttributedStringConversion
                .textView.attributedText
        else {
            throw AppError.unexpected(
                "could not get attributed string from html")
        }
        return AttributedString(nsAttributedString)
    } catch {
        return AttributedString(html)
    }
}

extension Mastodon.Entity.Status {
    public struct ViewModel {
        public let content: AttributedString?
        public let isPinned: Bool
        public let accountDisplayName: String?
        public let accountFullName: String?
        public let accountAvatarUrl: URL?
        public var needsUserAttribution: Bool {
            return accountDisplayName != nil || accountFullName != nil
        }
        public let navigateToStatus: () -> Void
    }

    public func viewModel(navigateToStatus: @escaping () -> Void) -> ViewModel {
        let displayableContent: AttributedString
        if let content {
            displayableContent = attributedString(
                fromHtml: content, emojis: account.emojis.asDictionary)
        } else {
            displayableContent = AttributedString()
        }
        return ViewModel(
            content: displayableContent, isPinned: false,
            accountDisplayName: account.displayName,
            accountFullName: account.acctWithDomain,
            accountAvatarUrl: account.avatarImageURL(),
            navigateToStatus: navigateToStatus)
    }
}
