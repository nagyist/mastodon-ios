//
//  DataSourceFacade+Profile.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-13.
//

import UIKit
import CoreDataStack
import MastodonCore
import MastodonSDK

extension DataSourceFacade {
    
    @MainActor
    static func coordinateToProfileScene(
        provider: DataSourceProvider & AuthContextProvider,
        target: StatusTarget,
        status: MastodonStatus
    ) async {
        let acct: String
        switch target {
        case .status:
            acct = status.reblog?.entity.account.acct ?? status.entity.account.acct
        case .reblog:
            acct = status.entity.account.acct
        }
        
        provider.coordinator.showLoading()
        
        let _redirectRecord = try? await Mastodon.API.Account.lookupAccount(
            session: .shared,
            domain: provider.authenticationBox.domain,
            query: .init(acct: acct),
            authorization: provider.authenticationBox.userAuthorization
        ).singleOutput().value
        
        provider.coordinator.hideLoading()
                
        guard let redirectRecord = _redirectRecord else {
            assertionFailure()
            return
        }

        await coordinateToProfileScene(
            provider: provider,
            account: redirectRecord
        )
    }

    @MainActor
    static func coordinateToProfileScene(
        provider: ViewControllerWithDependencies & AuthContextProvider,
        username: String,
        domain: String
    ) async {
        provider.coordinator.showLoading()

        do {
            guard let account = try await APIService.shared.fetchUser(
                username: username,
                domain: domain,
                authenticationBox: provider.authenticationBox
            ) else {
                return provider.coordinator.hideLoading()
            }

            provider.coordinator.hideLoading()

            await coordinateToProfileScene(provider: provider, account: account)
        } catch {
            provider.coordinator.hideLoading()
        }
    }

    @MainActor
    static func coordinateToProfileScene(
        provider: ViewControllerWithDependencies & AuthContextProvider,
        domain: String,
        accountID: String
    ) async {
        provider.coordinator.showLoading()

            do {
                let account = try await APIService.shared.accountInfo(
                    domain: domain,
                    userID: accountID,
                    authorization: provider.authenticationBox.userAuthorization
                ).value

                provider.coordinator.hideLoading()

                await coordinateToProfileScene(provider: provider, account: account)
            } catch {
                provider.coordinator.hideLoading()
        }
    }

    @MainActor
    public static func coordinateToProfileScene(
        provider: ViewControllerWithDependencies & AuthContextProvider,
        account: Mastodon.Entity.Account
    ) async {
        provider.coordinator.showLoading()

        guard let me = provider.authenticationBox.authentication.account(),
              let relationship = try? await APIService.shared.relationship(forAccounts: [account], authenticationBox: provider.authenticationBox).value.first else {
            return provider.coordinator.hideLoading()
        }

        provider.coordinator.hideLoading()

        let profileViewModel = ProfileViewModel(
            context: provider.context,
            authenticationBox: provider.authenticationBox,
            account: account,
            relationship: relationship,
            me: me
        )

        _ = provider.coordinator.present(
            scene: .profile(viewModel: profileViewModel),
            from: provider,
            transition: .show
        )
    }
}

extension DataSourceFacade {

    @MainActor
    static func coordinateToProfileScene(
        provider: DataSourceProvider & AuthContextProvider,
        status: MastodonStatus,
        mention: String,        // username,
        userInfo: [AnyHashable: Any]?
    ) async {
        let domain = provider.authenticationBox.domain
        
        guard
            let href = userInfo?["href"] as? String,
            let url = URL(string: href)
        else {
            return
        }
        let mentions = status.entity.mentions

        guard let mention = mentions.first(where: { $0.url == href }) else {
            _ = provider.coordinator.present(
                scene: .safari(url: url),
                from: provider,
                transition: .safariPresent(animated: true, completion: nil)
            )

            return
        }

        await DataSourceFacade.coordinateToProfileScene(provider: provider, domain: domain, accountID: mention.id)
    }

}

extension DataSourceFacade {
    static func createActivityViewController(
        dependency: NeedsDependency,
        account: Mastodon.Entity.Account
    ) -> UIActivityViewController {

        let activityViewController = UIActivityViewController(
            activityItems: [account.url],
            applicationActivities: [SafariActivity(sceneCoordinator: dependency.coordinator)]
        )
        return activityViewController
    }
    
    static func createActivityViewControllerForMastodonUser(status: Status, dependency: NeedsDependency) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: status.activityItems,
            applicationActivities: [SafariActivity(sceneCoordinator: dependency.coordinator)]
        )
        return activityViewController
    }
}
