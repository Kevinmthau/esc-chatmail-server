import Foundation
import ESCChatmailDomain

public enum MailProviderID: String, Sendable {
    case jmap
}

public enum MailProviderCapability: String, Hashable, Sendable {
    case mailboxListing
    case conversationListing
    case conversationHydration
    case incrementalSync
    case sending
}

public enum MailProviderError: Error, Sendable, LocalizedError {
    case unsupportedAccountConfiguration
    case notImplemented(operation: String)
    case invalidResponse
    case transportFailure(description: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedAccountConfiguration:
            return "The account configuration does not match this provider."
        case let .notImplemented(operation):
            return "\(operation) is not implemented yet."
        case .invalidResponse:
            return "The provider returned an invalid response."
        case let .transportFailure(description):
            return description
        }
    }
}

public protocol MailProvider: Sendable {
    var id: MailProviderID { get }
    var capabilities: Set<MailProviderCapability> { get }

    func fetchMailboxes(for account: AccountConfiguration) async throws -> [Mailbox]
    func fetchConversationSummaries(
        in mailboxID: MailboxID,
        page: PageRequest,
        account: AccountConfiguration
    ) async throws -> ConversationPage
    func fetchConversation(
        id: ConversationID,
        account: AccountConfiguration
    ) async throws -> Conversation
    func syncMailbox(
        mailboxID: MailboxID,
        cursor: String?,
        account: AccountConfiguration
    ) async throws -> SyncDelta
}
