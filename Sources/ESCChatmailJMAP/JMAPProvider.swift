import Foundation
import ESCChatmailDomain
import ESCChatmailProviders

public actor JMAPProvider: MailProvider {
    public nonisolated let id: MailProviderID = .jmap
    public nonisolated let capabilities: Set<MailProviderCapability> = [
        .mailboxListing,
        .conversationListing,
        .conversationHydration
    ]

    private let transport: any JMAPTransport

    public init(urlSession: URLSession = .shared) {
        self.transport = URLSessionJMAPTransport(urlSession: urlSession)
    }

    public init(transport: any JMAPTransport) {
        self.transport = transport
    }

    public func fetchMailboxes(for account: AccountConfiguration) async throws -> [Mailbox] {
        let session = try await bootstrapSession(for: account)
        let response: JMAPDTO.GetResponse<JMAPDTO.Mailbox> = try await execute(
            JMAPDTO.MethodCall(
                name: "Mailbox/get",
                arguments: .object([
                    "accountId": .string(session.mailAccountID),
                    "properties": .array([
                        .string("id"),
                        .string("name"),
                        .string("role"),
                        .string("totalThreads"),
                        .string("unreadThreads"),
                        .string("totalEmails"),
                        .string("unreadEmails")
                    ])
                ]),
                callID: "mailboxes"
            ),
            expecting: "Mailbox/get",
            session: session
        )

        return response.list.map(JMAPMapper.mailbox(from:))
    }

    public func fetchConversationSummaries(
        in mailboxID: MailboxID,
        page: PageRequest,
        account: AccountConfiguration
    ) async throws -> ConversationPage {
        let session = try await bootstrapSession(for: account)
        let position = Int(page.cursor ?? "") ?? 0
        let fetchedAt = Date()

        let response = try await execute(
            [
                JMAPDTO.MethodCall(
                    name: "Email/query",
                    arguments: .object([
                        "accountId": .string(session.mailAccountID),
                        "filter": .object([
                            "inMailbox": .string(mailboxID.rawValue)
                        ]),
                        "sort": .array([
                            .object([
                                "property": .string("receivedAt"),
                                "isAscending": .bool(false)
                            ])
                        ]),
                        "collapseThreads": .bool(true),
                        "position": .number(Double(position)),
                        "limit": .number(Double(page.limit)),
                        "calculateTotal": .bool(true)
                    ]),
                    callID: "query"
                ),
                JMAPDTO.MethodCall(
                    name: "Email/get",
                    arguments: .object([
                        "accountId": .string(session.mailAccountID),
                        "#ids": .object([
                            "resultOf": .string("query"),
                            "name": .string("Email/query"),
                            "path": .string("/ids")
                        ]),
                        "properties": .array([
                            .string("id"),
                            .string("threadId")
                        ])
                    ]),
                    callID: "thread-ids"
                ),
                JMAPDTO.MethodCall(
                    name: "Thread/get",
                    arguments: .object([
                        "accountId": .string(session.mailAccountID),
                        "#ids": .object([
                            "resultOf": .string("thread-ids"),
                            "name": .string("Email/get"),
                            "path": .string("/list/*/threadId")
                        ])
                    ]),
                    callID: "threads"
                ),
                JMAPDTO.MethodCall(
                    name: "Email/get",
                    arguments: .object([
                        "accountId": .string(session.mailAccountID),
                        "#ids": .object([
                            "resultOf": .string("threads"),
                            "name": .string("Thread/get"),
                            "path": .string("/list/*/emailIds")
                        ]),
                        "properties": .array(fullEmailProperties)
                    ]),
                    callID: "emails"
                )
            ],
            session: session
        )

        let query: JMAPDTO.QueryResponse = try decodeMethod(named: "Email/query", callID: "query", from: response)
        let representativeEmails: JMAPDTO.GetResponse<JMAPDTO.Email> = try decodeMethod(named: "Email/get", callID: "thread-ids", from: response)
        let threads: JMAPDTO.GetResponse<JMAPDTO.Thread> = try decodeMethod(named: "Thread/get", callID: "threads", from: response)
        let hydratedEmails: JMAPDTO.GetResponse<JMAPDTO.Email> = try decodeMethod(named: "Email/get", callID: "emails", from: response)

        let emailsByThreadID = JMAPMapper.emailsByThreadID(
            query: query,
            representativeEmails: representativeEmails.list,
            threads: threads.list,
            hydratedEmails: hydratedEmails.list
        )
        let nextPosition = nextPosition(currentPosition: query.position, count: query.ids.count, total: query.total)

        return JMAPMapper.conversationPage(
            mailboxID: mailboxID,
            emailsByThreadID: emailsByThreadID,
            queryState: query.queryState,
            nextPosition: nextPosition,
            fetchedAt: fetchedAt,
            account: account
        )
    }

    public func fetchConversation(
        id: ConversationID,
        account: AccountConfiguration
    ) async throws -> Conversation {
        let session = try await bootstrapSession(for: account)
        let response = try await execute(
            [
                JMAPDTO.MethodCall(
                    name: "Thread/get",
                    arguments: .object([
                        "accountId": .string(session.mailAccountID),
                        "ids": .array([.string(id.rawValue)])
                    ]),
                    callID: "thread"
                ),
                JMAPDTO.MethodCall(
                    name: "Email/get",
                    arguments: .object([
                        "accountId": .string(session.mailAccountID),
                        "#ids": .object([
                            "resultOf": .string("thread"),
                            "name": .string("Thread/get"),
                            "path": .string("/list/*/emailIds")
                        ]),
                        "properties": .array(fullEmailProperties)
                    ]),
                    callID: "emails"
                )
            ],
            session: session
        )

        let threads: JMAPDTO.GetResponse<JMAPDTO.Thread> = try decodeMethod(named: "Thread/get", callID: "thread", from: response)
        let emails: JMAPDTO.GetResponse<JMAPDTO.Email> = try decodeMethod(named: "Email/get", callID: "emails", from: response)

        guard
            let thread = threads.list.first(where: { $0.id == id.rawValue }),
            let conversation = JMAPMapper.conversation(
                from: thread.emailIDs.compactMap { emailID in emails.list.first(where: { $0.id == emailID }) },
                fallbackMailboxID: nil,
                account: account
            )
        else {
            throw MailProviderError.invalidResponse
        }

        return conversation
    }

    public func syncMailbox(
        mailboxID: MailboxID,
        cursor: String?,
        account: AccountConfiguration
    ) async throws -> SyncDelta {
        _ = cursor
        let page = try await fetchConversationSummaries(
            in: mailboxID,
            page: PageRequest(limit: account.syncPolicy.pageSize),
            account: account
        )

        return SyncDelta(
            mailboxID: mailboxID,
            updatedConversations: page.conversations,
            removedConversationIDs: [],
            syncState: page.syncState
        )
    }

    private func configuration(for account: AccountConfiguration) throws -> SelfHostedJMAPConfiguration {
        guard let configuration = account.jmapConfiguration else {
            throw MailProviderError.unsupportedAccountConfiguration
        }

        return configuration
    }

    private func bootstrapSession(for account: AccountConfiguration) async throws -> BootstrappedSession {
        let configuration = try configuration(for: account)
        var request = URLRequest(url: configuration.sessionURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request, configuration: configuration)

        let (data, response) = try await transport.send(request)
        try validate(response: response, data: data)

        let session = try decoder.decode(JMAPDTO.Session.self, from: data)
        guard session.capabilities.mail != nil else {
            throw MailProviderError.invalidResponse
        }

        guard let mailAccountID = session.primaryAccounts[JMAP.mailCapability] ?? session.accounts.keys.sorted().first else {
            throw MailProviderError.invalidResponse
        }

        return BootstrappedSession(configuration: configuration, session: session, mailAccountID: mailAccountID)
    }

    private func execute<T: Decodable>(
        _ methodCall: JMAPDTO.MethodCall,
        expecting methodName: String,
        session: BootstrappedSession
    ) async throws -> T {
        let response = try await execute([methodCall], session: session)
        return try decodeMethod(named: methodName, callID: methodCall.callID, from: response)
    }

    private func execute(
        _ methodCalls: [JMAPDTO.MethodCall],
        session: BootstrappedSession
    ) async throws -> JMAPDTO.Response {
        var request = URLRequest(url: session.session.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request, configuration: session.configuration)
        request.httpBody = try encoder.encode(
            JMAPDTO.Request(
                usingCapabilities: [JMAP.coreCapability, JMAP.mailCapability],
                methodCalls: methodCalls
            )
        )
        debugLog(request: request)

        let (data, response) = try await transport.send(request)
        debugLog(response: response, data: data)
        try validate(response: response, data: data)
        return try decoder.decode(JMAPDTO.Response.self, from: data)
    }

    private func decodeMethod<T: Decodable>(
        named methodName: String,
        callID: String,
        from response: JMAPDTO.Response
    ) throws -> T {
        if let errorResponse = response.methodResponses.first(where: { $0.name == "error" && $0.callID == callID }) {
            throw MailProviderError.transportFailure(description: "JMAP error response: \(errorResponse.arguments)")
        }

        guard let methodResponse = response.methodResponses.first(where: { $0.name == methodName && $0.callID == callID }) else {
            throw MailProviderError.invalidResponse
        }

        let data = try encoder.encode(methodResponse.arguments)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let description = String(data: data, encoding: .utf8) ?? "HTTP \(response.statusCode)"
            throw MailProviderError.transportFailure(description: description)
        }
    }

    private func applyAuthentication(
        to request: inout URLRequest,
        configuration: SelfHostedJMAPConfiguration
    ) {
        switch configuration.authentication {
        case let .password(password):
            let credential = "\(configuration.username):\(password)"
            let encoded = Data(credential.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        case let .bearerToken(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func nextPosition(currentPosition: Int, count: Int, total: Int?) -> Int? {
        let next = currentPosition + count
        guard let total else {
            return count == 0 ? nil : next
        }

        return next < total ? next : nil
    }

    private var fullEmailProperties: [JMAPDTO.JSONValue] {
        [
            .string("id"),
            .string("threadId"),
            .string("subject"),
            .string("preview"),
            .string("sentAt"),
            .string("receivedAt"),
            .string("from"),
            .string("to"),
            .string("keywords"),
            .string("mailboxIds"),
            .string("textBody"),
            .string("bodyValues")
        ]
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }

    private func debugLog(request: URLRequest) {
        guard isDebugHTTPEnabled else {
            return
        }

        print("JMAP request: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "nil")")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print(bodyString)
        }
    }

    private func debugLog(response: HTTPURLResponse, data: Data) {
        guard isDebugHTTPEnabled else {
            return
        }

        print("JMAP response: HTTP \(response.statusCode) \(response.url?.absoluteString ?? "nil")")
        if let bodyString = String(data: data, encoding: .utf8) {
            print(bodyString)
        }
    }

    private var isDebugHTTPEnabled: Bool {
        ProcessInfo.processInfo.environment["ESC_JMAP_DEBUG_HTTP"] == "1"
    }
}

private enum JMAP {
    static let coreCapability = "urn:ietf:params:jmap:core"
    static let mailCapability = "urn:ietf:params:jmap:mail"
}

private struct BootstrappedSession: Sendable {
    let configuration: SelfHostedJMAPConfiguration
    let session: JMAPDTO.Session
    let mailAccountID: String
}
