# Current Technical Architecture

Planning scope and unresolved choices are tracked in `docs/architecture/planning-ledger.md`.

This architecture is derived from the accepted current product documents in `docs/product/`. It does
not treat the unconfirmed candidate principles as product rules. It does preserve the underlying
requirements that produced those candidates.

## Terms

- A **workspace** is the company boundary for users, saved pages, Memory, and connected accounts.
- A **provider adapter** is the only module that communicates with one external creator service.
- A **capability manifest** is a current list of the accounts, measures, dimensions, history, and
  access limits that one connected service actually exposes.
- A **page definition** is a versioned, declarative description of page layout, visualizations, and
  approved data requests. It contains no credential and no unrestricted executable code.
- A **build job** is durable background work that turns a confirmed page request into a validated
  page definition.
- A **correlation ID** is a safe identifier that joins one browser action to its API request,
  background work, provider calls, and test evidence.
- A **durable event record** is an append-only state-change record written with the related data
  change. It supports progress updates, recovery, and audit. It is not a replacement for telemetry.

## System context

The product is one web application with one source repository. It has a browser client, a server
application, and a durable worker built from the same TypeScript codebase. PostgreSQL stores product
state and durable jobs. A secret-vault boundary stores provider credentials outside ordinary product
records. Provider adapters communicate with supported social-media services. A page-building agent
provider receives only sanitized product context and returns a candidate page definition.

The first deployable shape has two processes from one release artifact:

1. The **web process** serves the browser assets, the HTTP API, and a server-sent event stream for
   progress. A server-sent event stream is a one-way connection that lets the server update an open
   browser page.
2. The **worker process** claims durable build and provider-refresh jobs from PostgreSQL. A separate
   message broker is not required for the first scale target.

The exact hosting platform, identity provider, secret-vault product, and page-building model provider
remain deployment decisions. Their contracts are fixed so those choices do not leak into product
modules.

## Components and ownership

| Module | Owns | Does not own |
|---|---|---|
| `web-experience` | Soft orange shell, side menu, chats, page rendering, loading and recovery states | Credentials, provider calls, authoritative build state |
| `application-core` | Workspace boundary, actor checks, HTTP composition, PostgreSQL access, durable jobs and event records | Provider-specific behavior, generated page choices |
| `provider-integrations` | Authorization, secret references, capability discovery, provider requests, normalization and refresh | Page layout, Memory meaning, raw credential display |
| `organization-memory` | Redacted append-only Memory messages, proposed and accepted summary versions, contradiction state | Provider authorization, page publication |
| `page-system` | Page request conversations, clarification, agent builds, validation, immutable page-definition versions, publication and page queries | Direct secret access, arbitrary production code execution |
| `observability` | Event envelope, correlation propagation, safe structured logs, traces, metrics and evidence queries | Product state or acceptance decisions |

The module documents under `docs/architecture/modules/` define repository ownership and safe change
boundaries. Contracts under `docs/architecture/contracts/` define every cross-module seam.

## Request and event flows

### Browser request

1. The browser creates or continues an `interaction_id` for one meaningful user action.
2. The web process authenticates the actor and derives `workspace_id` from trusted server context.
3. The server creates a `request_id`, continues a trace, and calls one application use case.
4. The use case writes product state and a durable event record in one database transaction.
5. The response returns the resulting state. The event stream reports later durable progress by
   event ID so a reconnect can resume without losing updates.
6. Safe logs and traces contain the same correlation fields. They never contain credentials or full
   conversation bodies.

### Provider connection and refresh

1. `provider-integrations` creates an authorization attempt with a short-lived state value and the
   least requested access.
2. The external service returns to the owned callback. The adapter verifies the state and exchanges
   the grant on the server.
3. Secret values go directly to `SecretVault`; PostgreSQL stores only the returned secret reference,
   safe account identity, granted access, connection state, and capability manifest.
4. The adapter discovers capabilities from documented service behavior and safe verification calls.
   Unsupported measures remain absent or explicitly unavailable.
5. Durable refresh jobs fetch permitted information, normalize it into metric observations, and
   record freshness, empty, partial, rate-limited, revoked, or failed states.

### Memory update

