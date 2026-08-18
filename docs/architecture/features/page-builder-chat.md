# Feature implementation: page-builder-chat

Product truth: `docs/product/features/page-builder-chat.md`

## Architecture elements used

- `web-experience`: plus route, opening copy, suggestion cards, chat, clarification, confirmation,
  progress, blockers, resume, and success link.
- `page-system`: persistent conversation, suggestion catalog, request state, feasibility, immutable
  confirmation snapshot, build job, agent boundary, and validation.
- `organization-memory`: current accepted summary version and safe organization meaning.
- `provider-integrations`: safe account identities and exact capability manifests.
- `application-core` and `observability`: durable jobs, event replay, idempotency, and correlated
  evidence.
- Contracts: `page-builder-agent.md`, `page-definition.md`, `http-api.md`, `events.md`, and
  `security-boundaries.md`.

## Feature-specific implementation

The initial suggestion catalog contains stable product prompts for cross-platform retention and
subscriber count over time. Because their final meanings are open, selection creates a draft with
required clarification fields; it cannot silently choose a retention formula or freshness promise.

Each conversation uses a typed request draft: purpose, accounts/sources, audiences, measures,
comparison, time range, freshness wording, page title/icon preference, unresolved items, and
feasibility. Memory fills only fields supported by an accepted summary. Capability manifests decide
whether requested information is available. The user sees the resolved request before confirmation.

Confirmation pins conversation, request, Memory, and capability versions. The build job uses the
constrained agent contract and can publish only after deterministic validation.

The first evaluation uses a `demo` page-code route. This route runs as a background sidecar process,
records queued and building states, waits for the configured demonstration interval, and returns a
reviewed pre-generated page definition. It never starts Claude Code and never represents the result
as model-generated. The durable job and publication contracts remain the same.

The later `glm-claude-code` route starts Claude Code as a separate sidecar process. It supplies one
page request, a constrained output directory, the approved page schema, and the current safe tool
and Memory context. The route uses the Z.AI Anthropic-compatible endpoint. The sidecar receives the
credential through its process environment. The prompt and logs never contain the credential.

## Inputs, outputs, and contracts

- Input: plus selection, suggestion key or redacted natural-language message, and clarification
  answers.
- Safe context: current accepted Memory version and capability manifests for the workspace.
- Draft output: resolved fields, unresolved fields, blockers, alternatives tied to actual capability,
  and readiness for confirmation.
- Confirmation output: immutable request snapshot and build ID.
- Progress output: durable build state, safe status code, retry action, and page ID only after
  publication.

## Data and control flow

1. The plus route creates or resumes a page conversation and loads the suggestion catalog.
2. A message passes through secret redaction and appends with a durable event.
3. Request analysis applies accepted Memory, then checks capability manifests.
4. The page assistant asks only for unresolved product meaning. Unavailable data creates a typed
   blocker or a clearly labeled alternative for user choice.
5. The browser displays the resolved request. Confirmation checks the expected versions and enqueues
   the build atomically.
6. The worker runs the page-building agent, validator, fixture renderer, and publication flow.
7. The event stream shows durable progress. Reload resumes from the conversation and build records.

## Failure and recovery behavior

- Broad requests remain in `NEEDS_CLARIFICATION`; the system never fabricates missing meaning.
- Unconnected accounts create `connection_required` with a safe route and retain the draft.
- Unsupported measures create `capability_unavailable`; alternatives name their different meaning.
- Secret text is redacted before conversation persistence or assistant input.
- Version change between review and confirmation returns a conflict and shows the changed context.
- Model, worker, validator, or renderer failure preserves the conversation and request. A retryable
  attempt can restart with the same snapshot.
- Browser/event-stream interruption does not cancel the build. Reload fetches durable state.
- A final failure creates no published navigation entry.

## Required observability

Opening and suggestion chain:

`ui.user_action -> page.conversation.started -> ui.page_state.rendered -> ui.user_action`

Clarification or block chain:

`page.message.received -> memory.context.selected -> page.capability_check.completed -> page.clarification.requested|page.request.blocked -> ui.page_state.rendered`

Build success chain:

`page.request.confirmed -> page.build.queued -> page.build.started -> page.agent.completed -> page.validation.completed -> page.published -> ui.page_state.rendered`

Failure/retry chain:

`page.build.started -> page.build.failed -> ui.page_state.rendered -> ui.recovery.selected -> page.build.queued`

Events include suggestion key, unresolved category, blocker class, pinned version IDs, attempt, safe
progress code, validation rule IDs, and durations. They exclude chat, Memory, prompt, output, and page
definition text.

## Objective verification

| Done criterion | Objective evidence |
|---|---|
| DC-01 | Plus-button browser journey proves opening value message and actionable suggestion controls |
| DC-02 | Catalog assertion and browser screenshot prove both required suggestions |
| DC-03 | Accepted-Memory fixture proves populated request fields and no repeated known question |
| DC-04 | Broad request journeys prove focused unresolved categories and no guessed confirmation |
| DC-05 | Missing connection and unavailable capability journeys prove preserved draft and safe recovery |
| DC-06 | Feasible request proves durable progress and either validated publication or explicit failure |
| DC-07 | Browser close/reload and worker interruption prove conversation/request/build recovery |
| DC-08 | Secret-in-chat fixtures prove redaction before storage/model input and Connected Tools route |
| DC-09 | Demonstration fixture proves queued/building/published order, explicit preview label, one generated route, and reload persistence |

The tester asserts the full precursor event chain for DC-06, not only the final published screen.

## Release and runtime considerations

- Suggestion text is product-owned content; its technical template cannot define unresolved retention
  or real-time meaning.
- Build budget, timeout, approval boundary, and multi-user editing remain open. The future coding
  route uses `glm-claude-code`; the evaluation route uses `demo` and needs no model credential.
- Page-definition schema and model policy versions are included in the release artifact.
- Staging must run success, blocked, secret, invalid output, timeout, retry, and browser reconnect
  journeys before production.
