# RESUME — fresh-session runbook (authored 2026-07-07)

You are resuming the software-factory build. This is your entry point. Read this, then
`knowledge/factory-build-spec.md` (the full work order), then act. Everything below is decided;
implement, don't re-litigate.

## What this project is
A greenfield "software factory": a pipeline of agents (PM → technical-planning/TS → roadmap
skill → parallel builders → independent validators → user) that turns a non-technical person's
request into shipped software. Design principles + rubric: `knowledge/factory-wisdom.md`,
`knowledge/gold-standard.md`. Flow map: `PIPELINE.md`. Grounding: the Notion "Software Factory
Best Practises" pages (fetched into those docs).

## State on resume (clean this first)
- Stale tmux sessions from the last run are frozen at a rate-limit modal (10 builders +
  kanban-ui + maybe prd-agent/technical-planning-agent). Kill them: `tmux kill-server` (nothing
  live is worth keeping). Then `git worktree prune`.
- The last full run's artifacts are the FROZEN PHASE-1 FIXTURE — keep them: `knowledge/prd/
  product.md`, `knowledge/contracts/acceptance/*.md` (10), `knowledge/technical/feasibility/*`,
  `knowledge/spec/*`, `knowledge/architecture.md`, the 10 `kanban/*.md` tickets. These let you
  test later stages without re-driving the conversation.
- `git status` will be noisy (untracked worktree builds, runtime state). Do not commit blindly.

## Already shipped + verified (do not redo)
- Dispatch concurrency cap (`kanban-dispatch`, slot-gated) — but CHANGE to one-per-ready-branch
  (build-spec §Concurrency).
- Builder ticket-brief write-protection (`bin/hook-guard-ticket`, `BUILDER_ISSUE` in
  spawn-builder, registered in `.claude/settings.json`) — 5-way unit-tested.
- Shift-left status machine: NOT_STARTED → IN_PROGRESS (build+validate loop) → NEEDS_SETUP /
  NEEDS_TESTING (taste only, refused without a passing validation verdict) → DONE.
- PM capture guard (Stop hook), positive-ack dedup-safe delivery, $TMUX-gated identity hooks,
  event-logged inter-agent delegation. All in `bin/`. `scripts/smoke-test.sh` = 15/15.

## Confirmed-working stages (freeze; test forward from here)
1. Requirements → gated handoff — SOLID (9 iterations green).
2. Coherence pass → 92/100 verifier gate → 10-ticket dependency DAG → dispatch — confirmed
   working on the 2026-07-06 run (correct DAG, conditional escalation TS→PM fired).
3. Single-ticket build→validate loop — SOLID, but harness assumes old validator-after-
   NEEDS_TESTING order; rework to validation-inside-IN_PROGRESS.
NEVER confirmed end-to-end: a ticket IN_PROGRESS → validated → NEEDS_TESTING → user → DONE in
the real multi-ticket run (builders never finished last time — rate limit).

## Execution order (the iteration loop)
Test in a SISTER folder, never in-place: `../attempt_<N>_<short-name>/` seeded from the frozen
fixture, `KANBAN_PROJECT_ROOT` pointed at it (build-spec §Test isolation). Models during tests:
PM/TS = Opus, builder/validator = Sonnet (frontmatter + `--model sonnet` in spawn-builder);
THIS thread stays Fable — don't change session model. Verify `CLAUDE_CODE_SUBAGENT_MODEL` in
user settings isn't forcing Fable onto the tmux agents.

STEP 1 — Plumbing changes (each: edit, unit-test, keep smoke-test 15/15):
  a. Concurrency: one builder per ready independent branch (DAG ready-set governs; MAX_BUILDERS
     is just a rate-limit ceiling, default high).
  b. Port assigned on validator boot, not at NEEDS_TESTING (move the alloc block).
  c. spawn-builder passes `--model sonnet`; agent frontmatter models confirmed.
  d. Builder rules: read TS research links in ticket; self-setup infra, NEEDS_SETUP only as
     true last resort; run own tests while building.
  e. Validator: authors the test scripts/browser actions itself from the acceptance contract;
     kept blind to builder's infra/web-setup struggles; referee + N-round cap (contested
     verdict → planner, then human); every assertion traces to a contract line.
  f. TS→PM feasibility: single-pass reason-fully-then-report-per-feature via one queued message
     (drop the rough/deep two-stage — the model keeps skipping it).
  g. Completion→PR→serial rebase-queue onto main→AAR→self-mine repeated steps into skills/
     scripts. (Lesson ROUTING is KIV; the write-side still ships. Evaluate rtk:
     https://github.com/rtk-ai/rtk for token budget.)

STEP 2 — THE PRIMARY TEST: iterate the ROADMAP-CREATION + KANBAN-DISPATCH phases until the
  site cloner one-shots. This is the current focus — the requirements phase is already frozen-
  green, so start from the handoff.
  Setup: `../attempt_1_roadmap-dispatch/` seeded with the frozen requirements fixture
  (knowledge/prd/product.md, the 10 acceptance contracts, feasibility verdicts, specs,
  architecture). Product code builds in ITS OWN target dir/repo, NOT the factory tree (last run
  tangled product into the factory's own files — fix before dispatch).
  Models (MANDATORY for this test): PM/TS = Opus, builders/validators = Sonnet. No Fable on the
  agents. Confirm `CLAUDE_CODE_SUBAGENT_MODEL` isn't forcing Fable.
  Known infra blocker (EXPECTED, not a bug): the AWS CLI cannot be created/provisioned in this
  environment. So `cloud-setup` (and anything needing a real AWS box / receiver deploy) MUST
  legitimately hit NEEDS_SETUP with a clear remark — that is the CORRECT behavior to verify,
  not a failure. Every OTHER ticket should build without it. A run where cloud-setup pauses at
  NEEDS_SETUP and the rest reach DONE = the pass condition.
  Loop: kill stale sessions → reset the 10 tickets to NOT_STARTED → apply STEP 1a concurrency
  cap → fire handoff (or re-dispatch) → watch tickets build 1-2 at a time → fix each defect the
  run surfaces (edit plumbing/prompt, reset, re-run) → iterate until: every non-AWS ticket
  reaches DONE and cloud-setup sits at NEEDS_SETUP. Keep the passing artifacts.
  Assert along the way: DAG shape + waves honored, capped dispatch (no rate-limit wall), real
  product code written to the target repo, validator runs inside IN_PROGRESS, NEEDS_TESTING
  refused without a passing verdict.

STEP 3 — Single-ticket harness reworked to validation-inside-IN_PROGRESS; iterate to green.
  (Supports STEP 2; do whichever unblocks faster.)

STEP 4 — Full end-to-end once STEP 2 passes: score the built cloner against
  `knowledge/gold-standard.md` (Vibecode 100-pt rubric) via the sanity agent (must be written —
  `.claude/agents/sanity-agent.md` doesn't exist yet).

## Watching (for the human)
- Board UI: `KANBAN_PROJECT_ROOT=<dir> node kanban-ui/server.js` → http://localhost:2999
- High-level action feed: `bin/factory-watch` (handoffs, tickets, dispatch, status, verdicts —
  no LLM internals).
- Talk to the PM: `tmux attach -t prd-agent`.

## Known open items / gaps (in build-spec, not yet built)
sanity-agent; validator referee+cap; TS single-pass feasibility; port-on-boot; one-per-branch
concurrency; PR/rebase-queue/AAR-mine; rtk eval; lesson-routing (KIV); Deep Review (brownfield,
later). PIPELINE.md phases 4-5 still show old status names — refresh.
