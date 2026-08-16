---
name: architecture-derivation
description: Derive the smallest coherent whole-project architecture from confirmed product features and principles, then write one zoomed implementation view per feature. Use only in high-reasoning technical planning, before writing the roadmap.
---

# Derive architecture before feature implementation plans

Treat `docs/product/**` as read-only. Read the parent PRD, optional confirmed principles, and every
active feature together.

1. Identify the system shape and shared domain concepts implied by several features. Do not assume a
   server, database, queue, or shared layer unless the product needs one.
2. Prefer one owned integration boundary per external system, derived state over duplicated state,
   explicit state machines for lifecycle-heavy behavior, and shared capabilities where several
   features enforce the same product principle. Record why each non-obvious move applies.
3. Write `docs/architecture/overview.md`, quality attributes, modules, and exact interface/event
   contracts. Include project-wide UX behavior, observability, security, performance, release, and
   failure-recovery provisions where relevant.
4. Write `docs/architecture/features/<id>.md` for each feature. Map every product outcome and
   applicable principle to named architecture elements, feature-specific logic, contracts, flow,
   failures, events, objective verification, and release considerations.
5. Re-read all feature views together. Remove local reinventions of shared capabilities and resolve
   every seam to a named contract. If the architecture cannot preserve a product outcome, return the
   gap to the Product Manager; never silently change product truth.

Only after this pass use `roadmap-and-branching` to declare chronology and real merge prerequisites.
