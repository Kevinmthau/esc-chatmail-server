# ESC Chatmail Server Repo Guide

## Purpose

This repository is the new iOS-client-focused codebase for a self-hosted version of ESC Chatmail backed by Stalwart and using JMAP as the primary client protocol.

## Hard Constraints

- Do not implement Gmail in this repo.
- Do not use IMAP as the primary client protocol.
- Keep protocol DTOs separate from app domain models.
- Preserve the chat-like product UX.
- Prefer small, reviewable commits.

## Current Architecture

The project is currently organized as a Swift package with these modules:

- `ESCChatmailDomain`
  Provider-agnostic account, mailbox, conversation, message, attachment, pagination, and sync-state models.
- `ESCChatmailProviders`
  Provider contract surface, including `MailProvider`.
- `ESCChatmailJMAP`
  JMAP DTOs, transport, mapping, and `JMAPProvider`.
- `ESCChatmailSync`
  Provider-agnostic sync orchestration.
- `ESCChatmailUI`
  Mock-backed SwiftUI inbox/conversation rendering.
- `ESCChatmailStalwartSmoke`
  Opt-in executable for validating a live self-hosted Stalwart JMAP deployment.

## Boundary Rules

- Domain models must not import JMAP DTOs.
- UI code should consume domain snapshots and view models, not provider DTOs.
- `SyncEngine` should depend on `MailProvider`, not directly on `JMAPProvider`.
- JMAP request/response translation belongs in `ESCChatmailJMAP`.

## Current State

- JMAP session bootstrap is implemented.
- Mailbox fetch is implemented.
- Conversation summary fetch is implemented using collapsed thread queries.
- Full conversation hydration is implemented via `Thread/get` plus `Email/get`.
- Incremental sync is not truly implemented yet.
  `syncMailbox` currently falls back to a full refresh shape.

## Verification

Use the full Xcode toolchain when running Swift commands:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
swift test
```

## Live Stalwart Smoke Path

Use the smoke tool before making deeper assumptions about live Stalwart/JMAP behavior:

1. Copy values from `Scripts/stalwart-smoke.env.example`.
2. Export the required `ESC_JMAP_*` environment variables.
3. Run:

```bash
./Scripts/run-stalwart-smoke.sh
```

Required environment variables:

- `ESC_JMAP_BASE_URL`
- `ESC_JMAP_EMAIL`
- `ESC_JMAP_USERNAME`
- `ESC_JMAP_PASSWORD`

Optional environment variables:

- `ESC_JMAP_SESSION_URL`
- `ESC_JMAP_BEARER_TOKEN`
- `ESC_JMAP_INBOX_MAILBOX_ID`
- `ESC_JMAP_PAGE_SIZE`
- `ESC_JMAP_PREVIEW_LIMIT`

## Preferred Next Steps

When extending the repo, prioritize work in this order:

1. Validate behavior against a live Stalwart server when changing JMAP assumptions.
2. Implement true incremental sync on top of validated JMAP behavior.
3. Add persistence and offline reliability after the network model is stable.

## Avoid

- Adding Gmail-specific concepts to domain models.
- Reintroducing IMAP-first architecture.
- Letting JMAP wire types leak into UI or sync code.
- Conflating smoke/integration behavior with deterministic unit tests.