1. The browser sends one Memory message.
2. The server scans for secrets before persistence. It stores a redacted immutable message and a
   redaction marker when needed.
3. The Memory assistant receives the safe conversation, current accepted summary, connection-safe
   account names, and capability manifests. It never receives secret values.
4. The assistant returns questions or a typed summary proposal. The server validates the proposal.
5. The user accepts, corrects, or rejects the proposal. Only an accepted version becomes current.
6. Page builds pin the exact accepted Memory summary version that they used.

### Page build and publication

1. The page chat appends redacted messages and forms a typed request draft.
2. The page system combines the draft with the accepted Memory summary and current capability
   manifests. It marks missing meaning or unavailable data before confirmation.
3. User confirmation creates an immutable request snapshot and a durable build job.
4. The worker gives the page-building agent a sanitized `PageBuildContext`. The agent can return only
   a candidate page definition and explanatory summary.
5. Deterministic validation checks the definition schema, component allowlist, metric capabilities,
   workspace references, limits, accessibility rules, and secret absence.
6. A test renderer runs the definition with deterministic provider fixtures. Publication occurs only
   after validation succeeds.
7. One database transaction writes the immutable page version, makes it current, adds its navigation
   entry, completes the build, and emits `page.published`.
8. The browser event stream shows progress. A reconnect reads durable state rather than relying on a
   missed live message.

### Page view

1. The server loads the current published page definition and the pinned creation context.
2. The page query service resolves only approved metric requests through normalized observations.
3. Each widget receives a `current`, `delayed`, `empty`, `partial`, or `unavailable` data state.
4. One failed source does not hide valid independent widgets. The page exposes the safe recovery
   action for the failed connection or refresh.

## State machines

Transitions use compare-and-set version checks. Repeated requests with the same idempotency key
return the first result instead of creating duplicate state.

### Connection

`DISCONNECTED -> AUTHORIZING -> CONNECTED`

- `AUTHORIZING -> DISCONNECTED` on cancellation or denied access.
- `CONNECTED -> LIMITED` when requested access is incomplete.
- `CONNECTED|LIMITED -> EXPIRED|REVOKED|UNAVAILABLE` when later access fails.
- `EXPIRED|REVOKED|UNAVAILABLE|LIMITED -> AUTHORIZING` on reconnect.
- Any active state can move to `DISCONNECT_PENDING -> DISCONNECTED` after impact confirmation.

### Memory summary

`NO_SUMMARY -> PROPOSED -> ACCEPTED`

- An accepted version is immutable.
- A later change creates a new `PROPOSED` version with the prior accepted version as its parent.
- `PROPOSED -> REJECTED` leaves the current accepted version unchanged.
- A conflict marks a proposal `NEEDS_CLARIFICATION`; it cannot become current until resolved.

### Page build

`DRAFT -> NEEDS_CLARIFICATION -> READY_FOR_CONFIRMATION -> QUEUED -> BUILDING -> VALIDATING -> PUBLISHED`

- A feasible draft can move directly to `READY_FOR_CONFIRMATION`.
- A missing connection or capability moves the request to `BLOCKED` with a typed recovery action.
- `QUEUED|BUILDING|VALIDATING -> FAILED_RETRYABLE|FAILED_FINAL` records a safe cause.
- `FAILED_RETRYABLE -> QUEUED` creates a new attempt for the same immutable request snapshot.
- Only `PUBLISHED` creates or replaces a side-menu page destination.

## Data model

All workspace-owned tables include `workspace_id`. All mutable aggregates include `version`,
`created_at`, and `updated_at`. Human-facing identifiers are not used as authorization decisions.

Core records are:

- `workspace`, `actor_membership` and server-derived `ActorContext`.
- `provider_connection`, `provider_account`, `capability_manifest`, and opaque `secret_ref`.
- `metric_observation` with canonical measure, provider measure, dimensions, period, observed value,
  source time, fetched time, and availability state.
- `memory_conversation`, immutable `memory_message`, `memory_summary_version`, and its acceptance state.
- `page_conversation`, immutable `page_message`, `page_request_snapshot`, `page_build`,
  `page_definition_version`, and `navigation_entry`.
- `durable_job` with lease and retry fields.
- `domain_event` with the safe event envelope.

