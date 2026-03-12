import SwiftUI
import ESCChatmailDomain

@MainActor
public final class InboxViewModel: ObservableObject {
    @Published public private(set) var snapshot: MailStoreSnapshot
    @Published public var selectedConversationID: ConversationID?

    public init(
        snapshot: MailStoreSnapshot = MockInboxData.snapshot,
        selectedConversationID: ConversationID? = MockInboxData.snapshot.conversations.first?.id
    ) {
        self.snapshot = snapshot
        self.selectedConversationID = selectedConversationID
    }

    public var mailboxes: [Mailbox] {
        snapshot.mailboxes
    }

    public var conversations: [ConversationSummary] {
        snapshot.conversations
    }

    public var selectedConversation: Conversation? {
        guard let selectedConversationID else {
            return nil
        }

        return snapshot.conversationThreads[selectedConversationID]
    }

    public func selectConversation(_ conversationID: ConversationID?) {
        selectedConversationID = conversationID
    }
}

public struct InboxDemoScreen: View {
    @StateObject private var viewModel: InboxViewModel

    @MainActor
    public init(snapshot: MailStoreSnapshot = MockInboxData.snapshot) {
        _viewModel = StateObject(wrappedValue: InboxViewModel(snapshot: snapshot))
    }

    public var body: some View {
        InboxRootView(viewModel: viewModel)
    }
}

public struct InboxRootView: View {
    @ObservedObject private var viewModel: InboxViewModel

    public init(viewModel: InboxViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            ConversationListView(
                conversations: viewModel.conversations,
                selection: $viewModel.selectedConversationID
            )
        } detail: {
            if let conversation = viewModel.selectedConversation {
                ConversationDetailView(conversation: conversation)
            } else {
                ContentUnavailableView(
                    "Select a conversation",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Mock JMAP-backed conversation data is ready for UI iteration.")
                )
            }
        }
    }
}

public struct ConversationListView: View {
    let conversations: [ConversationSummary]
    @Binding var selection: ConversationID?

    public init(conversations: [ConversationSummary], selection: Binding<ConversationID?>) {
        self.conversations = conversations
        _selection = selection
    }

    public var body: some View {
        List(conversations, selection: $selection) { summary in
            ConversationRowView(summary: summary)
                .tag(summary.id)
        }
        .navigationTitle("Inbox")
    }
}

private struct ConversationRowView: View {
    let summary: ConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.participantLine)
                        .font(.headline)
                        .lineLimit(1)

                    Text(summary.subject)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(summary.lastMessageAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(summary.snippet)
                .font(.body)
                .lineLimit(2)

            HStack(spacing: 8) {
                if summary.isPinned {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if summary.isUnread {
                    Text("\(summary.unreadCount) unread")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

public struct ConversationDetailView: View {
    let conversation: Conversation

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.summary.subject)
                    .font(.title3.weight(.semibold))

                Text(conversation.summary.participantLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.messages) { message in
                        MessageBubbleView(message: message)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(conversation.summary.subject)
    }
}

private struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.direction == .outgoing {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.author.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(message.bodyPlaintext)
                    .font(.body)

                if let attachment = message.attachments.first {
                    Label(attachment.fileName, systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.sentAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: 360, alignment: .leading)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if message.direction == .incoming {
                Spacer(minLength: 48)
            }
        }
    }

    private var bubbleColor: Color {
        message.direction == .outgoing ? .blue.opacity(0.18) : .gray.opacity(0.12)
    }
}

struct InboxDemoScreen_Previews: PreviewProvider {
    static var previews: some View {
        InboxDemoScreen()
    }
}
