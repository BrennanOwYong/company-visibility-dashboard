# Current Decisions

- PostgreSQL is the single product-state store and durable job queue for the first system shape.
- Aggregate state and its durable event record commit together.
- Workers claim jobs with leases and idempotency keys; no message broker is introduced yet.
- Workspace context comes from authenticated server state and is mandatory for every use case.

Alternatives rejected for now: browser-owned state, process-memory jobs, separate databases per
feature, and an event broker without measured need. These choices reduce recovery gaps and seams.

