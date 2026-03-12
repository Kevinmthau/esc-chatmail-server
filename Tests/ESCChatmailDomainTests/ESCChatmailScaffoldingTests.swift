import Testing
@testable import ESCChatmailDomain
@testable import ESCChatmailUI

struct ESCChatmailScaffoldingTests {
    @Test
    func selfHostedPreviewAccountUsesJMAPConfiguration() {
        guard case let .jmap(configuration) = MockInboxData.account.provider else {
            Issue.record("Expected a self-hosted JMAP account configuration.")
            return
        }

        #expect(configuration.sessionURL.absoluteString == "https://mail.chatmail.example/.well-known/jmap")
        #expect(configuration.username == "kevin")
    }

    @Test
    func mockSnapshotProvidesRenderableInboxState() {
        let snapshot = MockInboxData.snapshot

        #expect(snapshot.selectedMailboxID == MailboxID("mailbox.inbox"))
        #expect(snapshot.mailboxes.contains(where: { $0.role == .inbox }))
        #expect(snapshot.conversations.count == 3)
        #expect(snapshot.conversationThreads.count == 3)
    }
}
