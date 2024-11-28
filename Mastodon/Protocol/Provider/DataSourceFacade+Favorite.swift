//
//  DataSourceFacade+Favorite.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-21.
//

import UIKit
import CoreData
import MastodonSDK
import MastodonCore

extension DataSourceFacade {
    @MainActor
    public static func responseToStatusFavoriteAction(
        provider: DataSourceProvider & AuthContextProvider,
        status: MastodonStatus
    ) async throws {
        FeedbackGenerator.shared.generate(.selectionChanged)

        let updatedStatus = try await APIService.shared.favorite(
            status: status,
            authenticationBox: provider.authenticationBox
        ).value
        
        let newStatus: MastodonStatus = .fromEntity(updatedStatus)
        newStatus.showDespiteContentWarning = status.showDespiteContentWarning
        newStatus.showDespiteFilter = status.showDespiteFilter
        
        provider.update(status: newStatus, intent: .favorite(updatedStatus.favourited == true))
    }
}
