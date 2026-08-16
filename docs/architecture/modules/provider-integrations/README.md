# Module: provider-integrations

## Responsibility

Own creator-service authorization, opaque secret use, account identity, capability discovery,
provider error classification, normalized metric observations, refresh, and revocation.

## Repository paths

Planned: `packages/provider-integrations/` with one subdirectory per provider and shared simulator.

## Public interfaces

`../../contracts/provider-adapter.md` and the vault boundary in
`../../contracts/security-boundaries.md`.

## Current feature ownership

Primary owner for `connected-social-tools`; supplies safe capabilities and observations to Memory
and the page system.

## Decisions

See `decisions.md`.

## Current-PRD lessons

See `current-prd-lessons.md`.

