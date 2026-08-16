# Feature implementation: company-memory

Product truth: `docs/product/features/company-memory.md`

## Architecture elements used

- `web-experience`: Memory conversation, current/proposed summary presentation, comparison,
  acceptance, correction, conflict, privacy warning, and return state.
- `organization-memory`: append-only messages, redaction, clarification, proposal validation,
  conflict detection, immutable versions, and current accepted pointer.
- `provider-integrations`: safe account names and capability manifests for access-path context.
- `application-core`: actor checks, transactions, version conflicts, durable events, and persistence.
- `observability`: correlation without conversation or summary content.
- Contracts: `http-api.md`, `data-model.md`, `security-boundaries.md`, and `events.md`.

## Feature-specific implementation

Memory has one conversation and zero or more immutable summary versions for the workspace in the
first product shape. It stores the original user-visible conversation only after secret redaction.
When redaction occurs, the immutable message contains a visible typed placeholder so the user can
understand that sensitive input was removed.

The typed summary contains tools, safe accounts, sources, concepts, cross-tool mappings, measures,
audiences, reactions, business meanings, access paths, unresolved items, and evidence message IDs.
A model can propose content, but deterministic validation checks references, required fields,
workspace ownership, and secret absence. Explicit user acceptance changes the current pointer.

For “track Instagram,” clarification remains open until the proposal represents the relevant metric,
account, audience, reaction, business meaning, and access path or marks each missing item explicitly.
This completeness profile is a product-configurable policy because the final minimum remains open.

## Inputs, outputs, and contracts

- Input: one natural-language message, expected conversation version, and `interaction_id`.
- Input context for assistance: redacted messages, current accepted summary, safe account labels, and
  capabilities. Secret values and unaccepted unrelated content are excluded.
- Output: redacted immutable message, clarification questions or typed proposal, redaction notice,
  conflict set, and proposal state.
- Acceptance input: proposal ID and expected current summary version.
- Accepted output: new immutable version ID and current pointer. Page building reads by version ID.

## Data and control flow

1. The server authorizes `edit_memory` for the trusted workspace.
2. The shared scanner redacts before the message transaction. The message and receipt event commit.
3. The Memory assistant receives safe context and returns clarification or a proposal.
4. The server parses the typed output, validates known account/source references, scans again, and
   records a proposal or `NEEDS_CLARIFICATION` conflict.
5. The browser displays original redacted messages separately from the proposed and accepted summary.
6. Accept, correct, and reject use expected versions. Acceptance atomically changes the current
   pointer and emits `memory.summary.accepted`.
7. Later page confirmation pins the current accepted summary version; later Memory changes do not
   mutate that request or an existing page.

## Failure and recovery behavior

- Ambiguous meaning creates focused questions, not an accepted guess.
- Conflicting meaning retains both source messages and the current accepted version until resolved.
- An unconnected source can be described but is marked `access_unverified` with a Connected Tools
  recovery route.
- Secret input is replaced before persistence. No model call receives the value. The browser states
  what class was removed and where safe authorization belongs.
- Model timeout or invalid output preserves the appended message and accepted summary; retry can
  continue from durable state.
- Browser interruption before acceptance leaves the proposal non-current.
- Stale acceptance returns a version conflict and reloads the current proposal/summary for review.
- Unauthorized access returns a non-enumerating denied/not-found state and no content.

## Required observability

Clarification chain:

`ui.user_action -> memory.message.received -> memory.clarification.requested -> ui.page_state.rendered`

Proposal and acceptance chain:

`memory.message.received -> memory.summary.proposed -> ui.page_state.rendered -> ui.user_action -> memory.summary.accepted -> ui.page_state.rendered`

Secret recovery chain:

`ui.user_action -> memory.message.received -> memory.message.redacted -> ui.page_state.rendered -> ui.recovery.selected`

Conflict chain:

`memory.message.received -> memory.summary.conflict_detected -> ui.page_state.rendered`

Safe attributes contain message sequence, redaction class/count, question categories, proposal
version, conflict type, decision state, duration, and IDs. They contain no text.

## Objective verification

| Done criterion | Objective evidence |
|---|---|
| DC-01 | New and returning browser journeys prove start state, redacted conversation, and current summary access |
| DC-02 | “Track Instagram” fixture proves all six clarification categories before completeness |
| DC-03 | Propose, compare, correct, accept journey plus immutability query |
| DC-04 | Later page-build context test proves accepted meaning is used and answered questions are not repeated |
| DC-05 | Conflicting statement fixture proves visible conflict and unchanged current pointer |
| DC-06 | Unconnected source fixture proves meaning retained, access unverified, and connection route |
| DC-07 | Multiple fake secret classes prove pre-persistence redaction, absent model input, and browser recovery |
| DC-08 | Interrupt/reload between proposal and acceptance proves last accepted summary remains current |
| DC-09 | Accept correction, start later page request, and prove new pin while prior published page is unchanged |
| DC-10 | Cross-workspace and no-policy browser/API tests prove no Memory content disclosure |

Browser evidence includes screenshots for original/proposed/accepted distinction and correlated safe
events. Database assertions confirm immutability and secret absence.

## Release and runtime considerations

- Summary schema readers must support current accepted versions through rolling deployment.
- Model provider, model policy, content-processing terms, cost limits, and regional handling require
  approval before live use.
- Shared/team scope, acceptance policy, rollback, retention, deletion, and exact completeness rules
  remain open product decisions.
- Production needs redaction regression fixtures and a restricted response procedure for suspected
  sensitive input.
