// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ESCChatmail",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ESCChatmailDomain", targets: ["ESCChatmailDomain"]),
        .library(name: "ESCChatmailProviders", targets: ["ESCChatmailProviders"]),
        .library(name: "ESCChatmailJMAP", targets: ["ESCChatmailJMAP"]),
        .library(name: "ESCChatmailSync", targets: ["ESCChatmailSync"]),
        .library(name: "ESCChatmailUI", targets: ["ESCChatmailUI"]),
        .executable(name: "ESCChatmailStalwartSmoke", targets: ["ESCChatmailStalwartSmoke"])
    ],
    targets: [
        .target(name: "ESCChatmailDomain"),
        .target(
            name: "ESCChatmailProviders",
            dependencies: ["ESCChatmailDomain"]
        ),
        .target(
            name: "ESCChatmailJMAP",
            dependencies: ["ESCChatmailDomain", "ESCChatmailProviders"]
        ),
        .target(
            name: "ESCChatmailSync",
            dependencies: ["ESCChatmailDomain", "ESCChatmailProviders"]
        ),
        .target(
            name: "ESCChatmailUI",
            dependencies: ["ESCChatmailDomain"]
        ),
        .executableTarget(
            name: "ESCChatmailStalwartSmoke",
            dependencies: ["ESCChatmailDomain", "ESCChatmailJMAP", "ESCChatmailProviders"]
        ),
        .testTarget(
            name: "ESCChatmailDomainTests",
            dependencies: ["ESCChatmailDomain", "ESCChatmailUI"]
        ),
        .testTarget(
            name: "ESCChatmailJMAPTests",
            dependencies: ["ESCChatmailDomain", "ESCChatmailProviders", "ESCChatmailJMAP"]
        )
    ]
)
