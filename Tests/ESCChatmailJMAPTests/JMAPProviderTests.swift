import Foundation
import Testing
@testable import ESCChatmailDomain
@testable import ESCChatmailJMAP

struct JMAPProviderTests {
    @Test
    func fetchMailboxesBootstrapsSessionAndMapsThreadCounts() async throws {
        let transport = MockJMAPTransport(
            responses: [
                .json(
                    """
                    {
                      "capabilities": {
                        "urn:ietf:params:jmap:core": {},
                        "urn:ietf:params:jmap:mail": {}
                      },
                      "accounts": {
                        "A1": {
                          "name": "Kevin",
                          "isPersonal": true,
                          "isReadOnly": false
                        }
                      },
                      "primaryAccounts": {
                        "urn:ietf:params:jmap:mail": "A1"
                      },
                      "apiUrl": "https://mail.chatmail.example/jmap/api",
                      "downloadUrl": "https://mail.chatmail.example/jmap/download/{accountId}/{blobId}/{name}",
                      "uploadUrl": "https://mail.chatmail.example/jmap/upload/{accountId}",
                      "eventSourceUrl": "https://mail.chatmail.example/jmap/eventsource",
                      "state": "session-state"
                    }
                    """,
                    url: URL(string: "https://mail.chatmail.example/.well-known/jmap")!
                ),
                .json(
                    """
                    {
                      "methodResponses": [
                        [
                          "Mailbox/get",
                          {
                            "accountId": "A1",
                            "state": "mailbox-state",
                            "list": [
                              {
                                "id": "mbox-inbox",
                                "name": "Inbox",
                                "role": "inbox",
                                "totalThreads": 12,
                                "unreadThreads": 3,
                                "totalEmails": 50,
                                "unreadEmails": 7
                              },
                              {
                                "id": "mbox-archive",
                                "name": "Archive",
                                "role": "archive",
                                "totalThreads": 44,
                                "unreadThreads": 0
                              }
                            ]
                          },
                          "mailboxes"
                        ]
                      ],
                      "sessionState": "session-state"
                    }
                    """,
                    url: URL(string: "https://mail.chatmail.example/jmap/api")!
                )
            ]
        )
        let provider = JMAPProvider(transport: transport)

        let mailboxes = try await provider.fetchMailboxes(for: previewAccount)

        #expect(mailboxes.count == 2)
        #expect(mailboxes.first?.role == .inbox)
        #expect(mailboxes.first?.totalCount == 12)
        #expect(mailboxes.first?.unreadCount == 3)

        let requests = await transport.requestsSnapshot()
        #expect(requests.count == 2)
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Basic a2V2aW46ZGVtby1wYXNzd29yZA==")
        #expect(requests[1].httpMethod == "POST")
        let requestBody = try decodedObject(from: requests[1].httpBody)
        #expect(requestBody?["using"] != nil)
    }

