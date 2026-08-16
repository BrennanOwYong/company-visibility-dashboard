# Module: application-core

## Responsibility

Own trusted workspace context, HTTP use-case composition, PostgreSQL transactions, durable jobs,
durable event records, idempotency, and worker leases.

## Repository paths

Planned: `apps/server/`, `apps/worker/`, `packages/application-core/`, and `packages/database/`.

## Public interfaces

`ActorContext`, transaction boundary, durable job lease API, domain event append/replay API, and the
routes in `../../contracts/http-api.md`.

## Current feature ownership

Shared foundation for all five active features. It does not own feature decisions.

## Decisions

See `decisions.md`.

## Current-PRD lessons

See `current-prd-lessons.md`.

