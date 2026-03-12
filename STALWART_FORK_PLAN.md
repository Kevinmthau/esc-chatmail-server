# Stalwart Fork Plan For ESC Chatmail

## Goal

Operate a self-hosted Stalwart fork as the mail server for ESC Chatmail without breaking the JMAP contract that this Swift client already depends on.

This repository is the client/provider side. The Stalwart fork should live in a separate repository and be treated as an external deployable service.

## Operating Principle

- Keep the fork JMAP-first.
- Preserve standard JMAP behavior wherever possible.
- Put chatmail-specific behavior behind server configuration or extra capabilities instead of changing standard JMAP field meanings.
- Use this repo's smoke tool as the contract check before changing client code.

## Recommended Initial Deployment Target

Start with one production-grade VM, not Kubernetes.

- OS: Ubuntu 24.04 LTS or equivalent.
- Topology: one public host for JMAP and SMTP.
- TLS: publicly trusted certificate.
- Storage: persistent local volume first, off-host backups from day one.
- Reverse proxy: optional, only if it simplifies TLS and request logging.

This keeps the first operational milestone small enough to debug. Horizontal scaling can wait until the protocol and sync model are stable.

## Minimum Server Surface The Client Requires

The current client assumes all of the following are available and stable:

### Session bootstrap

- `GET /.well-known/jmap`
- JMAP session payload advertises `urn:ietf:params:jmap:mail`
- `apiUrl`, `downloadUrl`, `uploadUrl`, `accounts`, and `primaryAccounts` are present
- at least one usable mail account exists

### Authentication

- HTTP Basic auth or Bearer auth
- HTTPS with a trusted certificate

Note: the current transport uses default `URLSession` trust evaluation. Even though the domain model has an `acceptsInvalidCertificates` flag, this repo does not currently honor it in transport code. Use a trusted cert for staging if you want the smoke tool to work unchanged.

### JMAP methods and semantics

- `Mailbox/get`
  - properties used: `id`, `name`, `role`, `totalThreads`, `unreadThreads`, `totalEmails`, `unreadEmails`
- `Email/query`
  - supports `filter.inMailbox`
  - supports sorting by `receivedAt`
  - supports `collapseThreads`
  - supports `position`
  - supports `limit`
  - supports `calculateTotal`
  - returns `ids`, `position`, `total`, `queryState`
- `Thread/get`
  - returns `id`, `emailIds`
- `Email/get`
  - properties used: `id`, `threadId`, `subject`, `preview`, `sentAt`, `receivedAt`, `from`, `to`, `keywords`, `mailboxIds`, `textBody`, `bodyValues`

### Data expectations

- thread IDs are stable
- `receivedAt` and `sentAt` are valid ISO 8601 timestamps
- `keywords["$seen"]` reflects read state
- `preview` is useful for list rendering
- `textBody` plus `bodyValues` can reconstruct plaintext message bodies
- mailbox counts are coherent enough for inbox badges and list totals

## Server Changes To Prioritize In Your Fork

Implement these in order.

### 1. Preserve baseline JMAP compatibility

Do not start by inventing chatmail-only endpoints. First get a mostly unmodified Stalwart deployment working and passing the smoke tool.

### 2. Make thread behavior deterministic for chat UX

The inbox UI in this repo is conversation-first. Your fork should make sure thread grouping is stable and predictable for reply-heavy conversations. If you need custom thread policy, implement it server-side without changing `Email/query` or `Thread/get` semantics.

### 3. Optimize list and hydrate behavior

The current client renders inbox state from collapsed thread queries and then hydrates a full conversation. That means your fork should be tuned for:

- cheap `Email/query` with `collapseThreads = true`
- cheap `Thread/get`
- cheap `Email/get` for full thread hydration
- accurate previews and body extraction

### 4. Validate incremental sync primitives

This repo does not yet implement true incremental sync. Before changing the client, verify what your fork can support for change tracking:

- `Email/queryChanges`
- `Email/changes`
- `Thread/changes`

If upstream Stalwart does not give the behavior you need, this is the first substantial server-side feature to add for the chatmail use case.

### 5. Add send-path features after read/sync is stable

Do not prioritize compose or send until mailbox listing, conversation listing, hydration, and change tracking are all validated against real data.

## Suggested Fork Repository Layout

Use a separate repository for the fork with a layout like this:

