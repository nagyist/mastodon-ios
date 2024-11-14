//
//  SearchHistoryViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-7-15.
//

import UIKit
import Combine
import CoreDataStack
import MastodonCore

final class SearchHistoryViewModel {
    var disposeBag = Set<AnyCancellable>()

    // input
    let context: AppContext
    let authenticationBox: MastodonAuthenticationBox
    @Published public var items: [Persistence.SearchHistory.Item]

    // output
    var diffableDataSource: UICollectionViewDiffableDataSource<SearchHistorySection, SearchHistoryItem>?

    init(context: AppContext, authenticationBox: MastodonAuthenticationBox) {
        self.context = context
        self.authenticationBox = authenticationBox
        self.items = (try? FileManager.default.searchItems(for: authenticationBox)) ?? []
    }

}
