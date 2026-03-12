import Foundation

public struct AccountConfiguration: Hashable, Sendable {
    public var id: AccountID
    public var displayName: String
    public var emailAddress: String
    public var provider: ProviderConfiguration
    public var syncPolicy: SyncPolicy

    public init(
        id: AccountID,
        displayName: String,
        emailAddress: String,
        provider: ProviderConfiguration,
        syncPolicy: SyncPolicy = .default
    ) {
        self.id = id
        self.displayName = displayName
        self.emailAddress = emailAddress
        self.provider = provider
        self.syncPolicy = syncPolicy
    }
}

public enum ProviderConfiguration: Hashable, Sendable {
    case jmap(SelfHostedJMAPConfiguration)
}

public struct SelfHostedJMAPConfiguration: Hashable, Sendable {
    public var serverBaseURL: URL
    public var sessionURL: URL
    public var uploadURL: URL?
    public var downloadURL: URL?
    public var username: String
    public var authentication: Authentication
    public var acceptsInvalidCertificates: Bool

    public init(
        serverBaseURL: URL,
        sessionURL: URL,
        uploadURL: URL? = nil,
        downloadURL: URL? = nil,
        username: String,
        authentication: Authentication,
        acceptsInvalidCertificates: Bool = false
    ) {
        self.serverBaseURL = serverBaseURL
        self.sessionURL = sessionURL
        self.uploadURL = uploadURL
        self.downloadURL = downloadURL
        self.username = username
        self.authentication = authentication
        self.acceptsInvalidCertificates = acceptsInvalidCertificates
    }
}

public enum Authentication: Hashable, Sendable {
    case password(String)
    case bearerToken(String)
}

public struct SyncPolicy: Hashable, Sendable {
    public var pageSize: Int
    public var conversationPrefetchLimit: Int
    public var inboxRefreshInterval: TimeInterval

    public init(
        pageSize: Int = 40,
        conversationPrefetchLimit: Int = 12,
        inboxRefreshInterval: TimeInterval = 60
    ) {
        self.pageSize = pageSize
        self.conversationPrefetchLimit = conversationPrefetchLimit
        self.inboxRefreshInterval = inboxRefreshInterval
    }

    public static let `default` = SyncPolicy()
}

public extension AccountConfiguration {
    var jmapConfiguration: SelfHostedJMAPConfiguration? {
        guard case let .jmap(configuration) = provider else {
            return nil
        }

        return configuration
    }

    static func selfHostedJMAP(
        id: AccountID,
        displayName: String,
        emailAddress: String,
        serverBaseURL: URL,
        sessionURL: URL? = nil,
        uploadURL: URL? = nil,
        downloadURL: URL? = nil,
        username: String,
        authentication: Authentication,
        syncPolicy: SyncPolicy = .default
    ) -> AccountConfiguration {
        let resolvedSessionURL = sessionURL ?? serverBaseURL.appending(path: ".well-known/jmap")

        return AccountConfiguration(
            id: id,
            displayName: displayName,
            emailAddress: emailAddress,
            provider: .jmap(
                SelfHostedJMAPConfiguration(
                    serverBaseURL: serverBaseURL,
                    sessionURL: resolvedSessionURL,
                    uploadURL: uploadURL,
                    downloadURL: downloadURL,
                    username: username,
                    authentication: authentication
                )
            ),
            syncPolicy: syncPolicy
        )
    }
}
