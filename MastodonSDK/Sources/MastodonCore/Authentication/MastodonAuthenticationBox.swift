//
//  MastodonAuthenticationBox.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-7-20.
//

import Foundation
import CoreDataStack
import MastodonSDK

public protocol AuthContextProvider {
    var authenticationBox: MastodonAuthenticationBox { get }
}

public struct MastodonAuthenticationBox: UserIdentifier {
    public let authentication: MastodonAuthentication
    public var domain: String { authentication.domain }
    public var userID: String { authentication.userID }
    public var appAuthorization: Mastodon.API.OAuth.Authorization {
        Mastodon.API.OAuth.Authorization(accessToken: authentication.appAccessToken)
    }
    public var userAuthorization: Mastodon.API.OAuth.Authorization {
        Mastodon.API.OAuth.Authorization(accessToken: authentication.userAccessToken)
    }
    public var inMemoryCache: MastodonAccountInMemoryCache {
        .sharedCache(for: authentication.userID) // TODO: make sure this is really unique
    }

    public init(authentication: MastodonAuthentication) {
        self.authentication = authentication
    }
    
    @MainActor
    public var cachedAccount: Mastodon.Entity.Account? {
        return authentication.cachedAccount()
    }
}

public class MastodonAccountInMemoryCache {
    @Published public var followingUserIds: [String] = []
    @Published public var blockedUserIds: [String] = []
    @Published public var followRequestedUserIDs: [String] = []
    
    static var sharedCaches = [String: MastodonAccountInMemoryCache]()
    
    public static func sharedCache(for key: String) -> MastodonAccountInMemoryCache {
        if let sharedCache = sharedCaches[key] {
            return sharedCache
        }
        
        let sharedCache = MastodonAccountInMemoryCache()
        sharedCaches[key] = sharedCache
        return sharedCache
    }
}
