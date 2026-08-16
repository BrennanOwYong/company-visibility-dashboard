# Quality Attributes

These attributes define required system behavior. Quantitative service targets remain open where the
product requirements do not supply them.

## Product truth and data integrity

- A visible live measure must have a provider connection, capability declaration, source time,
  fetched time, and availability state.
- Unsupported and unavailable data must not become a numeric value.
- Original redacted conversations are append-only.
- Accepted Memory summaries and published page definitions are immutable versions.
- A retry with the same idempotency key must not create a second connection, build, publication, or
  observation.

## Security and privacy

- No secret value may enter product tables, agent prompts, page definitions, telemetry, screenshots,
  or user-visible evidence.
- A secret reference is usable only inside the provider integration boundary and only for the owning
  workspace and provider.
- Every workspace-owned read and write requires a trusted `ActorContext`.
- Generated definitions cannot execute arbitrary code, choose network destinations, or select secret
  references.
- Security tests must include cross-workspace access, forged redirect state, prompt injection,
  secret-in-chat, secret-in-provider-payload, and unsafe agent-output cases.

## Reliability and recovery

- Published pages remain usable when an unrelated provider or widget fails.
- The prior published version remains current when a page build fails.
- A worker crash cannot lose a confirmed request or leave a permanent lease.
- An event-stream reconnect resumes from durable state.
- Authorization cancellation, permission denial, expiration, rate limits, and provider outage have
  distinct recovery states.
- Production release requires a demonstrated database restore and secret-vault recovery procedure.

## Observability and testability

- Every product done criterion has one or more named event chains and objective tests in its feature
  architecture view.
- Frontend and backend events use the same interaction and trace correlation where a browser action
  causes server work.
- A page build is traceable from user confirmation through job transitions, agent result,
  validation, publication, and first render.
- Logs state what happened with safe identifiers. They do not store conversation content or secrets.
- Provider adapters support deterministic fixtures and a fault simulator for browser and contract
  tests.

## Accessibility and user experience

- Primary navigation, connection actions, Memory, chat, progress, page state, and recovery controls
  are keyboard usable and have accessible names.
- Color is not the only signal for selection, failure, freshness, or permission state.
- Enlarged text and narrow layouts retain every primary destination.
- Long-running builds expose durable progress and allow the user to leave and return.
- User-visible status uses product language. Provider and internal error detail remains in safe
  evidence, not in the primary message.

## Performance and scale

- The browser shell and saved navigation load without waiting for provider calls.
- Provider refresh and page builds do not run in an HTTP request.
- Page queries use normalized observations and bounded query plans; they do not fan out to all
  providers during a page render.
- Event replay, conversations, and observations use cursor pagination.
- Build concurrency, provider concurrency, retention, expected workspace count, expected page count,
  and latency targets must be set before a production capacity test.

## Changeability

- A new provider implements one adapter contract and capability mapping. It does not add provider
  rules to page or Memory modules.
- A new visualization implements one approved component contract and deterministic validation.
- Page-definition schema changes are versioned and support existing published definitions.
- Identity, secret-vault, model, telemetry, and hosting providers remain behind named interfaces.
- Active documentation contains only current-PRD decisions and lessons.
