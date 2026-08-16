# Provider Adapter Contract

## Purpose

One adapter owns all behavior for one external creator service. Other modules use canonical types and
must not call provider endpoints or interpret provider error bodies.

## Provider descriptor

Each adapter declares:

- Stable `provider_key`, safe display name, and authorization mode.
- Supported account classes.
- The least access sets for capability discovery and each metric family.
- Documented rate-limit categories and retry guidance.
- Available sandbox or simulator behavior.

The descriptor is a claim about adapter support, not a claim that every account grants every
capability.

## Operations

| Operation | Input | Output |
|---|---|---|
| `beginAuthorization` | workspace-safe attempt ID, callback URL, requested purpose | trusted authorization URL, expiry, state digest |
| `completeAuthorization` | verified callback values and attempt | secret material for direct vault write, safe account identity, grants |
| `discoverCapabilities` | secret handle and safe account identity | immutable capability manifest and access limitations |
| `fetchMetrics` | secret handle, capability version, bounded canonical requests, time window | normalized observations and per-request availability |
| `refreshAuthorization` | secret handle when provider supports refresh | replacement secret material and grant state |
| `revokeAuthorization` | secret handle and provider account | confirmed, already absent, or retryable revocation result |
| `healthCheck` | no user credential | adapter configuration and provider reachability state |

Secret material is accepted only as an in-memory handle from `SecretVault`. It is never returned to
the caller, serialized into a job, or logged.

## Capability manifest

A capability contains canonical measure, provider measure, account class, supported dimensions,
minimum and maximum time range, history availability, update behavior, grants, and known limits.
Unavailable capabilities have a typed reason: `not_supported`, `account_ineligible`,
`permission_missing`, `region_limited`, `temporarily_unverified`, or `provider_removed`.

Page building can use only a capability marked available in the exact manifest version pinned to the
request. Runtime refresh revalidates the capability and can downgrade availability without changing
the page's original meaning.

## Error classification

Adapters convert provider responses into `denied`, `permission_missing`, `expired`, `revoked`,
`rate_limited`, `invalid_request`, `not_supported`, `empty`, `temporary_unavailable`, or
`provider_changed`. The result includes retry safety and a safe user recovery code. Raw provider
bodies can enter only restricted diagnostic capture after secret filtering and retention control.

## Test contract

Each adapter supplies deterministic fixtures for success, denial, missing permission, expired access,
revocation, rate limit, empty results, partial results, changed response shape, timeout, and outage.
A provider sandbox smoke test is required when available. A live test account is external setup and
cannot be replaced by a fake pass.

