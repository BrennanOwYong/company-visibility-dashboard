---
name: roadmap-and-branching
description: Use after the technical plan passes its validation gate. Turns the validated plan (knowledge/spec/, knowledge/architecture.md, knowledge/contracts/iface/) into atomic kanban tickets on their own branches and dispatches builders in dependency order. Invoked by the technical-planning-agent only.
---

# Roadmap and Branching skill

The technical planning agent invokes this after its plan passes the validation gate. It turns
the validated technical plan into a build plan and hydrates the tracker: one atomic, fully
self-contained ticket per task, each on its own branch, dispatched in dependency order.

You do NOT plan or design here. The plan is fixed input. You decompose, order, hydrate, and emit.

Product code lives in its OWN git repo, never the factory tree. Before Step 3, ensure the
product repo exists (convention: `<project>/product`, `git init` + an initial commit) and pass
it as every ticket's `--repo`. spawn-builder refuses a ticket whose repo resolves to the
factory root.

## Inputs (the validated plan)
- `knowledge/prd/product.md` — the single PRD; each feature's section holds product intent (why, goal, user journey, success metric)
- `knowledge/contracts/acceptance/<feature>.md` — definition of done (implementation-independent assertions)
- `knowledge/spec/<feature>.md` — the per-feature technical plan (logic, needs, seams)
- `knowledge/architecture.md` — the derived architecture and ADRs
- `knowledge/contracts/iface/<seam>.md` — interface contract per seam, marked contract-covered or coupled

## Step 1 — decompose into atomic tasks
An atomic task is the smallest unit that one builder can build and that the validator can verify on its own. Build vertically: each ticket is a thin end-to-end slice with its own checkpoint, not a horizontal layer. Where one task needs another's output, make the second `--depends-on` the first — the dependent starts only after its dependency is built and merged, so it builds on real, working code (never a mock).

## Step 2 — order the work
Build the dependency graph from the seams and topologically order it into waves; record the merge order. Tickets with no dependency between them are a parallel wave; a dependent is sequenced via `--depends-on` and starts when its dependency finishes. Within a wave, order dispatch by the user priority column of the PRD's feature index, so what matters most reaches a testable state first. Note any blockers (external infra a ticket needs before it can finish).

## Step 3 — hydrate one ticket per atomic task
Each ticket must carry enough context to be a single one-and-done message to a builder: the builder builds from the ticket alone, with no follow-up questions. Pull every field straight from the plan:

```
kanban-create <issue> --feature <feature-name> \
  --repo    "<the PRODUCT repo path — never the factory root; git init <project>/product first if absent>" \
  --title   "<what to build, one line>" \
  --intent  "<why, from the PRD>" \
  --build   "<the finalized implementation from spec/<feature>.md: logic steps, the elements each touches, the operations, the surfaces — reconciled against architecture.md>" \
  --success "<the acceptance assertions from contracts/acceptance/<feature>.md — the definition of done, implementation-independent>" \
  --testing "<how to bring up the test state, and the acceptance assertions the validator will check on the running artifact>" \
  --depends-on <iss-a,iss-b> \
  --needs-infra "<external systems this task needs, e.g. Stripe account, OPENAI_API_KEY>" \
  --needs-user-test <true|false> \
  --landing-url "<the path the user lands on to test it, e.g. /popup or chrome://extensions — only for user-test tickets>" \
  --links   "[[architecture]],[[iface/<seam>]],[[<module>]],knowledge/technical/research/<tech>.md"
```

Tag `--needs-user-test` on EVERY ticket — this is the one automatic decision that divides the board. Set it `true` when the atomic task produces something a person judges by feel or experience (a screen, a flow, a visible interaction, a perceptible behavior); set it `false` for pure plumbing with no human-perceptible surface (a wire protocol, a background store, a headless service, a data migration). Every ticket is still built and independently validated for function, performance, and requirements regardless — the flag only decides whether, after validation passes, the ticket waits for the human's Test step (`true`) or integrates straight to DONE (`false`). For a `true` ticket also set `--landing-url` so the board's Test button knows where to drop the user; a `false` ticket needs neither that nor a `--testing` state for the human (the validator's own harness is enough).

`--links` MUST include every `knowledge/technical/research/<tech>.md` the plan relied on for this ticket's stack — the planner's research (exact APIs, parameter shapes, gotchas, official-doc links) is part of the briefing, and the builder reads those files instead of re-researching.

After each `kanban-create`, FILL the edge-contract stubs it scaffolded at `knowledge/contracts/<issue>-<dep>.md`: copy or point to the exact shape from `knowledge/contracts/iface/<seam>.md` (endpoint path, request/response schema, event signature, data model). This is the interface spec the dependent's builder reads to know what the dependency provides — it builds against the real, merged dependency (which finishes first), so the contract documents the seam rather than standing in for it.

The bar: if a ticket cannot be made self-sufficient, the plan is under-specified for that seam — return it to the planner rather than emitting a thin ticket. `--success` is the contract the post-build validator checks, so it must be assertions, not vibes, and it includes the architecture's UX-baseline assertions for every user-facing surface (loading/skeleton state visible during async work, no hydration flash or layout shift, empty and error states present, repeat visits served from cache per the caching strategy).

Testing split, non-negotiable: `--testing` carries EVERY test an LLM can run — functional, edge cases, states, the acceptance assertions, the UX-baseline checks — and the builder runs all of it against the live app during the build, before RUNNING_TESTS. The user Test step that follows holds ONLY taste: feel, flow, visual coherence, perceived speed. Anything objectively checkable that reaches the user is a defect in the ticket.

A port is NOT set here; each ticket gets one when its validator boots.

## Step 4 — verify the board before dispatch
```
kanban-graph
```
Confirm: acyclic, no dangling dependencies, and every acceptance assertion is covered by some ticket. The planner's gate already validated the plan; this re-checks the emitted tickets match it.

## Step 5 — record the build plan
Write `knowledge/build-plan.md`: the branches, the ordered atomic tasks, their dependencies, blockers, and the merge order. This is the durable record of how the plan became work.

## Step 6 — spawn branches and dispatch
```
kanban-dispatch
```
This creates a git worktree and `feat/<issue>` branch per READY ticket and launches one builder each (idempotent, re-runnable). Ready = every dependency is DONE (built + merged), so the worktree branches from a main that already holds real dependency code. Dep-free tickets go out first, under the MAX_BUILDERS rate-limit ceiling; a dependent dispatches when its dependency lands (the post-merge hook re-runs dispatch). spawn-builder uses the ticket you created — it does not overwrite it.

## After dispatch
The board is hydrated and builders are running. Your job is done. The build → RUNNING_TESTS → validation →
NEEDS_USER_TESTING (or auto-integrate) → DONE flow is owned downstream.
