//
//  FilterApplication.swift
//  MastodonSDK
//
//  Created by Shannon Hughes on 11/22/24.
//

import MastodonSDK
import NaturalLanguage

public extension Mastodon.Entity {
    struct FilterApplication: Equatable {
        let hideAnyMatch: [FilterContext : [String]]
        let warnAnyMatch: [FilterContext : [String]]
        let hideWholeWordMatch: [FilterContext : [String]]
        let warnWholeWordMatch: [FilterContext : [String]]
        
        public init?(filters: [Mastodon.Entity.FilterInfo]) {
            guard !filters.isEmpty else { return nil }
            
            var _hideAnyMatch = [FilterContext : [String]]()
            var _warnAnyMatch = [FilterContext : [String]]()
            var _hideWholeWordMatch = [FilterContext : [String]]()
            var _warnWholeWordMatch = [FilterContext : [String]]()
            
            for filter in filters {
                for context in filter.filterContexts {
                    let partialWords = filter.matchAll
                    let wholeWords = filter.matchWholeWordOnly
                    switch filter.filterAction {
                    case .hide:
                        var words = _hideWholeWordMatch[context] ?? []
                        words.append(contentsOf: wholeWords)
                        _hideWholeWordMatch[context] = words
                        
                        words = _hideAnyMatch[context] ?? []
                        words.append(contentsOf: partialWords)
                        _hideAnyMatch[context] = words
                    case .warn, ._other:
                        var words = _warnWholeWordMatch[context] ?? []
                        words.append(contentsOf: wholeWords)
                        _warnWholeWordMatch[context] = words
                        
                        words = _warnAnyMatch[context] ?? []
                        words.append(contentsOf: partialWords)
                        _warnAnyMatch[context] = words
                    }
                }
            }

            warnAnyMatch = _warnAnyMatch
            warnWholeWordMatch = _warnWholeWordMatch
            hideAnyMatch = _hideAnyMatch
            hideWholeWordMatch = _hideWholeWordMatch
        }
        
        public func apply(to status: MastodonStatus, in context: FilterContext) -> Mastodon.Entity.FilterResult {
            let status = status.reblog ?? status
            let defaultFilterResult = Mastodon.Entity.FilterResult.notFiltered
            guard let content = status.entity.content?.lowercased() else { return defaultFilterResult }
            return apply(to: content, in: context)
        }
            
        public func apply(to content: String?, in context: FilterContext) -> Mastodon.Entity.FilterResult {
            
            let defaultFilterResult = Mastodon.Entity.FilterResult.notFiltered
            
            guard let content else { return defaultFilterResult }
            
            if let warnAny = warnAnyMatch[context] {
                for partialMatchable in warnAny {
                    if content.contains(partialMatchable) {
                        return .warn(partialMatchable)
                    }
                }
            }
            if let hideAny = hideAnyMatch[context] {
                for partialMatchable in hideAny {
                    if content.contains(partialMatchable) {
                        return .hide
                    }
                }
            }
            
            let warnWholeWord = warnWholeWordMatch[context]
            let hideWholeWord = hideWholeWordMatch[context]
            
            var filterResult = defaultFilterResult
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = content
            
            tokenizer.enumerateTokens(in: content.startIndex..<content.endIndex) { range, _ in
                let word = String(content[range])
                if hideWholeWord?.contains(word) ?? false {
                    filterResult = .hide
                    return false
                } else if warnWholeWord?.contains(word) ?? false {
                    filterResult = .warn(word)
                    return false
                } else {
                    return true
                }
            }
            
            return filterResult
        }
    }
}
