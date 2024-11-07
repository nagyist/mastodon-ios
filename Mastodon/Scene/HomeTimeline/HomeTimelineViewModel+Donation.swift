// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import Combine
import Foundation
import MastodonSDK

extension HomeTimelineViewModel {

    func askForDonationIfPossible() async {
        var userAuthentication = authContext.mastodonAuthenticationBox
            .authentication
        var accountCreatedAt = userAuthentication.accountCreatedAt
        if accountCreatedAt == nil {
            do {
                let updated = try await AuthenticationViewModel.verifyAndSaveAuthentication(context: context, domain: userAuthentication.domain, clientID: userAuthentication.clientID, clientSecret: userAuthentication.clientSecret, userToken: userAuthentication.userAccessToken
                )
                accountCreatedAt = updated.createdAt
            } catch {
                return
            }
        }

        guard let accountCreatedAt = accountCreatedAt  else { return }
        guard
            Mastodon.Entity.DonationCampaign.isEligibleForDonationsBanner(
                domain: userAuthentication.domain,
                accountCreationDate: accountCreatedAt)
        else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            let seed = Mastodon.Entity.DonationCampaign.donationSeed(
                username: userAuthentication.username,
                domain: userAuthentication.domain)

            do {
                let campaign = try await self.context.apiService
                    .getDonationCampaign(seed: seed, source: nil).value
                guard !Mastodon.Entity.DonationCampaign.hasPreviouslyDismissed(campaign.id) && !Mastodon.Entity.DonationCampaign.hasPreviouslyContributed(campaign.id) else { return }
                onPresentDonationCampaign.send(campaign)
            } catch {
                // no-op
            }
        }
    }
}
