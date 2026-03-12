import Foundation
import ESCChatmailDomain
import ESCChatmailJMAP

@main
struct ESCChatmailStalwartSmokeTool {
    static func main() async {
        do {
            let configuration = try SmokeConfiguration.fromEnvironment()
            let account = configuration.accountConfiguration
            let provider = JMAPProvider()

            print("ESC Chatmail Stalwart smoke")
            print("Server: \(configuration.serverBaseURL.absoluteString)")
            print("Session URL: \(configuration.sessionURL.absoluteString)")
            print("Account: \(account.emailAddress)")

            let mailboxes = try await provider.fetchMailboxes(for: account)
            print("")
            print("Mailboxes: \(mailboxes.count)")

            for mailbox in mailboxes {
                print("- \(mailbox.name) [\(mailbox.id.rawValue)] unread=\(mailbox.unreadCount) total=\(mailbox.totalCount)")
            }

            guard let inbox = configuration.selectedInbox(from: mailboxes) else {
                throw SmokeError.inboxNotFound
            }

            let page = try await provider.fetchConversationSummaries(
                in: inbox.id,
                page: PageRequest(limit: configuration.pageSize),
                account: account
            )

            print("")
            print("Inbox mailbox: \(inbox.name) [\(inbox.id.rawValue)]")
            print("Conversation summaries: \(page.conversations.count)")
            print("Query cursor: \(page.syncState.cursor ?? "nil")")
            print("Next page cursor: \(page.nextCursor ?? "nil")")

            for summary in page.conversations.prefix(configuration.previewLimit) {
                let participants = summary.participants.map(\.displayName).joined(separator: ", ")
                print("")
                print("- \(summary.subject)")
                print("  thread=\(summary.id.rawValue)")
                print("  participants=\(participants)")
                print("  unread=\(summary.unreadCount)")
                print("  snippet=\(summary.snippet)")
            }

            if let firstConversationID = page.conversations.first?.id {
                let conversation = try await provider.fetchConversation(id: firstConversationID, account: account)
                print("")
                print("Hydrated conversation: \(conversation.id.rawValue)")
                print("Messages: \(conversation.messages.count)")

                if let lastMessage = conversation.messages.last {
                    print("Last message author: \(lastMessage.author.displayName)")
                    print("Last message direction: \(lastMessage.direction.rawValue)")
                    print("Last message body:")
                    print(lastMessage.bodyPlaintext)
                }
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            fputs("\nRequired environment:\n", stderr)
            fputs("  ESC_JMAP_BASE_URL=https://mail.example.com\n", stderr)
            fputs("  ESC_JMAP_EMAIL=user@example.com\n", stderr)
            fputs("  ESC_JMAP_USERNAME=user\n", stderr)
            fputs("  ESC_JMAP_PASSWORD=secret  (or ESC_JMAP_BEARER_TOKEN)\n", stderr)
            fputs("\nOptional environment:\n", stderr)
            fputs("  ESC_JMAP_SESSION_URL=https://mail.example.com/.well-known/jmap\n", stderr)
            fputs("  ESC_JMAP_INBOX_MAILBOX_ID=mailbox-id\n", stderr)
            fputs("  ESC_JMAP_PAGE_SIZE=10\n", stderr)
            fputs("  ESC_JMAP_PREVIEW_LIMIT=5\n", stderr)
            exit(1)
        }
    }
}

private struct SmokeConfiguration {
    let serverBaseURL: URL
    let sessionURL: URL
    let emailAddress: String
    let username: String
    let authentication: Authentication
    let pageSize: Int
    let previewLimit: Int
    let inboxMailboxID: MailboxID?

    var accountConfiguration: AccountConfiguration {
        AccountConfiguration.selfHostedJMAP(
            id: AccountID(emailAddress.lowercased()),
            displayName: username,
            emailAddress: emailAddress,
            serverBaseURL: serverBaseURL,
            sessionURL: sessionURL,
            username: username,
            authentication: authentication,
            syncPolicy: SyncPolicy(pageSize: pageSize)
        )
    }

    static func fromEnvironment(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> SmokeConfiguration {
        let baseURL = try requiredURL("ESC_JMAP_BASE_URL", environment: environment)
        let sessionURL = try optionalURL("ESC_JMAP_SESSION_URL", environment: environment) ?? baseURL.appending(path: ".well-known/jmap")
        let emailAddress = try requiredValue("ESC_JMAP_EMAIL", environment: environment)
        let username = try requiredValue("ESC_JMAP_USERNAME", environment: environment)
        let pageSize = Int(environment["ESC_JMAP_PAGE_SIZE"] ?? "") ?? 10
        let previewLimit = Int(environment["ESC_JMAP_PREVIEW_LIMIT"] ?? "") ?? 5
        let inboxMailboxID = environment["ESC_JMAP_INBOX_MAILBOX_ID"].flatMap { rawValue in
            rawValue.isEmpty ? nil : MailboxID(rawValue)
        }

        let authentication: Authentication
        if let token = environment["ESC_JMAP_BEARER_TOKEN"], !token.isEmpty {
            authentication = .bearerToken(token)
        } else {
            let password = try requiredValue("ESC_JMAP_PASSWORD", environment: environment)
            authentication = .password(password)
        }

        return SmokeConfiguration(
            serverBaseURL: baseURL,
            sessionURL: sessionURL,
            emailAddress: emailAddress,
            username: username,
            authentication: authentication,
            pageSize: pageSize,
            previewLimit: previewLimit,
            inboxMailboxID: inboxMailboxID
        )
    }

    func selectedInbox(from mailboxes: [Mailbox]) -> Mailbox? {
        if let inboxMailboxID {
            return mailboxes.first(where: { $0.id == inboxMailboxID })
        }

        return mailboxes.first(where: { $0.role == .inbox }) ?? mailboxes.first
    }

    private static func requiredValue(_ key: String, environment: [String: String]) throws -> String {
        guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw SmokeError.missingEnvironment(key)
        }

        return value
    }

    private static func requiredURL(_ key: String, environment: [String: String]) throws -> URL {
        let value = try requiredValue(key, environment: environment)
        guard let url = URL(string: value) else {
            throw SmokeError.invalidURL(key)
        }

        return url
    }

    private static func optionalURL(_ key: String, environment: [String: String]) throws -> URL? {
        guard let rawValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        guard let url = URL(string: rawValue) else {
            throw SmokeError.invalidURL(key)
        }

        return url
    }
}

private enum SmokeError: LocalizedError {
    case missingEnvironment(String)
    case invalidURL(String)
    case inboxNotFound

    var errorDescription: String? {
        switch self {
        case let .missingEnvironment(key):
            return "Missing environment variable: \(key)"
        case let .invalidURL(key):
            return "Invalid URL in environment variable: \(key)"
        case .inboxNotFound:
            return "Could not identify an inbox mailbox from the provider response."
        }
    }
}
