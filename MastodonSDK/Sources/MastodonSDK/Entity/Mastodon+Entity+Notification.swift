//
//  Mastodon+Entity+Notification.swift
//  
//
//  Created by MainasuK Cirno on 2021/1/29.
//

import Foundation

extension Mastodon.Entity {
    /// Notification
    ///
    /// - Since: 0.9.9
    /// - Version: 3.3.0
    /// # Last Update
    ///   2021/1/29
    /// # Reference
    ///  [Document](https://docs.joinmastodon.org/entities/notification/)
    public struct Notification: Codable, Sendable {
        public typealias ID = String
        
        public let id: ID
        public let type: NotificationType
        public let createdAt: Date
        public let groupKey: String?
        public let account: Account
        public let status: Status?
        public let report: Report?
        public let relationshipSeveranceEvent: RelationshipSeveranceEvent?
        public let accountWarning: AccountWarning?

        enum CodingKeys: String, CodingKey {
            case id
            case type
            case groupKey = "group_key"
            case createdAt = "created_at"
            case account
            case status
            case report
            case accountWarning = "moderation_warning"
            case relationshipSeveranceEvent = "event"
        }
    }
    
    /// NotificationGroup
    ///
    /// - Since: 4.3.0
    /// - Version: 4.3.0
    /// # Last Update
    ///   2024/12/19
    /// # Reference
    ///  [Document](https://docs.joinmastodon.org/methods/grouped_notifications/#NotificationGroup)
    public struct NotificationGroup: Codable, Sendable {
        public typealias ID = String
        
        public let id: ID
        public let notificationsCount: Int
        public let type: NotificationType
        public let mostRecentNotificationID: ID
        public let pageOldestID: ID? // ID of the oldest notification from this group represented within the current page. This is only returned when paginating through notification groups. Useful when polling new notifications.
        public let pageNewestID: ID? // ID of the newest notification from this group represented within the current page. This is only returned when paginating through notification groups. Useful when polling new notifications.
        public let latestPageNotificationAt: Date? // Date at which the most recent notification from this group within the current page has been created. This is only returned when paginating through notification groups.
        public let sampleAccountIDs: [String] // IDs of some of the accounts who most recently triggered notifications in this group.
        public let statusID: ID?
        public let report: Report?
        public let relationshipSeveranceEvent: RelationshipSeveranceEvent?
        public let accountWarning: AccountWarning?
        
        enum CodingKeys: String, CodingKey {
            case id = "group_key"
            case notificationsCount = "notifications_count"
            case type
            case mostRecentNotificationID = "most_recent_notification_id"
            case pageOldestID = "page_min_id"
            case pageNewestID = "page_max_id"
            case latestPageNotificationAt = "latest_page_notification_at"
            case sampleAccountIDs = "sample_account_ids"
            case statusID = "status_id"
            case report = "report"
            case accountWarning = "moderation_warning"
            case relationshipSeveranceEvent = "event"
        }
    }
    
    public struct GroupedNotificationsResults: Codable, Sendable {
        public let accounts: [Mastodon.Entity.Account]
        public let partialAccounts: [Mastodon.Entity.PartialAccountWithAvatar]?
        public let statuses: [Mastodon.Entity.Status]
        public let notificationGroups: [Mastodon.Entity.NotificationGroup]
        
        enum CodingKeys: String, CodingKey {
            case accounts
            case partialAccounts = "partial_accounts"
            case statuses
            case notificationGroups = "notification_groups"
        }
    }
    
    public struct PartialAccountWithAvatar: Codable, Sendable
    {
        public typealias ID = String
        
        public let id: ID
        public let acct: String // The Webfinger account URI. Equal to username for local users, or username@domain for remote users.
        public let url: String // location of this account's profile page
        public let avatar: String // url
        public let avatarStatic: String // url, non-animated
        public let locked: Bool // account manually approves follow requests
        public let bot: Bool // is this a bot account
        
        enum CodingKeys: String, CodingKey {
            case id
            case acct
            case url
            case avatar
            case avatarStatic = "avatar_static"
            case locked
            case bot
        }
    }
    
