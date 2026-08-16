# Page-Building Agent Contract

## Trust boundary

The page-building agent is untrusted generation inside a constrained service boundary. It receives no
credential, secret reference, direct database connection, provider-network route, source repository
write access, shell, or deployment permission.

## Sanitized input

`PageBuildContext` contains:

- Immutable confirmed request snapshot and safe conversation references.
- Current accepted Memory summary version with redaction already applied.
- Safe connected-account names and exact capability manifests.
- Page-definition schema, approved component and transformation catalog, layout limits, and examples.
- Stable quality rules and the prior validator report for a retry.
- Correlation, build, and attempt IDs that contain no user content.

Full credentials, full raw provider payloads, unrelated workspace content, and unaccepted Memory
proposals are forbidden.

## Output

The agent returns one candidate page definition, a purpose summary, a how-it-works summary, and a list
of assumptions or unresolved blockers. Output must parse against a strict response schema. Text
outside the response schema is discarded as diagnostic material after safe filtering.

An unresolved capability, business meaning, unit mismatch, or connection must become a typed blocker.
The agent must not substitute sample values, invent a provider capability, or weaken the confirmed
request.

## Control flow

- One build attempt has fixed input versions and an execution deadline.
- Cancellation stops the model request when supported and marks the attempt retryable.
- A schema failure or validator failure can create a bounded repair attempt with only safe rule
  feedback. It cannot change the confirmed request or pinned context.
- Exceeding attempt, time, or cost limits produces a recoverable failure for the user and preserves
  the conversation.
- The trusted page system, not the agent, decides whether to publish.

## Model-provider boundary

The model client accepts a named model policy, typed request, deadline, and correlation fields. It
returns typed output, usage, provider request ID, finish state, and safe error classification. Model
provider choice, allowed versions, cost limits, and data-processing terms must be set before
production.

## Security tests

Tests inject instructions through user chat, Memory, provider account names, metric labels, and raw
provider fixtures. The agent output must not gain new capabilities, reveal hidden context, select a
secret, call a network destination, or bypass definition validation.

