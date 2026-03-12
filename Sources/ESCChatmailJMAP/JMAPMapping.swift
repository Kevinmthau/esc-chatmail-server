import Foundation
import ESCChatmailDomain

enum JMAPMapper {
    static func mailbox(from mailbox: JMAPDTO.Mailbox) -> Mailbox {
        Mailbox(
            id: MailboxID(mailbox.id),
            name: mailbox.name,
            role: mailboxRole(for: mailbox.role),
            unreadCount: mailbox.unreadThreads ?? mailbox.unreadEmails ?? 0,
            totalCount: mailbox.totalThreads ?? mailbox.totalEmails ?? 0
        )
    }

    static func conversationPage(
        mailboxID: MailboxID,
        emailsByThreadID: [String: [JMAPDTO.Email]],
        queryState: String,
        nextPosition: Int?,
        fetchedAt: Date,
        account: AccountConfiguration
    ) -> ConversationPage {
        let summaries = emailsByThreadID
            .compactMap { summary(from: $0.value, mailboxID: mailboxID, account: account) }
            .sorted(by: { $0.lastMessageAt > $1.lastMessageAt })

        return ConversationPage(
            mailboxID: mailboxID,
            conversations: summaries,
            nextCursor: nextPosition.map(String.init),
            syncState: MailboxSyncState(
                mailboxID: mailboxID,
                cursor: queryState,
                lastSuccessfulSyncAt: fetchedAt,
                isInitialSyncComplete: true
            )
        )
    }

    static func conversation(
        from emails: [JMAPDTO.Email],
        fallbackMailboxID: MailboxID?,
        account: AccountConfiguration
    ) -> Conversation? {
        guard let summary = summary(from: emails, mailboxID: fallbackMailboxID, account: account) else {
            return nil
        }

        let messages = emails
            .map { message(from: $0, account: account) }
            .sorted(by: { $0.sentAt < $1.sentAt })

        return Conversation(summary: summary, messages: messages)
    }

    static func emailsByThreadID(
        query: JMAPDTO.QueryResponse,
        representativeEmails: [JMAPDTO.Email],
        threads: [JMAPDTO.Thread],
        hydratedEmails: [JMAPDTO.Email]
    ) -> [String: [JMAPDTO.Email]] {
        let representativeThreadIDs = representativeEmails.compactMap { email in
            query.ids.contains(email.id) ? email.threadID : nil
        }

        let hydratedByID = Dictionary(uniqueKeysWithValues: hydratedEmails.map { ($0.id, $0) })
        let threadsByID = Dictionary(uniqueKeysWithValues: threads.map { ($0.id, $0) })

        return representativeThreadIDs.reduce(into: [String: [JMAPDTO.Email]]()) { result, threadID in
            guard let thread = threadsByID[threadID] else {
                return
            }

            let emails = thread.emailIDs.compactMap { hydratedByID[$0] }
            if !emails.isEmpty {
                result[threadID] = emails
            }
        }
    }

    private static func summary(
        from emails: [JMAPDTO.Email],
        mailboxID: MailboxID?,
        account: AccountConfiguration
    ) -> ConversationSummary? {
        guard let latestEmail = latestEmail(in: emails) else {
            return nil
        }

        let conversationID = ConversationID(latestEmail.threadID)
        let participants = summaryParticipants(from: emails, account: account)
        let fallbackMailboxID = mailboxID ?? MailboxID(latestEmail.mailboxIDs?.keys.sorted().first ?? "unknown")

        return ConversationSummary(
            id: conversationID,
            mailboxID: fallbackMailboxID,
            subject: latestEmail.subject?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "(No subject)",
            participants: participants,
            snippet: latestEmail.preview?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? bodyText(from: latestEmail).nonEmpty ?? "",
            unreadCount: unreadCount(in: emails),
            lastMessageAt: messageDate(for: latestEmail),
            lastMessageSender: participant(from: latestEmail.from?.first),
            isPinned: false,
            isMuted: false
        )
    }

