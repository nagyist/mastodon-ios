// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import Foundation
import MastodonSDK
import MastodonCore

struct NotificationRequestsViewModel {
    let appContext: AppContext
    let authenticationBox: MastodonAuthenticationBox
    let coordinator: SceneCoordinator

    var requests: [Mastodon.Entity.NotificationRequest]

    init(appContext: AppContext, authenticationBox: MastodonAuthenticationBox, coordinator: SceneCoordinator, requests: [Mastodon.Entity.NotificationRequest]) {
        self.appContext = appContext
        self.authenticationBox = authenticationBox
        self.coordinator = coordinator
        self.requests = requests
    }
}
