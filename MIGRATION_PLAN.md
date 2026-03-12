# Current Architecture Assessment

The repository is currently greenfield. There is no existing iOS app target, provider layer, mail domain model, or sync engine to migrate.

That has two implications:

- The first phase should establish clear architectural seams before networking code lands.
- The repo should encode the product constraints immediately so later work does not drift toward Gmail-specific or IMAP-first assumptions.

## Current Constraints

- Self-hosted ESC Chatmail only
- Stalwart-backed deployments
- JMAP as the primary client protocol
- No Gmail implementation in this repository
- No IMAP as the primary client protocol
- Provider DTOs must remain separate from app domain models
- The chat-like product UX must remain the organizing UI concept

# Target Architecture

## Design Goals

- Keep mail concepts provider-agnostic at the app boundary.
- Keep JMAP protocol details isolated in a provider module.
- Allow the UI to render from deterministic mock data before networking exists.
- Make each migration step small enough for straightforward review and rollback.

## Module Layout

### `ESCChatmailDomain`

Provider-agnostic mail models used by the rest of the app:

- account configuration
- mailboxes
- conversations
- messages
- attachments
- pagination and sync state
- snapshot/state containers consumed by view models

### `ESCChatmailProviders`

Provider-facing contracts:

- `MailProvider` protocol
- provider capability definitions
- provider error surface

This layer should return domain models, not protocol DTOs.

### `ESCChatmailJMAP`

JMAP-specific implementation details:

- JMAP DTOs and protocol envelopes
- JMAP session/bootstrap handling
- mapping from JMAP DTOs into domain models
- `JMAPProvider` implementation of `MailProvider`

This is where Stalwart/JMAP server assumptions belong.

### `ESCChatmailSync`

Provider-agnostic orchestration:

- initial mailbox bootstrap
- mailbox refresh and incremental sync
- thread hydration
- merge logic from provider results into app snapshot state

### `ESCChatmailUI`

Chatmail-facing presentation layer:

- inbox and conversation views
- chat-like thread rendering
- preview/demo screens
- mock-backed view models for Phase 1 rendering

## Architectural Boundaries

- Domain models never import or reference JMAP DTOs.
- `SyncEngine` depends on `MailProvider`, not on `JMAPProvider`.
- UI depends on domain snapshots and view models, not on protocol DTOs.
- Provider implementations own request/response translation into domain models.

# Migration Plan

## Phase 1: Scaffolding

Deliverables:

- `MIGRATION_PLAN.md`
- Swift package/module layout
- provider-agnostic mail domain models
- `MailProvider` protocol
- `JMAPProvider` skeleton
- self-hosted JMAP `AccountConfiguration`
- `SyncEngine` skeleton
- mock inbox/conversation data for UI rendering

Commit recommendation:

1. Add package + migration document
2. Add domain and provider contracts
3. Add JMAP + sync skeletons
4. Add mock-backed UI scaffolding

## Phase 2: JMAP Session Bootstrap

Deliverables:

- session discovery
- authentication wiring
- Stalwart account bootstrap
- capability validation
- opt-in live smoke path against a self-hosted Stalwart deployment

## Phase 3: Mailbox and Conversation Sync

Deliverables:

- mailbox fetch
- conversation list fetch
- thread hydration
- pagination
- incremental sync cursor handling

## Phase 4: Compose and Send

Deliverables:

- draft domain model expansion
- outbound message creation
- optimistic send states
- attachment upload flow

## Phase 5: Offline State and Reliability

Deliverables:

- persisted snapshots
- retry and backoff
- conflict handling
- background refresh strategy

# Phase 1 Scaffolding

## What This Phase Intentionally Does

- Sets naming and boundaries early
- Keeps JMAP types isolated from app models
- Preserves a conversation-first, chat-like UI structure
- Lets UI development proceed without networking

## What This Phase Intentionally Does Not Do

- Implement Gmail
- Make IMAP the primary client path
- Add real network calls
- Add persistence, auth storage, or background sync

## Immediate Next Steps After Phase 1

1. Stand up JMAP session bootstrap against a local Stalwart instance
2. Implement mailbox and thread mapping from JMAP DTOs to domain models
3. Add persistence and sync cursors once network behavior is validated
