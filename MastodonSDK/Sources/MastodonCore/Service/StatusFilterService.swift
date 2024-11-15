//
//  StatusFilterService.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-7-14.
//

import Foundation
import Combine
import CoreData
import CoreDataStack
import MastodonSDK
import MastodonMeta

@MainActor
public final class StatusFilterService {
    public static let shared = { StatusFilterService() }()

    var disposeBag = Set<AnyCancellable>()

    // input
    public let filterUpdatePublisher = PassthroughSubject<Void, Never>()

    // output
    @Published public var activeFilters: [Mastodon.Entity.Filter] = []

    private init() {
        // fetch account filters every 300s
        // also trigger fetch when app resume from background
        let filterUpdateTimerPublisher = Timer.publish(every: 300.0, on: .main, in: .common)
            .autoconnect()
            .share()
            .eraseToAnyPublisher()

        filterUpdateTimerPublisher
            .map { _ in }
            .subscribe(filterUpdatePublisher)
            .store(in: &disposeBag)

        Publishers.CombineLatest(
            AuthenticationServiceProvider.shared.$mastodonAuthenticationBoxes,
            filterUpdatePublisher
        )
        .flatMap { mastodonAuthenticationBoxes, _ -> AnyPublisher<Result<Mastodon.Response.Content<[Mastodon.Entity.Filter]>, Error>, Never> in
            guard let box = mastodonAuthenticationBoxes.first else {
                return Just(Result { throw APIService.APIError.implicit(.authenticationMissing) }).eraseToAnyPublisher()
            }
            return APIService.shared.filters(mastodonAuthenticationBox: box)
                .map { response in
                    let now = Date()
                    let newResponse = response.map { filters in
                        return filters.filter { filter in
                            if let expiresAt = filter.expiresAt {
                                // filter out expired rules
                                return expiresAt > now
                            } else {
                                return true
                            }
                        }
                    }
                    return Result<Mastodon.Response.Content<[Mastodon.Entity.Filter]>, Error>.success(newResponse)
                }
                .catch { error in
                    Just(Result<Mastodon.Response.Content<[Mastodon.Entity.Filter]>, Error>.failure(error))
                }
                .eraseToAnyPublisher()
        }
        .sink { result in
            switch result {
            case .success(let response):
                self.activeFilters = response.value
            case .failure(_):
                break
            }
        }
        .store(in: &disposeBag)

        // make initial trigger once
        filterUpdatePublisher.send()
    }

}
