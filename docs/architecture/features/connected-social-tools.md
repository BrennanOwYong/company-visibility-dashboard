# Feature implementation: connected-social-tools

Product truth: `docs/product/features/connected-social-tools.md`

## Architecture elements used

- `web-experience`: provider catalog, connection state, authorization explanation, impact review,
  reconnect, and visible recovery.
- `provider-integrations`: one adapter per provider, authorization, vault use, capability discovery,
  metric refresh, error mapping, and revoke.
- `application-core`: actor policy, connection records, jobs, transactions, and durable events.
- `observability`: safe authorization, provider, capability, refresh, and removal evidence.
- Contracts: `provider-adapter.md`, `security-boundaries.md`, `http-api.md`, `data-model.md`, and
  `events.md`.

## Feature-specific implementation

The provider catalog comes from installed adapters, not marketing claims. Each connection shows the
adapter descriptor and the account's current capability manifest. Authorization uses the provider's
trusted redirect. The callback writes credential material directly to `SecretVault`; normal product
records and browser responses contain only a safe account identity and state.

Capability discovery is a required connection step. A provider or account is usable only for the
metrics declared available in that immutable manifest. Refresh jobs normalize permitted values and
keep empty, delayed, partial, and unavailable separate from zero.

## Inputs, outputs, and contracts

- Input: provider key, requested purpose, actor policy, callback, and explicit removal confirmation.
- Output: safe account identity, connection state, granted access, capability manifest, refresh state,
  impacted page IDs/titles, and recovery code.
- Secret output: credential material goes only to `SecretVault.store`; the resulting reference is
  private to `provider-integrations`.
- Page and Memory modules receive safe names and capability manifests. They never receive a token,
  callback authorization code, or secret reference.

## Data and control flow

1. The user chooses a catalog provider; the server checks `manage_connections` policy.
2. `beginAuthorization` creates a single-use state bound to session, workspace, provider, and expiry.
3. The callback verifies state before provider exchange.
4. The adapter stores credential material in the vault and persists safe connection state.
5. Capability discovery writes an immutable manifest and sets `CONNECTED` or `LIMITED`.
6. Refresh jobs use the secret through the adapter operation, normalize results, and update freshness.
7. Reconnect creates a new attempt. Removal first returns impact; confirmed removal revokes, deletes
   the vault secret, changes state, and emits affected-page state events.

## Failure and recovery behavior

- Cancellation or denial returns `DISCONNECTED` and retains no partial secret.
- State mismatch, replay, wrong workspace, or expiry fails closed and requires a new attempt.
- Missing permission creates `LIMITED` with precise unavailable capabilities.
- Unsupported account data remains `not_supported`; no substitute metric is created.
- Expired or revoked access changes dependent widgets to unavailable and offers reconnect.
- Rate limit and outage use delayed retry; authorization is never retried automatically.
- Removal failure keeps the connection in a safe pending or retryable state and does not claim
  revocation succeeded.
- Secret-like text in normal chat is handled by the shared redaction boundary, not this view.

## Required observability

Authorization success chain:

`ui.user_action -> connection.authorization.started -> provider.authorization.completed -> connection.capabilities.discovered -> connection.state.changed -> ui.page_state.rendered`

Denied chain:

`ui.user_action -> connection.authorization.started -> connection.authorization.denied -> ui.page_state.rendered`

Refresh degradation chain:

`provider.request.started -> provider.request.failed -> connection.state.changed|provider.refresh.completed -> page.data_state.changed`

Removal chain:

`ui.user_action -> connection.removal.confirmed -> provider.revoke.completed -> connection.state.changed -> page.data_state.changed`

No event contains callback values, credential values, raw bodies, direct account identifiers, or
metric values.

## Objective verification

| Done criterion | Objective evidence |
|---|---|
| DC-01 | Simulator authorization and browser callback journey prove safe identity, connected state, and no secret in storage/API/events |
| DC-02 | Capability fixture proves available reactions and limits appear from the manifest |
| DC-03 | Deny and cancel journeys prove no connection/secret and usable retry |
| DC-04 | Missing permission and unsupported account fixtures prove explicit limitation and no invented observation |
| DC-05 | Expired/revoked fixtures prove affected page state and reconnect route |
| DC-06 | Timeout/outage fixtures prove bounded retry and preserved saved context |
| DC-07 | Secret-in-chat journey proves redaction and safe Connected Tools direction |
| DC-08 | Impact, confirmation, revoke, vault deletion, and affected-page browser journey |

Each adapter must pass the shared contract suite. Live provider evidence is separate and needs an
approved test account; lack of live setup is reported as human intervention, not a pass.

## Release and runtime considerations

- Provider callback URLs, client credentials, access scopes, test accounts, and rate limits are
  deployment setup.
- Adapter enablement is per environment. A catalog entry appears only when its adapter configuration
  passes health checks.
- Start with only providers whose requirements and test accounts are approved; the product's complete
  first-release list remains unresolved.
- Secret rotation and provider API-version changes need adapter-specific runbooks and smoke tests.
