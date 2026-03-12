import Foundation
import ESCChatmailDomain

public enum MockInboxData {
    public static let account = AccountConfiguration(
        id: AccountID("preview.self-hosted"),
        displayName: "ESC Self-Hosted",
        emailAddress: "kevin@chatmail.example",
        provider: .jmap(
            SelfHostedJMAPConfiguration(
                serverBaseURL: URL(string: "https://mail.chatmail.example")!,
                sessionURL: URL(string: "https://mail.chatmail.example/.well-known/jmap")!,
                uploadURL: URL(string: "https://mail.chatmail.example/jmap/upload")!,
                downloadURL: URL(string: "https://mail.chatmail.example/jmap/download/{accountId}/{blobId}/{name}")!,
                username: "kevin",
                authentication: .password("demo-password")
            )
        )
    )

    public static let snapshot: MailStoreSnapshot = {
        let inbox = Mailbox(
            id: MailboxID("mailbox.inbox"),
            name: "Inbox",
            role: .inbox,
            unreadCount: 3,
            totalCount: 24
        )
        let sent = Mailbox(
            id: MailboxID("mailbox.sent"),
            name: "Sent",
            role: .sent,
            unreadCount: 0,
            totalCount: 87
        )
        let archive = Mailbox(
            id: MailboxID("mailbox.archive"),
            name: "Archive",
            role: .archive,
            unreadCount: 0,
            totalCount: 142
        )

        let me = Participant(displayName: "Kevin", emailAddress: "kevin@chatmail.example")
        let mina = Participant(displayName: "Mina", emailAddress: "mina@team.example")
        let alex = Participant(displayName: "Alex", emailAddress: "alex@ops.example")
        let opsBot = Participant(displayName: "Ops Bot", emailAddress: "ops-bot@chatmail.example")
        let riley = Participant(displayName: "Riley", emailAddress: "riley@infra.example")

        let conversationOneID = ConversationID("conversation.rollout")
        let conversationTwoID = ConversationID("conversation.backup")
        let conversationThreeID = ConversationID("conversation.identity")

        let conversationOneSummary = ConversationSummary(
            id: conversationOneID,
            mailboxID: inbox.id,
            subject: "Stalwart rollout checkpoint",
            participants: [mina, me],
            snippet: "I switched the staging node over to JMAP-only. Can you verify the inbox hydrate path?",
            unreadCount: 1,
            lastMessageAt: date("2026-03-12T14:28:00Z"),
            lastMessageSender: mina,
            isPinned: true
        )

        let conversationTwoSummary = ConversationSummary(
            id: conversationTwoID,
            mailboxID: inbox.id,
            subject: "Nightly backup finished",
            participants: [opsBot],
            snippet: "Nightly mailbox backup completed in 2m 14s. Attachment store delta: +84 MB.",
            unreadCount: 1,
            lastMessageAt: date("2026-03-12T13:55:00Z"),
            lastMessageSender: opsBot
        )

        let conversationThreeSummary = ConversationSummary(
            id: conversationThreeID,
            mailboxID: inbox.id,
            subject: "Identity mapping for self-hosted accounts",
            participants: [alex, riley, me],
            snippet: "Let’s keep the app model provider-agnostic and derive sender identities after session bootstrap.",
            unreadCount: 1,
            lastMessageAt: date("2026-03-12T12:40:00Z"),
            lastMessageSender: riley
        )

        let conversationOne = Conversation(
            summary: conversationOneSummary,
            messages: [
                Message(
                    id: MessageID("message.rollout.1"),
                    conversationID: conversationOneID,
                    author: me,
                    direction: .outgoing,
                    sentAt: date("2026-03-12T14:10:00Z"),
                    bodyPlaintext: "Staging is on the new self-hosted stack now. I’ve stubbed the provider boundary and mock data path.",
                    deliveryState: .delivered,
                    isRead: true
                ),
                Message(
                    id: MessageID("message.rollout.2"),
                    conversationID: conversationOneID,
                    author: mina,
                    direction: .incoming,
                    sentAt: date("2026-03-12T14:18:00Z"),
                    bodyPlaintext: "Perfect. I switched the staging node over to JMAP-only. Can you verify the inbox hydrate path?",
                    deliveryState: .delivered,
                    isRead: true
                ),
                Message(
                    id: MessageID("message.rollout.3"),
                    conversationID: conversationOneID,
                    author: me,
                    direction: .outgoing,
                    sentAt: date("2026-03-12T14:24:00Z"),
                    bodyPlaintext: "The UI is rendering from mock threads first. Real hydrate can land once the session bootstrap is wired.",
                    deliveryState: .sent,
                    isRead: true
                )
            ]
        )

        let conversationTwo = Conversation(
            summary: conversationTwoSummary,
            messages: [
                Message(
                    id: MessageID("message.backup.1"),
                    conversationID: conversationTwoID,
                    author: opsBot,
                    direction: .incoming,
                    sentAt: date("2026-03-12T13:55:00Z"),
                    bodyPlaintext: "Nightly mailbox backup completed in 2m 14s. Attachment store delta: +84 MB.",
                    attachments: [
                        MailAttachment(
                            id: AttachmentID("attachment.backup.report"),
                            fileName: "backup-report.json",
                            mimeType: "application/json",
                            byteCount: 4_284
                        )
                    ],
                    deliveryState: .delivered,
                    isRead: false
                )
            ]
        )

        let conversationThree = Conversation(
            summary: conversationThreeSummary,
            messages: [
                Message(
                    id: MessageID("message.identity.1"),
                    conversationID: conversationThreeID,
                    author: alex,
                    direction: .incoming,
                    sentAt: date("2026-03-12T12:18:00Z"),
                    bodyPlaintext: "We should avoid baking JMAP account IDs into the app’s core conversation models.",
                    deliveryState: .delivered,
                    isRead: true
                ),
                Message(
                    id: MessageID("message.identity.2"),
                    conversationID: conversationThreeID,
                    author: riley,
                    direction: .incoming,
                    sentAt: date("2026-03-12T12:31:00Z"),
                    bodyPlaintext: "Agreed. Keep the app model provider-agnostic and derive sender identities after session bootstrap.",
                    deliveryState: .delivered,
                    isRead: true
                ),
                Message(
                    id: MessageID("message.identity.3"),
                    conversationID: conversationThreeID,
                    author: me,
                    direction: .outgoing,
                    sentAt: date("2026-03-12T12:40:00Z"),
                    bodyPlaintext: "I’m locking that boundary into the scaffolding so the sync engine only sees domain types.",
                    deliveryState: .delivered,
                    isRead: false
                )
            ]
        )

        return MailStoreSnapshot(
            accountID: account.id,
            selectedMailboxID: inbox.id,
            mailboxes: [inbox, sent, archive],
            conversations: [
                conversationOneSummary,
                conversationTwoSummary,
                conversationThreeSummary
            ],
            conversationThreads: [
                conversationOneID: conversationOne,
                conversationTwoID: conversationTwo,
                conversationThreeID: conversationThree
            ],
            syncStates: [
                inbox.id: MailboxSyncState(
                    mailboxID: inbox.id,
                    cursor: "preview-cursor",
                    lastSuccessfulSyncAt: date("2026-03-12T14:28:00Z"),
                    isInitialSyncComplete: true
                )
            ]
        )
    }()

    private static func date(_ rawValue: String) -> Date {
        ISO8601DateFormatter().date(from: rawValue)!
    }
}
