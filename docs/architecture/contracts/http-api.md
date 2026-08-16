# HTTP API Contract

## Common rules

- All endpoints use `/api/v1` and JSON, except provider redirects and the event stream.
- Authentication creates a trusted `ActorContext`. The server ignores any browser-supplied
  `workspace_id` for authorization.
- Mutations require `Idempotency-Key` and `X-Interaction-ID` headers.
- Responses include `X-Request-ID`. Trace context uses the W3C `traceparent` header.
- Mutable resource responses include `version`. A change to an existing resource requires
  `If-Match: <version>` and returns `409 version_conflict` when stale.
- Cursor pagination uses `?after=<opaque>&limit=<bounded>`.
- Errors use `{ "error": { "code", "message", "recovery", "request_id" } }`. `message` is safe for
  the user. Provider detail, secrets, and conversation text are not returned.

## Navigation and shell

| Method and path | Result |
|---|---|
| `GET /api/v1/navigation` | Fixed destinations plus current published page entries in stable order |
| `GET /api/v1/pages/{page_id}` | Current published page, definition, context summary, and widget data states |
| `GET /api/v1/pages/{page_id}/context` | Original redacted creation conversation and purpose/how-it-works summary |

## Connected tools

| Method and path | Result |
|---|---|
| `GET /api/v1/providers` | Supported provider descriptors and capabilities that can be checked before connection |
| `GET /api/v1/connections` | Safe account identities, connection states, grants, and current capability manifests |
| `POST /api/v1/connections/authorization-attempts` | Creates a short-lived attempt and returns the trusted provider authorization URL |
| `GET /api/v1/connections/callback/{provider}` | Verifies callback state, stores secrets through `SecretVault`, and redirects to a safe result page |
| `POST /api/v1/connections/{id}/reconnect` | Creates a new authorization attempt for an expired, limited, or revoked connection |
| `GET /api/v1/connections/{id}/removal-impact` | Lists affected published pages without revealing page data |
| `POST /api/v1/connections/{id}/remove` | Requires impact version and explicit confirmation; revokes and deletes the secret reference |
| `POST /api/v1/connections/{id}/refresh` | Enqueues a bounded refresh and returns its job ID |

The browser never receives access tokens, refresh tokens, client secrets, or `secret_ref` values.

## Memory

| Method and path | Result |
|---|---|
| `GET /api/v1/memory` | Conversation identity, latest messages, current accepted summary, and active proposal |
| `GET /api/v1/memory/messages` | Cursor-paged redacted immutable messages |
| `POST /api/v1/memory/messages` | Scans and appends one redacted message; returns redaction state and next clarification/proposal state |
| `POST /api/v1/memory/proposals/{id}/accept` | Makes the validated proposal the new current immutable summary version |
| `POST /api/v1/memory/proposals/{id}/reject` | Rejects the proposal and leaves the current summary unchanged |
| `POST /api/v1/memory/proposals/{id}/correct` | Appends a correction and creates a new proposal; it does not mutate the old proposal |

## Page creation

| Method and path | Result |
|---|---|
| `POST /api/v1/page-conversations` | Creates a saved draft conversation and returns suggestions |
| `GET /api/v1/page-conversations/{id}` | Redacted messages, current request draft, blockers, and latest build state |
| `POST /api/v1/page-conversations/{id}/messages` | Scans and appends one message; returns clarification, feasibility, or confirmation state |
| `POST /api/v1/page-conversations/{id}/confirm` | Pins the request, accepted Memory version, and capability versions; enqueues one build |
| `GET /api/v1/page-builds/{id}` | Durable state, safe progress, recovery action, and published page ID when complete |
| `POST /api/v1/page-builds/{id}/retry` | Enqueues another attempt for a retryable failed build without changing its request snapshot |

## Event stream

`GET /api/v1/events` returns `text/event-stream`. The client sends `Last-Event-ID` when it reconnects.
The server first replays authorized durable events after that ID and then sends new events. Each item
contains the safe event envelope from `events.md`. A heartbeat has no product meaning.

## Required error codes

`not_authenticated`, `not_authorized`, `not_found`, `invalid_input`, `version_conflict`,
`idempotency_conflict`, `secret_redacted`, `connection_required`, `capability_unavailable`,
`provider_denied`, `provider_rate_limited`, `provider_unavailable`, `build_blocked`,
`build_not_retryable`, and `temporary_failure`.

