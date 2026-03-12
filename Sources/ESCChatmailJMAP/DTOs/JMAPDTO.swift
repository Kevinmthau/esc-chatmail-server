import Foundation

public enum JMAPDTO {
    public enum JSONValue: Codable, Hashable, Sendable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case object([String: JSONValue])
        case array([JSONValue])
        case null

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Int.self) {
                self = .number(Double(value))
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([String: JSONValue].self) {
                self = .object(value)
            } else if let value = try? container.decode([JSONValue].self) {
                self = .array(value)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case let .string(value):
                try container.encode(value)
            case let .number(value):
                try container.encode(value)
            case let .bool(value):
                try container.encode(value)
            case let .object(value):
                try container.encode(value)
            case let .array(value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }
    }

    public struct SessionCapabilities: Decodable, Sendable {
        public let core: JSONValue?
        public let mail: JSONValue?

        public init(core: JSONValue?, mail: JSONValue?) {
            self.core = core
            self.mail = mail
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            core = try container.decodeIfPresent(JSONValue.self, forKey: DynamicCodingKey("urn:ietf:params:jmap:core"))
            mail = try container.decodeIfPresent(JSONValue.self, forKey: DynamicCodingKey("urn:ietf:params:jmap:mail"))
        }
    }

    public struct Session: Decodable, Sendable {
        public let capabilities: SessionCapabilities
        public let apiURL: URL
        public let downloadURL: String
        public let uploadURL: URL
        public let eventSourceURL: URL?
        public let state: String
        public let accounts: [String: Account]
        public let primaryAccounts: [String: String]

        public init(
            capabilities: SessionCapabilities,
            apiURL: URL,
            downloadURL: String,
            uploadURL: URL,
            eventSourceURL: URL?,
            state: String,
            accounts: [String: Account],
            primaryAccounts: [String: String]
        ) {
            self.capabilities = capabilities
            self.apiURL = apiURL
            self.downloadURL = downloadURL
            self.uploadURL = uploadURL
            self.eventSourceURL = eventSourceURL
            self.state = state
            self.accounts = accounts
            self.primaryAccounts = primaryAccounts
        }

        enum CodingKeys: String, CodingKey {
            case capabilities
            case apiURL = "apiUrl"
            case downloadURL = "downloadUrl"
            case uploadURL = "uploadUrl"
            case eventSourceURL = "eventSourceUrl"
            case state
            case accounts
            case primaryAccounts
        }
    }

    public struct Account: Decodable, Sendable {
        public let name: String
        public let isPersonal: Bool
        public let isReadOnly: Bool
        public let accountCapabilities: [String: JSONValue]?

        public init(name: String, isPersonal: Bool, isReadOnly: Bool, accountCapabilities: [String: JSONValue]? = nil) {
            self.name = name
            self.isPersonal = isPersonal
            self.isReadOnly = isReadOnly
            self.accountCapabilities = accountCapabilities
        }
    }

    public struct Mailbox: Decodable, Sendable {
        public let id: String
        public let name: String
        public let role: String?
        public let totalThreads: Int?
        public let unreadThreads: Int?
        public let totalEmails: Int?
        public let unreadEmails: Int?

        public init(
            id: String,
            name: String,
            role: String?,
            totalThreads: Int?,
            unreadThreads: Int?,
            totalEmails: Int?,
            unreadEmails: Int?
        ) {
            self.id = id
            self.name = name
            self.role = role
            self.totalThreads = totalThreads
            self.unreadThreads = unreadThreads
            self.totalEmails = totalEmails
            self.unreadEmails = unreadEmails
        }
    }

    public struct Thread: Decodable, Sendable {
        public let id: String
        public let emailIDs: [String]

        public init(id: String, emailIDs: [String]) {
            self.id = id
            self.emailIDs = emailIDs
        }

        enum CodingKeys: String, CodingKey {
            case id
            case emailIDs = "emailIds"
        }
    }

    public struct Email: Decodable, Sendable {
        public struct Address: Decodable, Sendable {
            public let email: String
            public let name: String?

            public init(email: String, name: String?) {
                self.email = email
                self.name = name
            }
        }

        public struct BodyPart: Decodable, Sendable {
            public let partID: String?
            public let type: String?

            public init(partID: String?, type: String?) {
                self.partID = partID
                self.type = type
            }

            enum CodingKeys: String, CodingKey {
                case partID = "partId"
                case type
            }
        }

        public struct BodyValue: Decodable, Sendable {
            public let value: String
            public let isTruncated: Bool?
            public let isEncodingProblem: Bool?

            public init(value: String, isTruncated: Bool?, isEncodingProblem: Bool?) {
                self.value = value
                self.isTruncated = isTruncated
                self.isEncodingProblem = isEncodingProblem
            }
        }

        public let id: String
        public let threadID: String
        public let subject: String?
        public let preview: String?
        public let sentAt: Date?
        public let receivedAt: Date?
        public let from: [Address]?
        public let to: [Address]?
        public let keywords: [String: Bool]?
        public let mailboxIDs: [String: Bool]?
        public let textBody: [BodyPart]?
        public let bodyValues: [String: BodyValue]?

        public init(
            id: String,
            threadID: String,
            subject: String?,
            preview: String?,
            sentAt: Date?,
            receivedAt: Date?,
            from: [Address]?,
            to: [Address]?,
            keywords: [String: Bool]? = nil,
            mailboxIDs: [String: Bool]? = nil,
            textBody: [BodyPart]? = nil,
            bodyValues: [String: BodyValue]? = nil
        ) {
            self.id = id
            self.threadID = threadID
            self.subject = subject
            self.preview = preview
            self.sentAt = sentAt
            self.receivedAt = receivedAt
            self.from = from
            self.to = to
            self.keywords = keywords
            self.mailboxIDs = mailboxIDs
            self.textBody = textBody
            self.bodyValues = bodyValues
        }

        enum CodingKeys: String, CodingKey {
            case id
            case threadID = "threadId"
            case subject
            case preview
            case sentAt
            case receivedAt
            case from
            case to
            case keywords
            case mailboxIDs = "mailboxIds"
            case textBody
            case bodyValues
        }
    }

    public struct Request: Encodable, Sendable {
        public let usingCapabilities: [String]
        public let methodCalls: [MethodCall]

        public init(usingCapabilities: [String], methodCalls: [MethodCall]) {
            self.usingCapabilities = usingCapabilities
            self.methodCalls = methodCalls
        }

        enum CodingKeys: String, CodingKey {
            case usingCapabilities = "using"
            case methodCalls
        }
    }

    public struct MethodCall: Encodable, Sendable {
        public let name: String
        public let arguments: JSONValue
        public let callID: String

        public init(name: String, arguments: JSONValue, callID: String) {
            self.name = name
            self.arguments = arguments
            self.callID = callID
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(name)
            try container.encode(arguments)
            try container.encode(callID)
        }
    }

    public struct Response: Decodable, Sendable {
        public let methodResponses: [MethodResponse]
        public let sessionState: String?

        public init(methodResponses: [MethodResponse], sessionState: String?) {
            self.methodResponses = methodResponses
            self.sessionState = sessionState
        }
    }

    public struct MethodResponse: Decodable, Sendable {
        public let name: String
        public let arguments: JSONValue
        public let callID: String

        public init(name: String, arguments: JSONValue, callID: String) {
            self.name = name
            self.arguments = arguments
            self.callID = callID
        }

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            name = try container.decode(String.self)
            arguments = try container.decode(JSONValue.self)
            callID = try container.decode(String.self)
        }
    }

    public struct GetResponse<Object: Decodable & Sendable>: Decodable, Sendable {
        public let accountID: String
        public let state: String?
        public let list: [Object]
        public let notFound: [String]?

        public init(accountID: String, state: String?, list: [Object], notFound: [String]?) {
            self.accountID = accountID
            self.state = state
            self.list = list
            self.notFound = notFound
        }

        enum CodingKeys: String, CodingKey {
            case accountID = "accountId"
            case state
            case list
            case notFound
        }
    }

    public struct QueryResponse: Decodable, Sendable {
        public let accountID: String
        public let queryState: String
        public let canCalculateChanges: Bool?
        public let position: Int
        public let ids: [String]
        public let total: Int?

        public init(
            accountID: String,
            queryState: String,
            canCalculateChanges: Bool?,
            position: Int,
            ids: [String],
            total: Int?
        ) {
            self.accountID = accountID
            self.queryState = queryState
            self.canCalculateChanges = canCalculateChanges
            self.position = position
            self.ids = ids
            self.total = total
        }

        enum CodingKeys: String, CodingKey {
            case accountID = "accountId"
            case queryState
            case canCalculateChanges
            case position
            case ids
            case total
        }
    }

    struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init(_ stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(stringValue: String) {
            self.init(stringValue)
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}
