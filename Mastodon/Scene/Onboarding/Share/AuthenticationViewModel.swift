//
//  AuthenticationViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/2/1.
//

import UIKit
import CoreData
import CoreDataStack
import Combine
import MastodonSDK
import MastodonCore
import AuthenticationServices

@MainActor
final class AuthenticationViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    private let context: AppContext
    private let coordinator: SceneCoordinator
    let isAuthenticationExist: Bool
    let input = CurrentValueSubject<String, Never>("")
    
    // output
    let viewHierarchyShouldReset: Bool
    let domain = CurrentValueSubject<String?, Never>(nil)
    let isDomainValid = CurrentValueSubject<Bool, Never>(false)
    let isAuthenticating = CurrentValueSubject<Bool, Never>(false)
    let isRegistering = CurrentValueSubject<Bool, Never>(false)
    let isIdle = CurrentValueSubject<Bool, Never>(true)
    let authenticated = PassthroughSubject<MastodonAuthenticationBox, Never>()
    let error = CurrentValueSubject<Error?, Never>(nil)
        
    init(context: AppContext, coordinator: SceneCoordinator, isAuthenticationExist: Bool) {
        self.context = context
        self.coordinator = coordinator
        self.isAuthenticationExist = isAuthenticationExist
        self.viewHierarchyShouldReset = isAuthenticationExist
        
        input
            .map { input in
                AuthenticationViewModel.parseDomain(from: input)
            }
            .assign(to: \.value, on: domain)
            .store(in: &disposeBag)
        
        Publishers.CombineLatest(
            isAuthenticating.eraseToAnyPublisher(),
            isRegistering.eraseToAnyPublisher()
        )
        .map { !$0 && !$1 }
        .assign(to: \.value, on: self.isIdle)
        .store(in: &disposeBag)
        
        domain
            .map { $0 != nil }
            .assign(to: \.value, on: isDomainValid)
            .store(in: &disposeBag)
    }
    
}

extension AuthenticationViewModel {
    static func parseDomain(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        
        let urlString = trimmed.hasPrefix("https://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        let components = host.components(separatedBy: ".")
        guard !components.contains(where: { $0.isEmpty }) else { return nil }
        guard components.count >= 2 else { return nil }

        return host
    }
}

extension AuthenticationViewModel {
    enum AuthenticationError: Error, LocalizedError {
        case badCredentials
        case registrationClosed
        
        var errorDescription: String? {
            switch self {
            case .badCredentials:               return "Bad Credentials"
            case .registrationClosed:           return "Registration Closed"
            }
        }
        
        var failureReason: String? {
            switch self {
            case .badCredentials:               return "Credentials invalid."
            case .registrationClosed:           return "Server disallow registration."
            }
        }
        
        var helpAnchor: String? {
            switch self {
            case .badCredentials:               return "Please try again."
            case .registrationClosed:           return "Please try another domain."
            }
        }
    }
}

extension AuthenticationViewModel {
    
    struct AuthenticateInfo {
        let domain: String
        let clientID: String
        let clientSecret: String
        let authorizeURL: URL
        let redirectURI: String
        
        init?(
            domain: String,
            application: Mastodon.Entity.Application,
            redirectURI: String = APIService.oauthCallbackURL
        ) {
            self.domain = domain
            guard let clientID = application.clientID,
                let clientSecret = application.clientSecret else { return nil }
            self.clientID = clientID
            self.clientSecret = clientSecret
            self.authorizeURL = {
                let query = Mastodon.API.OAuth.AuthorizeQuery(clientID: clientID, redirectURI: redirectURI)
                let url = Mastodon.API.OAuth.authorizeURL(domain: domain, query: query)
                return url
            }()
            self.redirectURI = redirectURI
        }
    }
    
    func authenticate(info: AuthenticateInfo, pinCodePublisher: AsyncThrowingStream<String, Error>) {
        Task {
            do {
                for try await code in pinCodePublisher {
                    self.isAuthenticating.value = true
                    let token = try await APIService.shared
                        .userAccessToken(
                            domain: info.domain,
                            clientID: info.clientID,
                            clientSecret: info.clientSecret,
                            redirectURI: info.redirectURI,
                            code: code
                        )
                    let authBox = try await AuthenticationViewModel.verifyAndActivateAuthentication(
                        info: info,
                        userToken: token
                    )
                    self.authenticated.send(authBox)
                    self.authenticated.send(completion: .finished)
                }
            } catch let error {
                self.isAuthenticating.value = false
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.errorCode == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        authenticated.send(completion: .finished)
                        return
                    }
                } else {
                    self.error.value = error
                    authenticated.send(completion: .finished)
                }
            }
        }
    }
    
    static func verifyAndActivateAuthentication(
        info: AuthenticateInfo,
        userToken: Mastodon.Entity.Token
    ) -> AnyPublisher<(Mastodon.Entity.Account, MastodonAuthenticationBox), Error> {
        let authorization = Mastodon.API.OAuth.Authorization(accessToken: userToken.accessToken)
        return APIService.shared.verifyAndActivateUser(
            domain: info.domain,
            clientID: info.clientID,
            clientSecret: info.clientSecret,
            authorization: authorization
        )
    }
    
    static func verifyAndActivateAuthentication(
        info: AuthenticateInfo,
        userToken: Mastodon.Entity.Token
    ) async throws -> MastodonAuthenticationBox {
        let authorization = Mastodon.API.OAuth.Authorization(accessToken: userToken.accessToken)
        
        let (_, authBox) = try await APIService.shared.verifyAndActivateUser(
            domain: info.domain,
            clientID: info.clientID,
            clientSecret: info.clientSecret,
            authorization: authorization
        )
        return authBox
    }
}