    public enum RelationshipSeveranceEventType: RawRepresentable, Codable, Sendable {
        case domainBlock
        case userDomainBlock
        case accountSuspension
        case _other(String)
        
        public init?(rawValue: String) {
            switch rawValue {
            case "domain_block":         self = .domainBlock
            case "user_domain_block":    self = .userDomainBlock
            case "account_suspension":   self = .accountSuspension
            default:                     self = ._other(rawValue)
            }
        }
        public var rawValue: String {
            switch self {
            case .domainBlock:                       return "domain_block"
            case .userDomainBlock:
                return "user_domain_block"
            case .accountSuspension:
                return "account_suspension"
            case ._other(let rawValue):
                return rawValue
            }
        }
    }
    
    public struct RelationshipSeveranceEvent: Codable, Sendable {
        public typealias ID = String
        
        public let id: ID
        public let type: RelationshipSeveranceEventType
        public let purged: Bool // Whether the list of severed relationships is unavailable because the underlying issue has been purged.
        public let targetName: String // Name of the target of the moderation/block event. This is either a domain name or a user handle, depending on the event type.
        public let followersCount: Int // Number of followers that were removed as result of the event.
        public let followingCount: Int // Number of accounts the user stopped following as result of the event.
        public let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case type
            case purged
            case targetName = "target_name"
            case followersCount = "followers_count"
            case followingCount = "following_count"
            case createdAt = "created_at"
        }
    }
}

extension Mastodon.Entity {
    public struct AccountWarning: Codable, Sendable {
        public typealias ID = String

        public let id: ID
        public let action: Action
        public let text: String?
        public let targetAccount: Account
        public let appeal: Appeal?
        public let statusIds: [Mastodon.Entity.Status.ID]?

        public enum CodingKeys: String, CodingKey {
            case id
            case action
            case text
            case targetAccount = "target_account"
            case appeal
            case statusIds = "status_ids"
        }

        public enum Action: String, Codable, Sendable {
            case none
            case disable
            case markStatusesAsSensitive
            case deleteStatuses
            case sensitive
            case silence
            case suspend

            public enum CodingKeys: String, CodingKey {
                case none
                case disable
                case markStatusesAsSensitive = "mark_statuses_as_sensitive"
                case deleteStatuses = "delete_statuses"
                case sensitive
                case silence
                case suspend
            }
        }

        public struct Appeal: Codable, Sendable {
            public let text: String
            public let state: State

            public enum State: String, Codable, Sendable {
                case approved
                case rejected
                case pending
            }
        }
    }
}

extension Mastodon.Entity {
    public enum NotificationType: RawRepresentable, Codable, Sendable {
        case follow
        case followRequest
        case mention
        case reblog
        case favourite
        case poll
        case status
        case moderationWarning

        case _other(String)
        
        public init?(rawValue: String) {
            switch rawValue {
            case "follow":              self = .follow
            case "follow_request":      self = .followRequest
            case "mention":             self = .mention
            case "reblog":              self = .reblog
            case "favourite":           self = .favourite
            case "poll":                self = .poll
            case "status":              self = .status
            case "moderation_warning":  self = .moderationWarning
            default:                    self = ._other(rawValue)
            }
        }
        
        public var rawValue: String {
            switch self {
            case .follow:                       return "follow"
            case .followRequest:                return "follow_request"
            case .mention:                      return "mention"
            case .reblog:                       return "reblog"
            case .favourite:                    return "favourite"
            case .poll:                         return "poll"
            case .status:                       return "status"
            case .moderationWarning:            return "moderation_warning"
            case ._other(let value):            return value
            }
        }
    }
}

extension Mastodon.Entity.Notification: Hashable {
    public static func == (lhs: Mastodon.Entity.Notification, rhs: Mastodon.Entity.Notification) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Mastodon.Entity.NotificationGroup: Hashable {
    public static func == (lhs: Mastodon.Entity.NotificationGroup, rhs: Mastodon.Entity.NotificationGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