    @Test
    func fetchConversationSummariesUsesCollapsedThreadQueryAndMapsUnreadCounts() async throws {
        let transport = MockJMAPTransport(
            responses: [
                .json(Self.sessionJSON, url: URL(string: "https://mail.chatmail.example/.well-known/jmap")!),
                .json(
                    """
                    {
                      "methodResponses": [
                        [
                          "Email/query",
                          {
                            "accountId": "A1",
                            "queryState": "query-state-1",
                            "canCalculateChanges": true,
                            "position": 0,
                            "ids": ["m1", "m4"],
                            "total": 3
                          },
                          "query"
                        ],
                        [
                          "Email/get",
                          {
                            "accountId": "A1",
                            "state": "email-state-1",
                            "list": [
                              { "id": "m1", "threadId": "thread-1" },
                              { "id": "m4", "threadId": "thread-2" }
                            ]
                          },
                          "thread-ids"
                        ],
                        [
                          "Thread/get",
                          {
                            "accountId": "A1",
                            "state": "thread-state-1",
                            "list": [
                              { "id": "thread-1", "emailIds": ["m1", "m2", "m3"] },
                              { "id": "thread-2", "emailIds": ["m4"] }
                            ]
                          },
                          "threads"
                        ],
                        [
                          "Email/get",
                          {
                            "accountId": "A1",
                            "state": "email-state-2",
                            "list": [
                              {
                                "id": "m1",
                                "threadId": "thread-1",
                                "subject": "Rollout checkpoint",
                                "preview": "Can you verify the JMAP hydrate path?",
                                "sentAt": "2026-03-12T14:20:00Z",
                                "receivedAt": "2026-03-12T14:20:00Z",
                                "from": [{ "email": "mina@example.com", "name": "Mina" }],
                                "to": [{ "email": "kevin@chatmail.example", "name": "Kevin" }],
                                "keywords": { "$seen": false },
                                "mailboxIds": { "mbox-inbox": true }
                              },
                              {
                                "id": "m2",
                                "threadId": "thread-1",
                                "subject": "Rollout checkpoint",
                                "preview": "Bootstrap is stubbed and ready for provider wiring.",
                                "sentAt": "2026-03-12T14:10:00Z",
                                "receivedAt": "2026-03-12T14:10:00Z",
                                "from": [{ "email": "kevin@chatmail.example", "name": "Kevin" }],
                                "to": [{ "email": "mina@example.com", "name": "Mina" }],
                                "keywords": { "$seen": true },
                                "mailboxIds": { "mbox-inbox": true }
                              },
                              {
                                "id": "m3",
                                "threadId": "thread-1",
                                "subject": "Rollout checkpoint",
                                "preview": "Starting the staging migration.",
                                "sentAt": "2026-03-12T14:00:00Z",
                                "receivedAt": "2026-03-12T14:00:00Z",
                                "from": [{ "email": "mina@example.com", "name": "Mina" }],
                                "to": [{ "email": "kevin@chatmail.example", "name": "Kevin" }],
                                "keywords": { "$seen": true },
                                "mailboxIds": { "mbox-inbox": true }
                              },
                              {
                                "id": "m4",
                                "threadId": "thread-2",
                                "subject": "Nightly backup",
                                "preview": "Backup completed successfully.",
                                "sentAt": "2026-03-12T13:40:00Z",
                                "receivedAt": "2026-03-12T13:40:00Z",
                                "from": [{ "email": "ops@example.com", "name": "Ops Bot" }],
                                "to": [{ "email": "kevin@chatmail.example", "name": "Kevin" }],
                                "keywords": { "$seen": true },
                                "mailboxIds": { "mbox-inbox": true }
                              }
                            ]
                          },
                          "emails"
                        ]
                      ],
                      "sessionState": "session-state"
                    }
                    """,
                    url: URL(string: "https://mail.chatmail.example/jmap/api")!
                )
            ]
        )
        let provider = JMAPProvider(transport: transport)

        let page = try await provider.fetchConversationSummaries(
            in: MailboxID("mbox-inbox"),
            page: PageRequest(limit: 2),
            account: previewAccount
        )

        #expect(page.conversations.count == 2)
        #expect(page.conversations.first?.id == ConversationID("thread-1"))
        #expect(page.conversations.first?.participants.map { $0.displayName } == ["Mina"])
        #expect(page.conversations.first?.unreadCount == 1)
        #expect(page.nextCursor == "2")
        #expect(page.syncState.cursor == "query-state-1")

        let requests = await transport.requestsSnapshot()
        let decodedBody = try decodedObject(from: requests[1].httpBody)
        let body = try #require(decodedBody)
        let methodCalls = try #require(body["methodCalls"] as? [Any])
        #expect(methodCalls.count == 4)
        #expect(jsonString(requests[1].httpBody).contains("\"collapseThreads\":true"))
        #expect(jsonString(requests[1].httpBody).contains("\"#ids\""))
    }

