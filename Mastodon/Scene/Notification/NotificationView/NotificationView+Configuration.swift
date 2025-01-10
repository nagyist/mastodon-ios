//
//  NotificationView+Configuration.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-21.
//

import UIKit
import Combine
import MastodonUI
import CoreDataStack
import MetaTextKit
import MastodonMeta
import Meta
import MastodonAsset
import MastodonCore
import MastodonLocalization
import MastodonSDK

extension NotificationView {
    public func configure(feed: MastodonFeed, authenticationBox: MastodonAuthenticationBox) {
        guard  let notification = feed.notification else {
            assertionFailure()
            return
        }

        let entity = MastodonNotification.fromEntity(
            notification,
            relationship: feed.relationship
        )

        configure(notification: entity, authenticationBox: authenticationBox)
    }
}

extension NotificationView {
    
    public func configure(notificationItem: MastodonFeedItemIdentifier) {
        let item = MastodonFeedItemCacheManager.shared.cachedItem(notificationItem)
        guard let notification = item as? Mastodon.Entity.Notification, let authBox = AuthenticationServiceProvider.shared.currentActiveUser.value else { assert(false); return }
 
        func contentDisplayMode(_ status: Mastodon.Entity.Status) -> StatusView.ContentDisplayMode {
            let contentDisplayModel = StatusView.ContentConcealViewModel(status: status, filterBox: StatusFilterService.shared.activeFilterBox, filterContext: .notifications, showDespiteFilter: MastodonFeedItemCacheManager.shared.shouldShowDespiteFilter(statusID: status.id), showDespiteContentWarning: MastodonFeedItemCacheManager.shared.shouldShowDespiteContentWarning(statusID: status.id))
            return contentDisplayModel.effectiveDisplayMode
        }
        
        switch notification.type {
        case .follow:
            setAuthorContainerBottomPaddingViewDisplay(isHidden: true)
        case .followRequest:
            setFollowRequestAdaptiveMarginContainerViewDisplay(isHidden: true)
        case .mention, .status:
            if let status = notification.status {
                statusView.configure(status: status, contentDisplayMode: contentDisplayMode(status))
                setStatusViewDisplay()
            }
        case .reblog, .favourite, .poll:
            if let status = notification.status {
                quoteStatusView.configure(status: status, contentDisplayMode: contentDisplayMode(status))
                setQuoteStatusViewDisplay()
            }
        case .moderationWarning:
            // case handled in `AccountWarningNotificationCell.swift`
            break
        case ._other:
            setAuthorContainerBottomPaddingViewDisplay()
            assertionFailure()
        }
        
        configure(notification: notification, authenticationBox: authBox)
    }
    
    public func configure(notification: Mastodon.Entity.Notification, authenticationBox: MastodonAuthenticationBox) {
        configureAuthor(notification: notification, authenticationBox: authenticationBox)
        
        func contentDisplayMode(_ status: Mastodon.Entity.Status) -> StatusView.ContentDisplayMode {
            let contentDisplayModel = StatusView.ContentConcealViewModel(status: status, filterBox: StatusFilterService.shared.activeFilterBox, filterContext: .notifications, showDespiteFilter: MastodonFeedItemCacheManager.shared.shouldShowDespiteFilter(statusID: status.id), showDespiteContentWarning: MastodonFeedItemCacheManager.shared.shouldShowDespiteContentWarning(statusID: status.id))
            return contentDisplayModel.effectiveDisplayMode
        }

        switch notification.type {
        case .follow:
            setAuthorContainerBottomPaddingViewDisplay(isHidden: true)
        case .followRequest:
            setFollowRequestAdaptiveMarginContainerViewDisplay(isHidden: false)
        case .mention, .status:
            if let status = notification.status {
                statusView.configure(status: status, contentDisplayMode: contentDisplayMode(status))
                setStatusViewDisplay()
            }
        case .reblog, .favourite, .poll:
            if let status = notification.status {
                quoteStatusView.configure(status: status, contentDisplayMode: contentDisplayMode(status))
                setQuoteStatusViewDisplay()
            }
        case .moderationWarning:
            // case handled in `AccountWarningNotificationCell.swift`
            break
        case ._other:
            setAuthorContainerBottomPaddingViewDisplay()
            assertionFailure()
        }
        
    }
    
