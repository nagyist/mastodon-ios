//
//  FilterApplication.swift
//  MastodonSDK
//
//  Created by Shannon Hughes on 11/22/24.
//

import MastodonSDK
import NaturalLanguage

public extension Mastodon.Entity.Filter {
    struct FilterApplication {
        let nonWordFilters: [Mastodon.Entity.Filter]
        let hideWords: [Context : [String]]
        let warnWords: [Context : [String]]
        
        public init?(filters: [Mastodon.Entity.Filter]) {
            guard !filters.isEmpty else { return nil }
            var wordFilters: [Mastodon.Entity.Filter] = []
            var nonWordFilters: [Mastodon.Entity.Filter] = []
            for filter in filters {
                if filter.wholeWord {
                    wordFilters.append(filter)
                } else {
                    nonWordFilters.append(filter)
                }
            }
            
            self.nonWordFilters = nonWordFilters
            
            var hidePhraseWords = [Context : [String]]()
            var warnPhraseWords = [Context : [String]]()
            for filter in wordFilters {
                if filter.filterAction ?? ._other("DEFAULT") == .hide {
                    for context in filter.context {
                        var words = hidePhraseWords[context] ?? [String]()
                        words.append(filter.phrase.lowercased())
                        hidePhraseWords[context] = words
                    }
                } else {
                    for context in filter.context {
                        var words = warnPhraseWords[context] ?? [String]()
                        words.append(filter.phrase.lowercased())
                        warnPhraseWords[context] = words
                    }
                }
            }
            
            self.hideWords = hidePhraseWords
            self.warnWords = warnPhraseWords
        }
        
        public func apply(to status: MastodonStatus, in context: Context) -> Mastodon.Entity.Filter.FilterStatus {
            
            let status = status.reblog ?? status
            let defaultFilterResult = Mastodon.Entity.Filter.FilterStatus.notFiltered
            guard let content = status.entity.content?.lowercased() else { return defaultFilterResult }
            
            for filter in nonWordFilters {
                guard filter.context.contains(context) else { continue }
                guard content.contains(filter.phrase.lowercased()) else { continue }
                switch filter.filterAction {
                case .hide:
                    return .hidden
                default:
                    return .filtered(filter.phrase)
                }
            }
            
            var filterResult = defaultFilterResult
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = content
            tokenizer.enumerateTokens(in: content.startIndex..<content.endIndex) { range, _ in
                let word = String(content[range])
                if let wordsToHide = hideWords[context], wordsToHide.contains(word) {
                    filterResult = .hidden
                    return false
                } else if let wordsToWarn = warnWords[context], wordsToWarn.contains(word) {
                    filterResult = .filtered(word)
                    return false
                } else {
                    return true
                }
            }
            
            return filterResult
        }
    }
}
