// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import MastodonCore

extension FileManager {
    public func searchItems(forUser userID: String) throws -> [Persistence.SearchHistory.Item] {
        return try searchItems().filter { $0.userID == userID }
    }

    public func searchItems() throws -> [Persistence.SearchHistory.Item] {
        guard let documentsDirectory else { return [] }

        let searchHistoryPath = Persistence.searchHistory.filepath(baseURL: documentsDirectory)

        guard let data = try? Data(contentsOf: searchHistoryPath) else { return [] }

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601

        do {
            let searchItems = try jsonDecoder.decode([Persistence.SearchHistory.Item].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }

            return searchItems
        } catch {
            return []
        }
    }

    public func addSearchItem(_ newSearchItem: Persistence.SearchHistory.Item) throws {
        var searchItems = (try? searchItems()) ?? []

        if let index = searchItems.firstIndex(of: newSearchItem) {
            searchItems.remove(at: index)
        }
        
        searchItems.append(newSearchItem)

        storeJSON(searchItems, .searchHistory)
    }

    private func storeJSON(_ encodable: Encodable, _ persistence: Persistence) {
        guard let documentsDirectory else { return }

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        do {
            let data = try jsonEncoder.encode(encodable)

            let searchHistoryPath = persistence.filepath(baseURL: documentsDirectory)
            try data.write(to: searchHistoryPath)
        } catch {
            debugPrint(error.localizedDescription)
        }

    }

    public func removeSearchHistory(forUser userID: String) {
        let searchItems = (try? searchItems()) ?? []
        let newSearchItems = searchItems.filter { $0.userID != userID }

        storeJSON(newSearchItems, .searchHistory)
    }
}