    @Test
    func fetchConversationHydratesMessagesAndExtractsPlaintextBody() async throws {
        let transport = MockJMAPTransport(
            responses: [
                .json(Self.sessionJSON, url: URL(string: "https://mail.chatmail.example/.well-known/jmap")!),
                .json(
                    """
                    {
                      "methodResponses": [
                        [
                          "Thread/get",
                          {
                            "accountId": "A1",
                            "state": "thread-state-2",
                            "list": [
                              { "id": "thread-42", "emailIds": ["m10", "m11"] }
                            ]
                          },
                          "thread"
                        ],
                        [
                          "Email/get",
                          {
                            "accountId": "A1",
                            "state": "email-state-3",
                            "list": [
                              {
                                "id": "m10",
                                "threadId": "thread-42",
                                "subject": "Identity mapping",
                                "preview": "Keep app models provider-agnostic.",
                                "sentAt": "2026-03-12T12:00:00Z",
                                "receivedAt": "2026-03-12T12:00:00Z",
                                "from": [{ "email": "alex@example.com", "name": "Alex" }],
                                "to": [{ "email": "kevin@chatmail.example", "name": "Kevin" }],
                                "keywords": { "$seen": true },
                                "mailboxIds": { "mbox-inbox": true },
                                "textBody": [{ "partId": "1", "type": "text/plain" }],
                                "bodyValues": {
                                  "1": { "value": "Keep app models provider-agnostic.", "isTruncated": false, "isEncodingProblem": false }
                                }
                              },
                              {
                                "id": "m11",
                                "threadId": "thread-42",
                                "subject": "Identity mapping",
                                "preview": "The sync engine only sees domain types.",
                                "sentAt": "2026-03-12T12:05:00Z",
                                "receivedAt": "2026-03-12T12:05:00Z",
                                "from": [{ "email": "kevin@chatmail.example", "name": "Kevin" }],
                                "to": [{ "email": "alex@example.com", "name": "Alex" }],
                                "keywords": { "$seen": false },
                                "mailboxIds": { "mbox-inbox": true },
                                "textBody": [{ "partId": "1", "type": "text/plain" }],
                                "bodyValues": {
                                  "1": { "value": "The sync engine only sees domain types.", "isTruncated": false, "isEncodingProblem": false }
                                }
                              }
                            ]
                          },
                          "emails"
                        ]
                      ],
                      "sessionState": "session-state"
                    }
                    """,
                    url: URL(string: "https://mail.chatmail.example/jmap/api")!
                )
            ]
        )
        let provider = JMAPProvider(transport: transport)

        let conversation = try await provider.fetchConversation(
            id: ConversationID("thread-42"),
            account: previewAccount
        )

        #expect(conversation.id == ConversationID("thread-42"))
        #expect(conversation.messages.count == 2)
        #expect(conversation.messages[0].direction == MessageDirection.incoming)
        #expect(conversation.messages[1].direction == MessageDirection.outgoing)
        #expect(conversation.messages[1].bodyPlaintext == "The sync engine only sees domain types.")
        #expect(conversation.summary.participants.map { $0.displayName } == ["Alex"])
        #expect(conversation.summary.unreadCount == 1)
    }

    private var previewAccount: AccountConfiguration {
        AccountConfiguration(
            id: AccountID("preview.self-hosted"),
            displayName: "ESC Self-Hosted",
            emailAddress: "kevin@chatmail.example",
            provider: .jmap(
                SelfHostedJMAPConfiguration(
                    serverBaseURL: URL(string: "https://mail.chatmail.example")!,
                    sessionURL: URL(string: "https://mail.chatmail.example/.well-known/jmap")!,
                    uploadURL: URL(string: "https://mail.chatmail.example/jmap/upload/{accountId}")!,
                    downloadURL: URL(string: "https://mail.chatmail.example/jmap/download/{accountId}/{blobId}/{name}")!,
                    username: "kevin",
                    authentication: .password("demo-password")
                )
            )
        )
    }

    private static let sessionJSON =
        """
        {
          "capabilities": {
            "urn:ietf:params:jmap:core": {},
            "urn:ietf:params:jmap:mail": {}
          },
          "accounts": {
            "A1": {
              "name": "Kevin",
              "isPersonal": true,
              "isReadOnly": false
            }
          },
          "primaryAccounts": {
            "urn:ietf:params:jmap:mail": "A1"
          },
          "apiUrl": "https://mail.chatmail.example/jmap/api",
          "downloadUrl": "https://mail.chatmail.example/jmap/download/{accountId}/{blobId}/{name}",
          "uploadUrl": "https://mail.chatmail.example/jmap/upload/{accountId}",
          "eventSourceUrl": "https://mail.chatmail.example/jmap/eventsource",
          "state": "session-state"
        }
        """
}

private actor MockJMAPTransport: JMAPTransport {
    struct StubResponse: Sendable {
        let data: Data
        let response: HTTPURLResponse

        static func json(_ body: String, url: URL, statusCode: Int = 200) -> StubResponse {
            StubResponse(
                data: Data(body.utf8),
                response: HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            )
        }
    }

    private var queuedResponses: [StubResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [StubResponse]) {
        self.queuedResponses = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = queuedResponses.removeFirst()
        return (response.data, response.response)
    }

    func requestsSnapshot() -> [URLRequest] {
        requests
    }
}

private func decodedObject(from data: Data?) throws -> [String: Any]? {
    guard let data else {
        return nil
    }

    return try JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func jsonString(_ data: Data?) -> String {
    guard let data else {
        return ""
    }

    return String(decoding: data, as: UTF8.self)
}
