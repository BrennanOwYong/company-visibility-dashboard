# Notion re-sync + kanban descriptiveness gap (2026-06-21)

Re-grounded against the latest Notion. What changed since the last sync, and how the repo's
ticket-emission compares to the now-detailed Roadmap & Branching spec.

## What changed in Notion

1. **Technical Planning Agent — new "Deep Review (brownfield)" phase (step 6).** Per task, just
   before that task builds: validate the task's assumptions against a LIVE CODE INDEX (a
   symbol-and-dependency graph from tree-sitter / LSP / code-graph, regenerated incrementally per
   commit, never hand-edited). On invalidation, re-plan (re-derive an implementation satisfying the
   SAME acceptance contract + propagate to dependents) OR name a concrete addressable blocker.
   Never outputs "impossible". Has its own verbatim check prompt. NOT in the repo yet.

2. **Roadmap & Branching — now a full spec** (was just my simpler SKILL.md). It is the answer to
   "how does the planner put info into kanban descriptively enough to one-shot a builder." Details
   below.

3. **Condensed Wisdom — new section "builder dispatch and persistence":** fresh context per card;
   the builder re-hydrates from durable artifacts (its spec/handoff, interface contracts,
   architecture doc, lessons), not a carried conversation; carry context only within one continuous
   coupled build; compact past ~40-60% window. After-action reports: two stages — raw AAR per
   ticket + a separate MINING pass that promotes repeated patterns into skills/scripts/rules, and
   prunes stale ones. Persist at narrowest scope, widen on recurrence.

## Repo ticket emission vs the Roadmap & Branching spec — the gap

The spec's canonical task (tracker-agnostic, one task = one ticket = one dispatchable unit):
build-plan.yaml is the SOURCE OF TRUTH; trackers are mirrors via thin adapters. Fields per task:
`id, title, depends_on, cross_branch_deps, blockers, interface_in, interface_out, acceptance_ref,
build_and_test, resources`; per branch: `branch, worktree`; plus `integration_branch, concurrency`.
Also emits `build-plan.mmd` (Mermaid view).

Repo today (`skills/roadmap-and-branching/SKILL.md` + `kanban-create`):
- Writes a PROSE `knowledge/build-plan.md`, not `build-plan.yaml` + `.mmd`.
- Ticket = `kanban/<issue>.md` via kanban-create flags: intent/build/success/testing/depends-on/
  needs-infra/links. Good coverage of intent+build+success+testing.
- MISSING vs spec: `build-plan.yaml` as canonical source of truth; `interface_in/interface_out`
  (the contract refs the task consumes/produces); `acceptance_ref` as an explicit link;
  `build_and_test` as an explicit "build through functional test, confirm AC1..ACn before commit"
  instruction (we fold this loosely into --build/--testing); `resources` progressive-disclosure
  links; `cross_branch_deps`; typed `blockers` (taste-review vs external-infra); the
  tracker-ADAPTER framing (emit()/sync_status(), factory-specific fields in a fenced factory block).

## Open decisions before aligning the skill (do not change unilaterally)

- **State vocabulary conflict.** Notion now uses `BACKLOG, READY, IN_PROGRESS, NEEDS_VALIDATION,
  NEEDS_ACTION, BUILT, DONE`. The repo uses `NOT_STARTED, IN_PROGRESS, NEEDS_SETUP, NEEDS_TESTING,
  COMPLETE` (per the owner's earlier explicit instruction). These differ. Owner must pick.
- **Adapter abstraction.** Spec wants kanban behind an emit()/sync_status() adapter so Linear/Jira/
  GitHub/etc. plug in later (this is the repo's KIV 8). Owner reserved this.
- **build-plan.yaml as source of truth** vs the current per-ticket-files-as-truth. Adopting yaml
  changes kanban-create/dispatch to read from it.
- **taste-review blocker + NEEDS_VALIDATION state** imply the validator gate, which isn't built.

## Recommendation
Align the roadmap skill to the spec's canonical task incrementally: add the missing one-shot
fields (acceptance_ref, build_and_test, interface_in/out, resources, typed blockers) to kanban-create
first (highest value for one-shotting), then decide build-plan.yaml + adapters + state vocab as
separate steps. Deep Review and the Validator are their own phases.
