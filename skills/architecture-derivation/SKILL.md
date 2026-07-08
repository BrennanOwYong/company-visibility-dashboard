---
name: architecture-derivation
description: Use in the technical planner's full-plan pass, after every per-feature spec is refreshed and before interface contracts are written. Reads all knowledge/spec/*.md together and derives the smallest shared architecture that supports the features, writes knowledge/architecture.md (~200 lines with ADRs), then reconciles each spec against it and flips status draft → final. Invoked by the technical-planning-agent only.
---

# Architecture Derivation skill

Derive the architecture FROM the features, never the reverse. This runs once per project (and
once per new milestone), after all per-feature specs exist. Inputs: every `knowledge/spec/*.md`,
`knowledge/prd/product.md`, the acceptance contracts, `knowledge/technical/research/*.md`,
`knowledge/platform/*.md`, AGENTS.md, modules.json, `knowledge/lessons.md`.

## Step 1 — read everything together, then unify
Read ALL feature specs in one pass. Unify shared needs into shared elements; fill the gaps where
one feature expects what another provides; resolve conflicting assumptions between specs.
Identify the system shape as it emerges (layered service, data/ML pipeline, browser extension,
CLI, library, event-driven) and design ONLY the shared elements that shape needs. Do not assume
a server and a database; do not force a shared layer the features do not need. The architecture
may be thin — thinness is success, not laziness.

## Step 2 — hunt the non-obvious supports
Before settling for the literal reading of each spec, actively look for structural moves that
support several features at once or make a hard feature cheap. Work through this list against
the specs and note which apply (and record WHY the rejected ones were rejected):
- **Entity recognition / shared domain model:** do multiple features secretly talk about the
  same entities under different names? Naming the entity once (one model, one id scheme, one
  lifecycle) often collapses several features' "needs" into one element.
- **Events over queries:** if two features need to know when something changed, one event
  stream beats N pollers and makes the next feature free.
- **Derived state over stored state:** can a feature's data be computed from what another
  feature already records, instead of writing a second copy that can drift?
- **Precompute at write time** what a feature reads often; a materialized view beats a hot path
  recomputation when the read/write ratio is lopsided.
- **State machines for lifecycle-heavy features:** if a spec has many "when X while Y" rules,
  an explicit state machine (states, transitions, guards) replaces a pile of booleans and makes
  the negative paths enumerable.
- **A single integration seam per external system:** every external API gets ONE adapter module
  owning auth, retries, and shape-mapping; features consume the adapter, never the API.

## Step 3 — keep it tight (non-negotiable defaults; deviation needs an ADR)
- **Webhooks/push over polling** unless the external system offers no push at all — and then
  the poller is one shared element with stated interval and backoff, never per-feature loops.
- **Type enforcement end to end:** every seam's shapes are typed and validated at the boundary
  (vendor-published types where they exist; schema validation at ingress). No `any`, no
  untyped escape hatches — an untyped seam is a seam without a contract.
- **One query interface for storage;** no feature talks to the store directly.
- **Unique, greppable names** for modules and functions — an agent's search loop must find one
  hit, not seven.
- **Idempotent handlers** on every webhook/event ingress (retries WILL happen).
- **Secrets via environment only;** nothing literal, anywhere.
- **The conventional pattern beats the clever bespoke one** — do not fight the model's training
  in downstream builders.

## Step 4 — cross-cutting UX baseline (provided once, here)
The architecture provides these once so no feature spec reinvents them: loading/skeleton states
for every async surface; designed empty and error states; no hydration flash or layout shift; a
stated caching strategy (what is cached, where, when invalidated); optimistic updates where
safe; a perceived-speed budget for first paint and first interaction. Name the shared elements
that deliver each.

## Step 5 — write knowledge/architecture.md (~200 lines, human-readable before any code exists)
Sections: current state; desired end state; system shape and the shared elements (with which
features each supports); the non-obvious moves adopted (from Step 2) and rejected (with why);
patterns to follow; the UX baseline provisions; ADRs — one per decision: why + rule + how it is
enforced (lint rule, type, review check); open questions. Every external-system decision cites
its `knowledge/technical/research/<tech>.md` file; do not restate research.

## Step 6 — reconcile and finalize
Re-read each feature spec against the explicit architecture: replace feature-local inventions
with the shared elements, resolve every seam to a named element, finalize the implementation
approach, and flip `status: draft` → `status: final`. A spec that cannot be reconciled without
violating a feature's perceived flow goes back as an escalation, not a silent compromise.
