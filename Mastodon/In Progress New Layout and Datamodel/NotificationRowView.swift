// Copyright © 2025 Mastodon gGmbH. All rights reserved.
import SwiftUI
import MastodonSDK
import MastodonAsset
import MastodonLocalization
import MastodonCore
import Combine

// TODO: all strings need localization

@MainActor
struct GroupedNotificationRowView: View {
    @ObservedObject var viewModel: NotificationRowViewModel
    
    init(viewModel: NotificationRowViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
            HStack(alignment: .top) {
                if let iconName = viewModel.type.iconSystemName(grouped: viewModel.grouped) {
                    NotificationIconView(for: viewModel.type, iconName: iconName)
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
        case is FollowNotificationViewModel:
            if viewModel.grouped {
                AvatarGroupRow(avatars: viewModel.authorAvatarUrls)
                Text("\(viewModel.authorsDescription) followed you")
            } else {
                let viewModel = viewModel as! FollowNotificationViewModel
                HStack {
                    AvatarGroupRow(avatars: viewModel.authorAvatarUrls)
                    switch viewModel.followButtonAction {
                    case .action(let buttonText):
                        Button(buttonText) {}
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .bold()
                        // TODO: implement follow action
                    case .unfetched, .fetching:
                        ProgressView()
                            .progressViewStyle(.circular)
                    case .noneNeeded, .error:
                        Spacer().frame(width: 0)
                    }
                }
                Text("\(viewModel.authorName) followed you")
            }
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
            ForEach(avatars, id: \.self) { avatarUrl in
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
            return "chart.bar.xaxis"
        case .adminReport:
            return "info.circle"
        case .severedRelationships:
            return "person.badge.minus"
        case .moderationWarning:
            return "exclamationmark.shield"
        case ._other:
            return "questionmark.square.dashed"
        case .followRequest, .mention, .status, .update, .adminSignUp:
            return nil
        }
    }
    
    var iconColor: Color {
        switch self {
        case .favourite:
            return .orange
        case .reblog:
            return .green
        case .follow:
            return Color(asset: Asset.Colors.accent)
        case .poll:
            return .secondary
        case .adminReport:
            return Color(asset: Asset.Colors.accent)
        case .severedRelationships:
            return .secondary
        case .moderationWarning:
            return Color(asset: Asset.Colors.accent)
        case ._other:
            return .gray
        case .followRequest, .mention, .status, .update, .adminSignUp:
            return .gray
        }
    }
}

@ViewBuilder
func NotificationIconView(for type: Mastodon.Entity.NotificationType, iconName: String) -> some View {
    HStack {
        Image(systemName: iconName)
            .foregroundStyle(type.iconColor)
    }
    .font(.system(size: 25))
    .frame(width: 44)
    .symbolVariant(.fill)
    .fontWeight(.semibold)
}

enum AvailableFollowAction: Equatable {
    case unfetched
    case fetching
    case error(Error)
    case noneNeeded
    case action(buttonText: String)
    
    var description: String {
        switch self {
        case .unfetched:
            return "unfetched"
        case .fetching:
            return "fetching"
        case .error(let error):
            return "error(\(error.localizedDescription))"
        case .noneNeeded:
            return "noneNeeded"
        case .action(let buttonText):
            return "action(\(buttonText))"
        }
    }
    
    static func == (lhs: AvailableFollowAction, rhs: AvailableFollowAction) -> Bool {
        return lhs.description == rhs.description
    }
    
}

protocol NotificationInfo {
    var type: Mastodon.Entity.NotificationType { get }
    var isGrouped: Bool { get }
    var authorsCount: Int { get }
    var primaryAuthorAccount: Mastodon.Entity.Account? { get }
    var authorName: String { get }
    var authorAvatarUrls: [URL] { get }
    func availableFollowAction() async -> AvailableFollowAction?
    func fetchAvailableFollowAction() async -> AvailableFollowAction
}
extension NotificationInfo {
    var authorsDescription: String {
        if authorsCount > 1 {
            return "\(authorName) and \(authorsCount - 1) others"
        } else {
            return authorName
        }
    }
    var avatarCount: Int {
        min(authorsCount, 8)
    }
    var isGrouped: Bool {
        return authorsCount > 1
    }
}

extension Mastodon.Entity.Notification: NotificationInfo {
    var authorsCount: Int { 1 }
    var primaryAuthorAccount: Mastodon.Entity.Account? { account }
    var authorName: String { account.displayNameWithFallback }
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
    func availableFollowAction() -> AvailableFollowAction? {
        if let relationship = MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: account.id) {
            if let text = relationship.followButtonText {
                return .action(buttonText: text)
            }
        }
        return nil
    }
    
    @MainActor
    func fetchAvailableFollowAction() async -> AvailableFollowAction {
        do {
            try await fetchRelationship()
            if let availableAction = availableFollowAction() {
                return availableAction
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
    
    @MainActor
    var primaryAuthorAccount: Mastodon.Entity.Account? {
        guard let firstAccountID = sampleAccountIDs.first else { return nil }
        return MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID)
    }
    
    var authorsCount: Int { notificationsCount }
    
    @MainActor
    var authorName: String {
        guard let firstAccountID = sampleAccountIDs.first, let firstAccount = MastodonFeedItemCacheManager.shared.fullAccount(firstAccountID) else { return "" }
        return firstAccount.displayNameWithFallback
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
    func availableFollowAction() -> AvailableFollowAction? {
        guard authorsCount == 1 && type == .follow else { return .noneNeeded }
        guard let firstAccountID = sampleAccountIDs.first else { return .noneNeeded }
        if let relationship = MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: firstAccountID), let text = relationship.followButtonText {
            return .action(buttonText: text)
        }
        return nil
    }
    
    @MainActor
    func fetchAvailableFollowAction() async -> AvailableFollowAction {
        do {
            try await fetchRelationship()
            if let availableAction = availableFollowAction() {
                return availableAction
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
}

extension Mastodon.Entity.Relationship {
    @MainActor
    var followButtonText: String? {
        if following {
            return L10n.Common.Controls.Friendship.following
        } else {
            if let account: NotificationAuthor = MastodonFeedItemCacheManager.shared.fullAccount(id) ?? MastodonFeedItemCacheManager.shared.partialAccount(id),
               account.locked
            {
                if requested {
                    return L10n.Common.Controls.Friendship.pending
                } else {
                    return L10n.Common.Controls.Friendship.request
                }
            }
            return L10n.Common.Controls.Friendship.follow
        }
    }
}