```text
stalwart-esc/
  docs/
    chatmail-constraints.md
    jmap-compatibility.md
    rollout-checklist.md
  deploy/
    staging/
    production/
    systemd/
  config/
    staging/
    production/
  patches/
  scripts/
```

Guidelines:

- keep an `upstream/main` tracking branch
- keep your deploy config versioned alongside the fork
- document every protocol-affecting change in `docs/jmap-compatibility.md`
- keep patches reviewable and isolated by behavior

## Deployment Checklist

### DNS and domain setup

- `A` and optionally `AAAA` record for `mail.<your-domain>`
- `MX` record for the mail domain pointing to `mail.<your-domain>`
- `SPF` TXT record for outbound authorization
- `DKIM` selector record
- `DMARC` policy record
- matching reverse DNS for the sending IP

Optional but recommended later:

- `MTA-STS`
- `TLS-RPT`

### Network and ports

- `443` for JMAP over HTTPS
- `25` for SMTP receipt
- `587` for authenticated submission
- `465` only if you explicitly want implicit TLS submission

Avoid exposing IMAP unless you have a concrete compatibility requirement outside this repo.

### Storage and backup

- persistent message store
- persistent queue state
- off-host encrypted backups
- documented restore drill

### Security and operations

- trusted TLS certificate
- secret management for admin and mailbox credentials
- monitoring for queue depth, delivery failures, auth failures, disk, and certificate expiry
- rate limiting and abuse controls
- log retention policy

## Execution Plan

### Phase 0: Fork and baseline

1. Fork upstream Stalwart into a separate repository.
2. Build and run the upstream behavior first.
3. Create one test domain and one real mailbox account.
4. Record the exact upstream commit you started from.

Exit criteria:

- server is reachable over HTTPS
- mailbox can receive and send mail
- JMAP session endpoint responds correctly

### Phase 1: Prove client compatibility

1. Export the environment variables from `Scripts/stalwart-smoke.env.example`.
2. Point them at the fork deployment.
3. Run `./Scripts/run-stalwart-smoke.sh`.
4. Verify:
   - session bootstrap succeeds
   - mailboxes list correctly
   - inbox conversation summaries load
   - at least one conversation hydrates fully

Exit criteria:

- the smoke tool passes against your fork with a trusted cert

### Phase 2: Introduce chatmail-specific changes

1. Add only one protocol-affecting change at a time.
2. Re-run the smoke tool after every server change.
3. Capture real payloads for:
   - session bootstrap
   - `Mailbox/get`
   - `Email/query`
   - `Thread/get`
   - `Email/get`
4. Document any differences from upstream Stalwart.

Exit criteria:

- the fork preserves all current smoke behavior
- thread behavior matches the chatmail product expectations you want

### Phase 3: Unlock real incremental sync

1. Validate what change-tracking APIs your fork supports.
2. If needed, add server-side support for stable mailbox deltas.
3. Only after that, update `ESCChatmailJMAP` and `ESCChatmailSync` in this repo to consume those deltas.

Exit criteria:

- this repo can stop using full-refresh fallback for mailbox sync

### Phase 4: Production hardening

1. Add backups and restore verification.
2. Add metrics and alerts.
3. Add queue and delivery observability.
4. Add key rotation and secret rotation procedures.
5. Run a failure drill for disk loss or host replacement.

Exit criteria:

- you can recover the service without guessing

## Smoke Validation Workflow

Use this repo as the compatibility checker for your fork.

Example:

```bash
export ESC_JMAP_BASE_URL=https://mail.example.com
export ESC_JMAP_SESSION_URL=https://mail.example.com/.well-known/jmap
export ESC_JMAP_EMAIL=user@example.com
export ESC_JMAP_USERNAME=user
export ESC_JMAP_PASSWORD=secret

./Scripts/run-stalwart-smoke.sh
```

Do not treat a passing unit test suite as server validation. Only the smoke path proves that the live fork still satisfies the current client assumptions.

## What Should Change In This Repo After The Fork Is Live

Only after the smoke path is green against your fork:

1. implement true incremental sync in `ESCChatmailJMAP` and `ESCChatmailSync`
2. add tests that encode the validated change-tracking behavior
3. add persistence and offline reliability
4. add compose/send only after read-path behavior is stable

## Non-Goals

- adding Gmail support
- rebuilding the client around IMAP
- leaking server-specific DTOs into domain or UI models
- inventing chatmail-only protocol changes before baseline JMAP behavior is stable
