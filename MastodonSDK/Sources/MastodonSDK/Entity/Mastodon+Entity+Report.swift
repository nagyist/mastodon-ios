//
//  Mastodon+Entity+Report.swift
//  
//
//  Created by MainasuK Cirno on 2021/1/29.
//

import Foundation

extension Mastodon.Entity {
    /// Report
    ///
    /// - Since: ?
    /// - Version: 4.0
    /// # Last Update
    ///   2025/02/03
    /// # Reference
    ///  [Document](https://docs.joinmastodon.org/entities/report/)
    public struct Report: Codable, Sendable {
        public typealias ID = String
        
        public let id: ID                   //  undocumented
        public let actionTaken: Bool?       //  undocumented
        public let targetAccount: Account?   // The account that was reported.
        public let flaggedStatusIDs: [String]? // IDs of statuses that have been attached to this report for additional context.
        public let comment: String? // The reason for the report.
        
        enum CodingKeys: String, CodingKey {
            case id
            case actionTaken = "action_taken"
            case targetAccount = "target_account"
            case flaggedStatusIDs = "status_ids"
            case comment
        }
    }
}
