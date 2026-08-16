# Current Architecture Planning Ledger

The technical planner writes this ledger before detailed synthesis. It tracks active features,
shared capabilities, external boundaries, quality constraints, open decisions, and required output
files. Replace superseded decisions instead of preserving conflicting active guidance.

## Accepted product inputs

| Feature ID | Required technical result |
|---|---|
| `dashboard-shell` | Persistent accessible navigation, soft pastel orange theme, saved page entries, and recoverable route states |
| `connected-social-tools` | Real provider authorization, secret-safe credential custody, capability discovery, reaction-data normalization, refresh, and revocation recovery |
| `company-memory` | Redacted immutable conversation, reviewable versioned summary, contradiction handling, return visits, and safe use by page building |
| `page-builder-chat` | Persistent chat, suggestions, focused clarification, capability checks, durable build progress, and interruption recovery |
| `generated-dashboard-pages` | Validated generated page definition, real connected measures, atomic publication, saved context, return visits, and partial failure states |

The unconfirmed entries in `docs/product/principles.md` are not governing rules. The accepted feature
requirements that caused those candidates remain active inputs.

## Required shared capabilities

- Authenticated company workspace boundary and deny-by-default access checks.
- Append-only redacted conversations and immutable accepted summary/page versions.
- Secret detection before persistence, model input, logging, and evidence capture.
- A secret vault that provider code can access through opaque references.
- Provider adapters with actual capability discovery and normalized availability states.
- Durable background jobs with leases, idempotency, retry policy, and crash recovery.
- A constrained page-definition format and deterministic validator.
- A page-building agent boundary with no secret, provider-network, database-write, or deployment access.
- Correlated browser, API, worker, provider, model, and page-render events.
- Deterministic provider simulators and browser journeys for positive and negative flows.

## Known external boundaries

| Boundary | Required contract | Current choice |
|---|---|---|
| Creator and social-media services | `contracts/provider-adapter.md` | One adapter per provider; first provider list remains open |
| Credential custody | `contracts/security-boundaries.md` | `SecretVault` interface; deployed product remains open |
| User identity | `contracts/security-boundaries.md` | Server-derived `ActorContext`; identity product and role model remain open |
| Page-building model | `contracts/page-builder-agent.md` | Sanitized typed input and declarative output; model provider remains open |
| Telemetry destination | `contracts/events.md` | OpenTelemetry-compatible export; vendor remains open |
| Browser automation | Feature verification sections | `agent-browser` journey execution plus deterministic provider simulator |

## Quality constraints

- Never show unsupported, stale, or unavailable provider information as current fact.
- Never persist or export a credential in product text, generated definitions, telemetry, or evidence.
- Never let generated output execute arbitrary code or choose a network or secret destination.
- Preserve the prior accepted Memory summary and published page when a proposal or build fails.
- Preserve confirmed work across browser, server, worker, or provider interruption.
- Keep valid parts of a multi-source page useful when one source fails.
- Join each meaningful browser action to backend and worker evidence with correlation IDs.
- Keep the browser shell and saved navigation independent of live provider response time.

## Decisions made in this phase

- Use one TypeScript source repository with a browser client, HTTP server, and worker process.
- Use PostgreSQL for product state, durable jobs, and durable event records. Do not add a message
  broker until measured scale requires one.
- Store credentials in a secret vault. Store only opaque references and safe account metadata in
  PostgreSQL.
- Normalize provider information before page rendering. Do not make broad provider fan-out calls in
  a browser page request.
- Let the page-building agent create only a typed page definition. The trusted application validates
  and executes it through approved components and provider capabilities.
- Store conversations after secret redaction. Preserve accepted summaries and published definitions
  as immutable versions.
- Use durable database events for recovery and progress replay, and OpenTelemetry-compatible signals
  for operations and test evidence.

## Decisions still open

- Hosting platform, regional topology, and production scale targets.
- Identity provider, company roles, and role permissions.
- Secret-vault and encryption-key products.
- First-release social providers, test accounts, metrics, history, and freshness targets.
- Page-building model provider, model version policy, cost limit, and completion-time target.
- Conversation, observation, page, event, and audit retention periods.
- Memory approval, history, rollback, and evidence visibility policy.
- Exact visual design tokens, icon rules, and supported browser/device matrix.
- Production recovery point, recovery time, availability, latency, and error-budget targets.
- Whether the first production environment needs provider webhooks or scheduled refresh only.

## Required output files

| Output | Status |
|---|---|
| `docs/architecture/overview.md` | Written and seam-reviewed |
| `docs/architecture/quality-attributes.md` | Written and seam-reviewed |
| `docs/architecture/contracts/http-api.md` | Written |
| `docs/architecture/contracts/data-model.md` | Written |
| `docs/architecture/contracts/provider-adapter.md` | Written |
| `docs/architecture/contracts/page-definition.md` | Written |
| `docs/architecture/contracts/page-builder-agent.md` | Written |
| `docs/architecture/contracts/events.md` | Written and reconciled with feature event chains |
| `docs/architecture/contracts/security-boundaries.md` | Written |
| `docs/architecture/contracts/test-entrypoints.md` | Written and verified against the split factory test contract |
| Current module documents for six named modules | Written |
| One feature architecture view for each of five accepted features | Written |
| `docs/architecture/roadmap.json` | Written and validated in roadmap phase |
| `bin/project-test` | Whole-project terminating check defined and passing |
| `bin/project-dev` | Persistent loopback test launcher contract defined; application target remains for the first builder |

Builder dispatch and application code are explicitly outside this phase. `roadmap-sync` creates only
thin runtime state that links the accepted product and architecture files.

## Seam review result

- All provider calls and credential use cross `provider-integrations` only.
- All generated output crosses the page-definition validator; no feature adds an executable-code
  escape.
- Memory and page conversations use the same redaction boundary and immutable-message rule.
- All long work uses `application-core` durable jobs and event replay.
- Every feature event chain uses names declared in `contracts/events.md`.
- Each product done criterion has objective verification in its feature architecture view.
- No architecture file changes product truth or treats a candidate principle as confirmed.

## Roadmap-phase decisions

- `dashboard-shell` establishes the shared application and navigation code.
- `connected-social-tools` and `company-memory` can build in parallel after the shell because they
  use documented contracts and do not require each other's merged implementation.
- `page-builder-chat` requires both connected capability data and accepted Memory behavior.
- `generated-dashboard-pages` requires the complete page-build and publication path.
- Every active feature has browser flows and subjective questions, so every roadmap entry declares
  browser control and later subjective UX testing.
- The terminating candidate check and persistent test launcher use separate entrypoints.
