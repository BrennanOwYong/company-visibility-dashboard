# Roadmap and Branching skill

The technical planning agent invokes this after its plan passes the validation gate. It turns
the validated technical plan into a build plan and hydrates the tracker: one atomic, fully
self-contained ticket per task, each on its own branch, dispatched in dependency order.

You do NOT plan or design here. The plan is fixed input. You decompose, order, hydrate, and emit.

## Inputs (the validated plan)
- `knowledge/prd/<feature>.md` — product intent (why, goal, user journey, success metric)
- `knowledge/contracts/acceptance/<feature>.md` — definition of done (implementation-independent assertions)
- `knowledge/spec/<feature>.md` — the per-feature technical plan (logic, needs, seams)
- `knowledge/architecture.md` — the derived architecture and ADRs
- `knowledge/contracts/iface/<seam>.md` — interface contract per seam, marked contract-covered or coupled

## Step 1 — decompose into atomic tasks (the contract-writable-seam test)
An atomic task is the smallest unit that one builder can build and that the validator can verify on its own.
- **Contract-covered seam** → the two sides are separable → each side is its own ticket; they build in parallel, each mocking the other against the interface contract.
- **Coupled seam** → cannot be pinned without building one side first → one ticket, or two sequenced tickets with a dependency. Never parallelize a coupled write.

Build vertically: each ticket is a thin end-to-end slice with its own checkpoint, not a horizontal layer.

## Step 2 — order the work
Build the dependency graph from the seams. Topologically order it into waves and record the merge order. Independent tickets are a parallel wave; coupled tickets are sequenced via `--depends-on`. Note any blockers (external infra a ticket needs before it can finish).

## Step 3 — hydrate one ticket per atomic task
Each ticket must carry enough context to be a single one-and-done message to a builder: the builder builds from the ticket alone, with no follow-up questions. Pull every field straight from the plan:

```
kanban-create <issue> --feature <feature-name> \
  --title   "<what to build, one line>" \
  --intent  "<why, from the PRD>" \
  --build   "<the finalized implementation from spec/<feature>.md: logic steps, the elements each touches, the operations, the surfaces — reconciled against architecture.md>" \
  --success "<the acceptance assertions from contracts/acceptance/<feature>.md — the definition of done, implementation-independent>" \
  --testing "<how to bring up the test state, and the acceptance assertions the validator will check on the running artifact>" \
  --depends-on <iss-a,iss-b> \
  --needs-infra "<external systems this task needs, e.g. Stripe account, OPENAI_API_KEY>" \
  --links   "[[architecture]],[[iface/<seam>]],[[<module>]]"
```

The bar: if a ticket cannot be made self-sufficient, the plan is under-specified for that seam — return it to the planner rather than emitting a thin ticket. `--success` is the contract the post-build validator checks, so it must be assertions, not vibes.

A port is NOT set here; each builder gets one at its NEEDS_TESTING transition.

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
This creates a git worktree and `feat/<issue>` branch per NOT_STARTED ticket and launches one builder each (idempotent, re-runnable). Independent tickets go out in parallel; a dependent ticket dispatches when its dependency lands (the post-merge hook signals completion). spawn-builder uses the ticket you created — it does not overwrite it.

## After dispatch
The board is hydrated and builders are running. Your job is done. The build → NEEDS_TESTING →
adversarial validation gate → COMPLETE flow is owned downstream.
