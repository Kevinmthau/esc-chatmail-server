import Foundation
import ESCChatmailDomain
import ESCChatmailProviders

public actor SyncEngine {
    private let provider: any MailProvider

    public init(provider: any MailProvider) {
        self.provider = provider
    }

    public func loadInitialSnapshot(for account: AccountConfiguration) async throws -> MailStoreSnapshot {
        let mailboxes = try await provider.fetchMailboxes(for: account)
        let selectedMailboxID = mailboxes.first(where: { $0.role == .inbox })?.id ?? mailboxes.first?.id

        guard let selectedMailboxID else {
            return MailStoreSnapshot(accountID: account.id)
        }

        let page = try await provider.fetchConversationSummaries(
            in: selectedMailboxID,
            page: PageRequest(limit: account.syncPolicy.pageSize),
            account: account
        )

        return MailStoreSnapshot(
            accountID: account.id,
            selectedMailboxID: selectedMailboxID,
            mailboxes: mailboxes,
            conversations: page.conversations,
            conversationThreads: [:],
            syncStates: [selectedMailboxID: page.syncState]
        )
    }

    public func refreshMailbox(
        _ mailboxID: MailboxID,
        in snapshot: MailStoreSnapshot,
        account: AccountConfiguration
    ) async throws -> MailStoreSnapshot {
        let cursor = snapshot.syncStates[mailboxID]?.cursor
        let delta = try await provider.syncMailbox(
            mailboxID: mailboxID,
            cursor: cursor,
            account: account
        )

        var updatedSnapshot = snapshot
        updatedSnapshot.syncStates[mailboxID] = delta.syncState
        updatedSnapshot.conversations.removeAll(where: { delta.removedConversationIDs.contains($0.id) })

        for summary in delta.updatedConversations {
            if let index = updatedSnapshot.conversations.firstIndex(where: { $0.id == summary.id }) {
                updatedSnapshot.conversations[index] = summary
            } else {
                updatedSnapshot.conversations.insert(summary, at: 0)
            }
        }

        return updatedSnapshot
    }

    public func loadConversation(
        _ conversationID: ConversationID,
        into snapshot: MailStoreSnapshot,
        account: AccountConfiguration
    ) async throws -> MailStoreSnapshot {
        let conversation = try await provider.fetchConversation(id: conversationID, account: account)
        var updatedSnapshot = snapshot
        updatedSnapshot.upsert(conversation: conversation)
        return updatedSnapshot
    }
}
