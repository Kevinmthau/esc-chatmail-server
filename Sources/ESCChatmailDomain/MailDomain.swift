import Foundation

public struct AccountID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MailboxID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct ConversationID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MessageID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct AttachmentID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum MailboxRole: String, CaseIterable, Codable, Sendable {
    case inbox
    case archive
    case sent
    case drafts
    case trash
    case spam
    case custom
}

public enum MessageDirection: String, Codable, Sendable {
    case incoming
    case outgoing
}

public enum MessageDeliveryState: String, Codable, Sendable {
    case pending
    case sent
    case delivered
    case failed
}

public struct Participant: Hashable, Codable, Sendable {
    public var displayName: String
    public var emailAddress: String

    public init(displayName: String, emailAddress: String) {
        self.displayName = displayName
        self.emailAddress = emailAddress
    }
}

public struct MailAttachment: Hashable, Codable, Sendable, Identifiable {
    public let id: AttachmentID
    public var fileName: String
    public var mimeType: String
    public var byteCount: Int

    public init(id: AttachmentID, fileName: String, mimeType: String, byteCount: Int) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.byteCount = byteCount
    }
}

public struct Mailbox: Hashable, Codable, Sendable, Identifiable {
    public let id: MailboxID
    public var name: String
    public var role: MailboxRole
    public var unreadCount: Int
    public var totalCount: Int

    public init(id: MailboxID, name: String, role: MailboxRole, unreadCount: Int, totalCount: Int) {
        self.id = id
        self.name = name
        self.role = role
        self.unreadCount = unreadCount
        self.totalCount = totalCount
    }
}

public struct Message: Hashable, Codable, Sendable, Identifiable {
    public let id: MessageID
    public var conversationID: ConversationID
    public var author: Participant
    public var direction: MessageDirection
    public var sentAt: Date
    public var bodyPlaintext: String
    public var attachments: [MailAttachment]
    public var deliveryState: MessageDeliveryState
    public var isRead: Bool

    public init(
        id: MessageID,
        conversationID: ConversationID,
        author: Participant,
        direction: MessageDirection,
        sentAt: Date,
        bodyPlaintext: String,
        attachments: [MailAttachment] = [],
        deliveryState: MessageDeliveryState,
        isRead: Bool
    ) {
        self.id = id
        self.conversationID = conversationID
        self.author = author
        self.direction = direction
        self.sentAt = sentAt
        self.bodyPlaintext = bodyPlaintext
        self.attachments = attachments
        self.deliveryState = deliveryState
        self.isRead = isRead
    }
}

public struct ConversationSummary: Hashable, Codable, Sendable, Identifiable {
    public let id: ConversationID
    public var mailboxID: MailboxID
    public var subject: String
    public var participants: [Participant]
    public var snippet: String
    public var unreadCount: Int
    public var lastMessageAt: Date
    public var lastMessageSender: Participant?
    public var isPinned: Bool
    public var isMuted: Bool

    public init(
        id: ConversationID,
        mailboxID: MailboxID,
        subject: String,
        participants: [Participant],
        snippet: String,
        unreadCount: Int,
        lastMessageAt: Date,
        lastMessageSender: Participant?,
        isPinned: Bool = false,
        isMuted: Bool = false
    ) {
        self.id = id
        self.mailboxID = mailboxID
        self.subject = subject
        self.participants = participants
        self.snippet = snippet
        self.unreadCount = unreadCount
        self.lastMessageAt = lastMessageAt
        self.lastMessageSender = lastMessageSender
        self.isPinned = isPinned
        self.isMuted = isMuted
    }

    public var isUnread: Bool {
        unreadCount > 0
    }

    public var participantLine: String {
        participants.map(\.displayName).joined(separator: ", ")
    }
}

public struct Conversation: Hashable, Codable, Sendable, Identifiable {
    public let id: ConversationID
    public var summary: ConversationSummary
    public var messages: [Message]

    public init(summary: ConversationSummary, messages: [Message]) {
        self.id = summary.id
        self.summary = summary
        self.messages = messages.sorted(by: { $0.sentAt < $1.sentAt })
    }
}

public struct PageRequest: Hashable, Sendable {
    public var limit: Int
    public var cursor: String?

    public init(limit: Int = 40, cursor: String? = nil) {
        self.limit = limit
        self.cursor = cursor
    }
}

public struct MailboxSyncState: Hashable, Sendable {
    public var mailboxID: MailboxID
    public var cursor: String?
    public var lastSuccessfulSyncAt: Date?
    public var isInitialSyncComplete: Bool

    public init(
        mailboxID: MailboxID,
        cursor: String? = nil,
        lastSuccessfulSyncAt: Date? = nil,
        isInitialSyncComplete: Bool = false
    ) {
        self.mailboxID = mailboxID
        self.cursor = cursor
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.isInitialSyncComplete = isInitialSyncComplete
    }
}

public struct ConversationPage: Hashable, Sendable {
    public var mailboxID: MailboxID
    public var conversations: [ConversationSummary]
    public var nextCursor: String?
    public var syncState: MailboxSyncState

    public init(
        mailboxID: MailboxID,
        conversations: [ConversationSummary],
        nextCursor: String? = nil,
        syncState: MailboxSyncState
    ) {
        self.mailboxID = mailboxID
        self.conversations = conversations
        self.nextCursor = nextCursor
        self.syncState = syncState
    }
}

public struct SyncDelta: Hashable, Sendable {
    public var mailboxID: MailboxID
    public var updatedConversations: [ConversationSummary]
    public var removedConversationIDs: [ConversationID]
    public var syncState: MailboxSyncState

    public init(
        mailboxID: MailboxID,
        updatedConversations: [ConversationSummary],
        removedConversationIDs: [ConversationID] = [],
        syncState: MailboxSyncState
    ) {
        self.mailboxID = mailboxID
        self.updatedConversations = updatedConversations
        self.removedConversationIDs = removedConversationIDs
        self.syncState = syncState
    }
}

public struct MailStoreSnapshot: Hashable, Sendable {
    public var accountID: AccountID
    public var selectedMailboxID: MailboxID?
    public var mailboxes: [Mailbox]
    public var conversations: [ConversationSummary]
    public var conversationThreads: [ConversationID: Conversation]
    public var syncStates: [MailboxID: MailboxSyncState]

    public init(
        accountID: AccountID,
        selectedMailboxID: MailboxID? = nil,
        mailboxes: [Mailbox] = [],
        conversations: [ConversationSummary] = [],
        conversationThreads: [ConversationID: Conversation] = [:],
        syncStates: [MailboxID: MailboxSyncState] = [:]
    ) {
        self.accountID = accountID
        self.selectedMailboxID = selectedMailboxID
        self.mailboxes = mailboxes
        self.conversations = conversations
        self.conversationThreads = conversationThreads
        self.syncStates = syncStates
    }

    public mutating func upsert(conversation: Conversation) {
        conversationThreads[conversation.id] = conversation

        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation.summary
        } else {
            conversations.insert(conversation.summary, at: 0)
        }
    }
}

public extension PageRequest {
    static let initial = PageRequest()
}