Conversation records store redacted message text. When the secret scanner changes input, the stored
message contains a replacement marker and redaction metadata, not the secret. Logs and events store
only identifiers, counts, state transitions, classifications, and hashes that cannot reconstruct
the conversation.

## Reliability and graceful failure

- State changes and their durable event records commit in one transaction.
- Workers use leases. Another worker can reclaim an expired lease after a crash.
- Provider reads use bounded retries with jitter, service-specific rate-limit handling, and circuit
  breaking. Authorization and user confirmation are never retried automatically.
- Build and refresh commands use idempotency keys. Retries cannot publish duplicate pages or metric
  observations.
- The event stream accepts a last event ID and replays durable events in order.
- Page publication is atomic. A failed candidate cannot replace the last published version.
- Each widget has an independent availability state. Partial failure remains visible and useful.
- Database backups, secret-vault recovery, and restore tests are required before production. Exact
  recovery time and recovery point targets remain open.

## Observability

The observability module uses OpenTelemetry-compatible traces, metrics, and structured logs. Every
meaningful frontend event, API operation, job transition, provider attempt, agent step, validation
result, and page render uses the event contract in `contracts/events.md`.

The required correlation chain is:

`interaction_id -> request_id -> trace_id -> job_id/build_id -> provider_request_id`

Tests query safe event evidence by `ticket_id`, `criterion_id`, and correlation fields. Production
events do not contain secret values or full conversation text. Redaction is tested before export.

## Security

- The server derives workspace and actor context from authenticated state. It does not trust IDs in
  browser input for access decisions.
- Every product query and mutation checks workspace ownership. The role model remains a product
  decision; authorization defaults to deny when no policy grants access.
- Provider authorization uses service-standard redirect protection, short-lived state, least access,
  and server-side credential exchange.
- Provider secrets live behind `SecretVault`. Only `provider-integrations` can resolve a secret
  reference, and only for a named provider operation.
- Secret scanning occurs before chat persistence, agent input, event creation, and log export.
- Provider content, conversation content, and agent output are untrusted input. They cannot issue
  system commands or select secret references.
- The page-building agent has no network route to provider services, no secret-vault access, no
  database write access, and no arbitrary deployment permission.
- Candidate page definitions pass deterministic validation. The page runtime supports only approved
  components, transformations, and metric queries.
- Browser sessions use secure cookies, request-forgery protection, content security policy, output
  encoding, and origin checks. Exact identity and key-management products remain open.

## Deployment and operations

- One release artifact contains browser assets, server code, worker code, database migrations, and
  the page-definition schema.
- The same artifact moves through development, pull-request validation, staging, and production.
- Database changes use backward-compatible expand-and-contract migrations.
- Readiness checks cover database access, required vault access, and job leasing. Provider outages
  affect only their own capabilities and pages.
- Pull-request checks include type checks, lint, unit tests, contract tests, migration checks,
  provider-adapter fixtures, page-definition validation, browser journeys, accessibility checks, and
  event-chain assertions.
- Staging uses provider sandboxes where available and deterministic simulators for denial, missing
  permission, expiration, rate limit, empty, partial, and outage cases. Live provider smoke tests run
  only with approved test accounts.
- Production needs encrypted backups, restore tests, secret rotation, rate-limit alarms, failed-job
  alarms, error-budget targets, and a rollback procedure. Hosting and quantitative targets remain
  unresolved.

## Active module documents

- `docs/architecture/modules/web-experience/`
- `docs/architecture/modules/application-core/`
- `docs/architecture/modules/provider-integrations/`
- `docs/architecture/modules/organization-memory/`
- `docs/architecture/modules/page-system/`
- `docs/architecture/modules/observability/`

## Active contracts

- `docs/architecture/contracts/http-api.md`
- `docs/architecture/contracts/data-model.md`
- `docs/architecture/contracts/provider-adapter.md`
- `docs/architecture/contracts/page-definition.md`
- `docs/architecture/contracts/page-builder-agent.md`
- `docs/architecture/contracts/events.md`
- `docs/architecture/contracts/security-boundaries.md`
- `docs/architecture/contracts/test-entrypoints.md`