    public func configure(notification: MastodonNotification, authenticationBox: MastodonAuthenticationBox) {
        configureAuthor(notification: notification, authenticationBox: authenticationBox)
        
        func contentDisplayMode(_ status: MastodonStatus) -> StatusView.ContentDisplayMode {
            let contentDisplayModel = StatusView.ContentConcealViewModel(status: status, filterBox: StatusFilterService.shared.activeFilterBox, filterContext: .notifications)
            return contentDisplayModel.effectiveDisplayMode
        }

        switch notification.entity.type {
        case .follow:
            setAuthorContainerBottomPaddingViewDisplay(isHidden: true)
        case .followRequest:
            setFollowRequestAdaptiveMarginContainerViewDisplay(isHidden: true)
        case .mention, .status:
            if let status = notification.status {
                statusView.configure(status: status, contentDisplayMode: contentDisplayMode(status))
                setStatusViewDisplay()
            }
        case .reblog, .favourite, .poll:
            if let status = notification.status {
                quoteStatusView.configure(status: status, contentDisplayMode: contentDisplayMode(status))
                setQuoteStatusViewDisplay()
            }
        case .moderationWarning:
            // case handled in `AccountWarningNotificationCell.swift`
            break
        case ._other:
            setAuthorContainerBottomPaddingViewDisplay()
            assertionFailure()
        }
        
    }
    