    private static func message(from email: JMAPDTO.Email, account: AccountConfiguration) -> Message {
        Message(
            id: MessageID(email.id),
            conversationID: ConversationID(email.threadID),
            author: participant(from: email.from?.first),
            direction: direction(for: email, account: account),
            sentAt: messageDate(for: email),
            bodyPlaintext: bodyText(from: email).nonEmpty ?? email.preview?.nonEmpty ?? "",
            attachments: [],
            deliveryState: direction(for: email, account: account) == .outgoing ? .sent : .delivered,
            isRead: isRead(email)
        )
    }

    private static func mailboxRole(for role: String?) -> MailboxRole {
        switch role?.lowercased() {
        case "inbox":
            return .inbox
        case "archive":
            return .archive
        case "sent":
            return .sent
        case "drafts":
            return .drafts
        case "trash":
            return .trash
        case "junk", "spam":
            return .spam
        default:
            return .custom
        }
    }

    private static func unreadCount(in emails: [JMAPDTO.Email]) -> Int {
        emails.reduce(into: 0) { count, email in
            if !isRead(email) {
                count += 1
            }
        }
    }

    private static func latestEmail(in emails: [JMAPDTO.Email]) -> JMAPDTO.Email? {
        emails.max(by: { messageDate(for: $0) < messageDate(for: $1) })
    }

    private static func messageDate(for email: JMAPDTO.Email) -> Date {
        email.receivedAt ?? email.sentAt ?? Date(timeIntervalSince1970: 0)
    }

    private static func summaryParticipants(
        from emails: [JMAPDTO.Email],
        account: AccountConfiguration
    ) -> [Participant] {
        let allParticipants = uniqueParticipants(
            emails.flatMap { email in
                (email.from ?? []).compactMap(participant(from:)) + (email.to ?? []).compactMap(participant(from:))
            }
        )

        let filtered = allParticipants.filter { participant in
            !matchesCurrentAccount(participant.emailAddress, account: account)
        }

        return filtered.isEmpty ? allParticipants : filtered
    }

    private static func uniqueParticipants(_ participants: [Participant]) -> [Participant] {
        var seen = Set<String>()
        var ordered: [Participant] = []

        for participant in participants {
            let normalized = participant.emailAddress.lowercased()
            guard !seen.contains(normalized) else {
                continue
            }

            seen.insert(normalized)
            ordered.append(participant)
        }

        return ordered
    }

    private static func participant(from address: JMAPDTO.Email.Address?) -> Participant {
        guard let address else {
            return Participant(displayName: "Unknown", emailAddress: "unknown@example.invalid")
        }

        return Participant(
            displayName: address.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? address.email,
            emailAddress: address.email
        )
    }

    private static func bodyText(from email: JMAPDTO.Email) -> String {
        guard
            let parts = email.textBody,
            let values = email.bodyValues
        else {
            return ""
        }

        let text = parts.compactMap { part -> String? in
            guard let partID = part.partID else {
                return nil
            }

            return values[partID]?.value
        }
        .joined(separator: "\n\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    private static func isRead(_ email: JMAPDTO.Email) -> Bool {
        email.keywords?["$seen"] ?? false
    }

    private static func direction(for email: JMAPDTO.Email, account: AccountConfiguration) -> MessageDirection {
        let senderAddresses = (email.from ?? []).map(\.email)
        return senderAddresses.contains(where: { matchesCurrentAccount($0, account: account) }) ? .outgoing : .incoming
    }

    private static func matchesCurrentAccount(_ emailAddress: String, account: AccountConfiguration) -> Bool {
        let normalizedEmail = emailAddress.lowercased()

        if normalizedEmail == account.emailAddress.lowercased() {
            return true
        }

        guard let configuration = account.jmapConfiguration else {
            return false
        }

        return normalizedEmail == configuration.username.lowercased()
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
