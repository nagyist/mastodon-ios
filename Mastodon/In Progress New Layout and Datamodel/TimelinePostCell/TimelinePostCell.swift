//
//  TimelinePostCell.swift
//  Design
//
//  Created by Sam on 2024-03-27.
//

import SwiftUI
import MastodonSDK

@MainActor
class TimelinePostViewModel {
    let feedItemIdentifier: MastodonFeedItemIdentifier
    let statusItemIdentifier: MastodonFeedItemIdentifier?
    let authorAvatarUrl: URL?
    let boostingAccountName: String?
    let authorAccountName: String?
    let authorAccountFullNameWithDomain: String?
    
    let includePadding: Bool
    let showMediaGrid = false
    
    // TODO: give this something that conforms to TimelinePostInfo, rather than a generic feed item identifier
    init(feedItemIdentifier: MastodonFeedItemIdentifier, includePadding: Bool) {
        self.includePadding = includePadding
        self.feedItemIdentifier = feedItemIdentifier
        if let notification = MastodonFeedItemCacheManager.shared.cachedItem(feedItemIdentifier) as? NotificationInfo {
            boostingAccountName = notification.type == .reblog ? notification.authorName : nil
        } else {
            boostingAccountName = nil
        }
        if let status = MastodonFeedItemCacheManager.shared.filterableStatus(associatedWith: feedItemIdentifier) {
            statusItemIdentifier = .status(id: status.id)
            authorAccountName = status.account.displayNameWithFallback
            authorAccountFullNameWithDomain = status.account.acctWithDomain
            authorAvatarUrl = status.account.avatarURL
        } else {
            statusItemIdentifier = nil
            authorAvatarUrl = nil
            authorAccountName = nil
            authorAccountFullNameWithDomain = nil
        }
    }
}

struct TimelinePostCell: View {
    private let viewModel: TimelinePostViewModel
    
    init(_ identifier: MastodonFeedItemIdentifier, includePadding: Bool = true) {
        viewModel = TimelinePostViewModel(feedItemIdentifier: identifier, includePadding: includePadding)
    }
    
    var body: some View {
        Grid(alignment: .leading, verticalSpacing: 4) {
            if let boostingAccountName = viewModel.boostingAccountName {
                BoostHeader(boostingAccountName: boostingAccountName)
            }
            GridRow(alignment: .top) {
                if let authorAvatarUrl = viewModel.authorAvatarUrl {
                    AsyncImage(url: authorAvatarUrl)
                        //.resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.separator, lineWidth: 1)
                                .blendMode(.plusLighter)
                        }
                        .offset(x: 0, y: 4)
                }
                VStack(alignment: .leading) {
                    if let authorAccountName = viewModel.authorAccountName, let authorAccountFullNameWithDomain = viewModel.authorAccountFullNameWithDomain {
                        AuthorHeader(displayName: authorAccountName, fullAccountName: authorAccountFullNameWithDomain)
                    }
                    if let content = MastodonFeedItemCacheManager.shared.statusViewModel(associatedWith: viewModel.feedItemIdentifier)?.content {
                        Text(content)
                            .font(.callout)
                    }
                    if viewModel.showMediaGrid {
                        MediaGrid()
                    }
                    if let statusItemIdentifier = viewModel.statusItemIdentifier {
                        ActionButtons(statusItemIdentifier)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.all, viewModel.includePadding ? nil : 0)
    }

}
//
//#Preview {
//    TimelinePostCell()
//}