    private func configureAuthor(notification: Mastodon.Entity.Notification, authenticationBox: MastodonAuthenticationBox) {
        let author = notification.account

        // author avatar
        avatarButton.avatarImageView.configure(with: author.avatarImageURL())
        avatarButton.avatarImageView.configure(cornerConfiguration: .init(corner: .fixed(radius: 12)))

        // author name
        let metaAuthorName: MetaContent
        do {
            let content = MastodonContent(content: author.displayNameWithFallback, emojis: author.emojis.asDictionary)
            metaAuthorName = try MastodonMetaContent.convert(document: content)
        } catch {
            assertionFailure(error.localizedDescription)
            metaAuthorName = PlaintextMetaContent(string: author.displayNameWithFallback)
        }
        authorNameLabel.configure(content: metaAuthorName)

        // username
        let metaUsername = PlaintextMetaContent(string: "@\(author.acct)")
        authorUsernameLabel.configure(content: metaUsername)

        // notification type indicator
        let notificationIndicatorText: MetaContent?
        if let type = MastodonNotificationType(rawValue: notification.type.rawValue) {
            // TODO: fix the i18n. The subject should assert place at the string beginning
            func createMetaContent(text: String, emojis: MastodonContent.Emojis) -> MetaContent {
                let content = MastodonContent(content: text, emojis: emojis)
                guard let metaContent = try? MastodonMetaContent.convert(document: content) else {
                    return PlaintextMetaContent(string: text)
                }
                return metaContent
            }

            switch type {
            case .follow:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.followedYou,
                    emojis: author.emojis.asDictionary
                )
            case .followRequest:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.requestToFollowYou,
                    emojis: author.emojis.asDictionary
                )
            case .mention:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.mentionedYou,
                    emojis: author.emojis.asDictionary
                )
            case .reblog:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.rebloggedYourPost,
                    emojis: author.emojis.asDictionary
                )
            case .favourite:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.favoritedYourPost,
                    emojis: author.emojis.asDictionary
                )
            case .poll:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.pollHasEnded,
                    emojis: author.emojis.asDictionary
                )
            case .status:
                notificationIndicatorText = createMetaContent(
                    text: .empty,
                    emojis: author.emojis.asDictionary
                )
            case ._other:
                notificationIndicatorText = nil
            }

            var actions = [UIAccessibilityCustomAction]()

            // these notifications can be directly actioned to view the profile
            if type != .follow, type != .followRequest {
                actions.append(
                    UIAccessibilityCustomAction(
                        name: L10n.Common.Controls.Status.showUserProfile,
                        image: nil
                    ) { [weak self] _ in
                        guard let self, let delegate = self.delegate else { return false }
                        delegate.notificationView(self, authorAvatarButtonDidPressed: self.avatarButton)
                        return true
                    }
                )
            }

            if type == .followRequest {
                actions.append(
                    UIAccessibilityCustomAction(
                        name: L10n.Common.Controls.Actions.confirm,
                        image: Asset.Editing.checkmark20.image
                    ) { [weak self] _ in
                        guard let self, let delegate = self.delegate else { return false }
                        delegate.notificationView(self, acceptFollowRequestButtonDidPressed: self.acceptFollowRequestButton)
                        return true
                    }
                )

                actions.append(
                    UIAccessibilityCustomAction(
                        name: L10n.Common.Controls.Actions.delete,
                        image: Asset.Circles.forbidden20.image
                    ) { [weak self] _ in
                        guard let self, let delegate = self.delegate else { return false }
                        delegate.notificationView(self, rejectFollowRequestButtonDidPressed: self.rejectFollowRequestButton)
                        return true
                    }
                )
            }

            notificationActions = actions

        } else {
            notificationIndicatorText = nil
            notificationActions = []
        }

        if let notificationIndicatorText {
            notificationTypeIndicatorLabel.configure(content: notificationIndicatorText)
        } else {
            notificationTypeIndicatorLabel.reset()
        }

        if let me = authenticationBox.cachedAccount {
            let isMyself = (author == me)
            let isMuting: Bool
            let isBlocking: Bool

            if let relationship = MastodonFeedItemCacheManager.shared.currentRelationship(toAccount: notification.account.id) {
                isMuting = relationship.muting
                isBlocking = relationship.blocking || relationship.domainBlocking
            } else {
                isMuting = false
                isBlocking = false
            }

            let menuContext = NotificationView.AuthorMenuContext(name: metaAuthorName.string, isMuting: isMuting, isBlocking: isBlocking, isMyself: isMyself)
            let (menu, actions) = setupAuthorMenu(menuContext: menuContext)
            menuButton.menu = menu
            authorActions = actions
            menuButton.showsMenuAsPrimaryAction = true

            menuButton.isHidden = menuContext.isMyself
        }

        timestampUpdatePublisher
            .prepend(Date())
            .eraseToAnyPublisher()
            .sink { [weak self] now in
                guard let self, let type = MastodonNotificationType(rawValue: notification.type.rawValue) else { return }

                let formattedTimestamp =  notification.createdAt.localizedAbbreviatedSlowedTimeAgoSinceNow
                dateLabel.configure(content: PlaintextMetaContent(string: formattedTimestamp))

                self.accessibilityLabel = [
                    "\(author.displayNameWithFallback) \(type)",
                    author.acct,
                    formattedTimestamp
                ].joined(separator: ", ")
                if self.statusView.isHidden == false {
                    self.accessibilityLabel! += ", " + (self.statusView.accessibilityLabel ?? "")
                }
                if self.quoteStatusViewContainerView.isHidden == false {
                    self.accessibilityLabel! += ", " + (self.quoteStatusView.accessibilityLabel ?? "")
                }

            }
            .store(in: &disposeBag)
        
        if notification.type == .followRequest {
            let followRequestState = MastodonFeedItemCacheManager.shared.followRequestState(forFollowRequestNotification: notification.id).state
            switch followRequestState {
            case .none:
                break
            case .isAccept:
                self.rejectFollowRequestButtonShadowBackgroundContainer.isHidden = true
                self.acceptFollowRequestButton.isUserInteractionEnabled = false
                self.acceptFollowRequestButton.setImage(nil, for: .normal)
                self.acceptFollowRequestButton.setTitle(L10n.Scene.Notification.FollowRequest.accepted, for: .normal)
            case .isReject:
                self.acceptFollowRequestButtonShadowBackgroundContainer.isHidden = true
                self.rejectFollowRequestButton.isUserInteractionEnabled = false
                self.rejectFollowRequestButton.setImage(nil, for: .normal)
                self.rejectFollowRequestButton.setTitle(L10n.Scene.Notification.FollowRequest.rejected, for: .normal)
            case .isAccepting:
                self.acceptFollowRequestActivityIndicatorView.startAnimating()
                self.acceptFollowRequestButton.tintColor = .clear
                self.acceptFollowRequestButton.setTitleColor(.clear, for: .normal)
            case .isRejecting:
                self.rejectFollowRequestActivityIndicatorView.startAnimating()
                self.rejectFollowRequestButton.tintColor = .clear
                self.rejectFollowRequestButton.setTitleColor(.clear, for: .normal)
            }
            if !followRequestState.isTransient {
                followRequestAdaptiveMarginContainerView.isHidden = false
                
                self.acceptFollowRequestActivityIndicatorView.stopAnimating()
                self.acceptFollowRequestButton.tintColor = .white
                self.acceptFollowRequestButton.setTitleColor(.white, for: .normal)
                
                self.rejectFollowRequestActivityIndicatorView.stopAnimating()
                self.rejectFollowRequestButton.tintColor = .black
                self.rejectFollowRequestButton.setTitleColor(.black, for: .normal)
            }
        } else {
            followRequestAdaptiveMarginContainerView.isHidden = true
        }
    }

    private func configureAuthor(notification: MastodonNotification, authenticationBox: MastodonAuthenticationBox) {
        let author = notification.account

        // author avatar
        avatarButton.avatarImageView.configure(with: author.avatarImageURL())
        avatarButton.avatarImageView.configure(cornerConfiguration: .init(corner: .fixed(radius: 12)))

        // author name
        let metaAuthorName: MetaContent
        do {
            let content = MastodonContent(content: author.displayNameWithFallback, emojis: author.emojis.asDictionary)
            metaAuthorName = try MastodonMetaContent.convert(document: content)
        } catch {
            assertionFailure(error.localizedDescription)
            metaAuthorName = PlaintextMetaContent(string: author.displayNameWithFallback)
        }
        authorNameLabel.configure(content: metaAuthorName)

        // username
        let metaUsername = PlaintextMetaContent(string: "@\(author.acct)")
        authorUsernameLabel.configure(content: metaUsername)

        // notification type indicator
        let notificationIndicatorText: MetaContent?
        if let type = MastodonNotificationType(rawValue: notification.entity.type.rawValue) {
            // TODO: fix the i18n. The subject should assert place at the string beginning
            func createMetaContent(text: String, emojis: MastodonContent.Emojis) -> MetaContent {
                let content = MastodonContent(content: text, emojis: emojis)
                guard let metaContent = try? MastodonMetaContent.convert(document: content) else {
                    return PlaintextMetaContent(string: text)
                }
                return metaContent
            }

            switch type {
            case .follow:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.followedYou,
                    emojis: author.emojis.asDictionary
                )
            case .followRequest:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.requestToFollowYou,
                    emojis: author.emojis.asDictionary
                )
            case .mention:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.mentionedYou,
                    emojis: author.emojis.asDictionary
                )
            case .reblog:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.rebloggedYourPost,
                    emojis: author.emojis.asDictionary
                )
            case .favourite:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.favoritedYourPost,
                    emojis: author.emojis.asDictionary
                )
            case .poll:
                notificationIndicatorText = createMetaContent(
                    text: L10n.Scene.Notification.NotificationDescription.pollHasEnded,
                    emojis: author.emojis.asDictionary
                )
            case .status:
                notificationIndicatorText = createMetaContent(
                    text: .empty,
                    emojis: author.emojis.asDictionary
                )
            case ._other:
                notificationIndicatorText = nil
            }

            var actions = [UIAccessibilityCustomAction]()

            // these notifications can be directly actioned to view the profile
            if type != .follow, type != .followRequest {
                actions.append(
                    UIAccessibilityCustomAction(
                        name: L10n.Common.Controls.Status.showUserProfile,
                        image: nil
                    ) { [weak self] _ in
                        guard let self, let delegate = self.delegate else { return false }
                        delegate.notificationView(self, authorAvatarButtonDidPressed: self.avatarButton)
                        return true
                    }
                )
            }

            if type == .followRequest {
                actions.append(
                    UIAccessibilityCustomAction(
                        name: L10n.Common.Controls.Actions.confirm,
                        image: Asset.Editing.checkmark20.image
                    ) { [weak self] _ in
                        guard let self, let delegate = self.delegate else { return false }
                        delegate.notificationView(self, acceptFollowRequestButtonDidPressed: self.acceptFollowRequestButton)
                        return true
                    }
                )

                actions.append(
                    UIAccessibilityCustomAction(
                        name: L10n.Common.Controls.Actions.delete,
                        image: Asset.Circles.forbidden20.image
                    ) { [weak self] _ in
                        guard let self, let delegate = self.delegate else { return false }
                        delegate.notificationView(self, rejectFollowRequestButtonDidPressed: self.rejectFollowRequestButton)
                        return true
                    }
                )
            }

            notificationActions = actions

        } else {
            notificationIndicatorText = nil
            notificationActions = []
        }

        if let notificationIndicatorText {
            notificationTypeIndicatorLabel.configure(content: notificationIndicatorText)
        } else {
            notificationTypeIndicatorLabel.reset()
        }

        if let me = authenticationBox.cachedAccount {
            let isMyself = (author == me)
            let isMuting: Bool
            let isBlocking: Bool

            if let relationship = notification.relationship {
                isMuting = relationship.muting
                isBlocking = relationship.blocking || relationship.domainBlocking
            } else {
                isMuting = false
                isBlocking = false
            }

            let menuContext = NotificationView.AuthorMenuContext(name: metaAuthorName.string, isMuting: isMuting, isBlocking: isBlocking, isMyself: isMyself)
            let (menu, actions) = setupAuthorMenu(menuContext: menuContext)
            menuButton.menu = menu
            authorActions = actions
            menuButton.showsMenuAsPrimaryAction = true

            menuButton.isHidden = menuContext.isMyself
        }

        timestampUpdatePublisher
            .prepend(Date())
            .eraseToAnyPublisher()
            .sink { [weak self] now in
                guard let self, let type = MastodonNotificationType(rawValue: notification.entity.type.rawValue) else { return }

                let formattedTimestamp =  notification.entity.createdAt.localizedAbbreviatedSlowedTimeAgoSinceNow
                dateLabel.configure(content: PlaintextMetaContent(string: formattedTimestamp))

                self.accessibilityLabel = [
                    "\(author.displayNameWithFallback) \(type)",
                    author.acct,
                    formattedTimestamp
                ].joined(separator: ", ")
                if self.statusView.isHidden == false {
                    self.accessibilityLabel! += ", " + (self.statusView.accessibilityLabel ?? "")
                }
                if self.quoteStatusViewContainerView.isHidden == false {
                    self.accessibilityLabel! += ", " + (self.quoteStatusView.accessibilityLabel ?? "")
                }

            }
            .store(in: &disposeBag)

        switch notification.followRequestState.state {
            case .isAccept:
                self.rejectFollowRequestButtonShadowBackgroundContainer.isHidden = true
                self.acceptFollowRequestButton.isUserInteractionEnabled = false
                self.acceptFollowRequestButton.setImage(nil, for: .normal)
                self.acceptFollowRequestButton.setTitle(L10n.Scene.Notification.FollowRequest.accepted, for: .normal)
            case .isReject:
                self.acceptFollowRequestButtonShadowBackgroundContainer.isHidden = true
                self.rejectFollowRequestButton.isUserInteractionEnabled = false
                self.rejectFollowRequestButton.setImage(nil, for: .normal)
                self.rejectFollowRequestButton.setTitle(L10n.Scene.Notification.FollowRequest.rejected, for: .normal)
            default:
                break
        }

        let state = notification.transientFollowRequestState.state
        if state == .isAccepting {
            self.acceptFollowRequestActivityIndicatorView.startAnimating()
            self.acceptFollowRequestButton.tintColor = .clear
            self.acceptFollowRequestButton.setTitleColor(.clear, for: .normal)
        } else {
            self.acceptFollowRequestActivityIndicatorView.stopAnimating()
            self.acceptFollowRequestButton.tintColor = .white
            self.acceptFollowRequestButton.setTitleColor(.white, for: .normal)
        }
        if state == .isRejecting {
            self.rejectFollowRequestActivityIndicatorView.startAnimating()
            self.rejectFollowRequestButton.tintColor = .clear
            self.rejectFollowRequestButton.setTitleColor(.clear, for: .normal)
        } else {
            self.rejectFollowRequestActivityIndicatorView.stopAnimating()
            self.rejectFollowRequestButton.tintColor = .black
            self.rejectFollowRequestButton.setTitleColor(.black, for: .normal)
        }

        if state == .isAccept {
            self.rejectFollowRequestButtonShadowBackgroundContainer.isHidden = true
        }
        if state == .isReject {
            self.acceptFollowRequestButtonShadowBackgroundContainer.isHidden = true
        }
    }
}

extension MastodonFollowRequestState.State {
    var isTransient: Bool {
        switch self {
        case .none, .isAccept, .isReject:
            return false
        case .isAccepting, .isRejecting:
            return true
        }
    }
}
