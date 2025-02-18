//
//  RemoteThreadViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-12.
//

import UIKit
import CoreDataStack
import MastodonCore
import MastodonSDK

final class RemoteThreadViewModel: ThreadViewModel {
        
    init(
        authenticationBox: MastodonAuthenticationBox,
        statusID: Mastodon.Entity.Status.ID
    ) {
        super.init(
            authenticationBox: authenticationBox,
            optionalRoot: nil
        )
        
        Task { @MainActor in
            let response = try await APIService.shared.status(
                statusID: statusID,
                authenticationBox: authenticationBox
            )
            
            let threadContext = MastodonItemIdentifier.Thread.Context(status: .fromEntity(response.value))
            self.root = .root(context: threadContext)
            
        }   // end Task
    }
    
    init(
        authenticationBox: MastodonAuthenticationBox,
        notificationID: Mastodon.Entity.Notification.ID
    ) {
        super.init(
            authenticationBox: authenticationBox,
            optionalRoot: nil
        )
        
        Task { @MainActor in
            let response = try await APIService.shared.notification(
                notificationID: notificationID,
                authenticationBox: authenticationBox
            )
            
            guard let status = response.value.status else { return }
            
            let threadContext = MastodonItemIdentifier.Thread.Context(status: .fromEntity(status))
            self.root = .root(context: threadContext)
        }   // end Task
    }
    
}
