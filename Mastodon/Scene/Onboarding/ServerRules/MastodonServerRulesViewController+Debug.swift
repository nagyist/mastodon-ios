//
//  MastodonServerRulesViewController+Debug.swift
//  Mastodon
//
//  Created by MainasuK on 2022-4-27.
//

import UIKit
import MastodonCore

#if DEBUG

extension MastodonRegisterViewController {
    
    @MainActor
    static func create(
        context: AppContext,
        coordinator: SceneCoordinator,
        domain: String
    ) async throws -> MastodonRegisterViewController {
        let viewController = MastodonRegisterViewController()
        viewController.context = context
        viewController.coordinator = coordinator
        
        let instanceResponse = try await APIService.shared.instance(domain: domain, authenticationBox: nil).singleOutput()
        let applicationResponse = try await APIService.shared.createApplication(domain: domain).singleOutput()
        let accessTokenResponse = try await APIService.shared.applicationAccessToken(
            domain: domain,
            clientID: applicationResponse.value.clientID!,
            clientSecret: applicationResponse.value.clientSecret!,
            redirectURI: applicationResponse.value.redirectURI!
        ).singleOutput()
        
        viewController.viewModel = MastodonRegisterViewModel(
            context: context,
            domain: domain,
            authenticateInfo: .init(
                domain: domain,
                application: applicationResponse.value
            )!,
            instance: instanceResponse.value,
            applicationToken: accessTokenResponse.value
        )
        
        return viewController
    }
    
}

#endif

