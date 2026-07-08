# Factory build-spec — pending changes (authored 2026-07-07)

Work order for the next build session. Each item is a decision already made by the owner;
implement, don't re-litigate. Verify each against `scripts/smoke-test.sh` and the relevant
live harness. Grouped by subsystem. Items marked (SHIPPED) are already done.

## Concurrency / dispatch
- (SHIPPED) `kanban-dispatch` has a slot-gated cap so it never fans out all tickets at once
  (frontier sessions freeze at a rate-limit modal, not an error — parallelism is bounded by
  the account usage limit, not cores).
- CHANGE the model from a flat `MAX_BUILDERS=2` to **one builder per independent branch that
  is ready NOW**. "Ready" = all its `dependsOn` tickets are past the point where their
  interface contract is stable (contract-covered → ready immediately via the mock; coupled →
  wait for the dependency to merge). Compute the current ready-set from the DAG each dispatch
  pass; spawn one builder per ready branch, no more. Keep a hard ceiling env
  (`MAX_BUILDERS`) as a rate-limit backstop, default it high (e.g. 8) but let the ready-set be
  the real governor. A branch = a chain of coupled tickets sharing one `feat/<ticket>` line;
  independent branches scale out, coupled tickets within a branch stay serial.

## Builder lifecycle (per ticket)
- Branch is ALWAYS named for the ticket: `feat/<issue>` (already true; keep it invariant).
- Builder works in its git worktree (already true).
- Builder references the docs the TS agent already researched — the ticket links
  `knowledge/technical/research/<tech>.md`. ADD these links into the ticket `--links` / a
  `## References` the roadmap skill fills from the spec, so the builder reads TS's findings
  instead of re-researching.
- While building, the builder DOES its own infra setup (create the local service, wire the
  integration, run the tool) as part of the work. It only sets `NEEDS_SETUP` when it genuinely
  cannot do it itself (needs a credential/account/access only the human has). NEEDS_SETUP is
  the last resort, not the first blocker.
- Builder runs its own small tests as it codes (self-verification — necessary but biased).
- (SHIPPED) Builder cannot edit its ticket's brief (hook-guard-ticket): Intent/Build/Success
  criteria/Testing + frontmatter are immutable to it; completion sections are writable.

## Completion → PR → rebase → AAR → skill-mining
On ticket done:
1. Builder opens a PR for `feat/<issue>`.
2. Builder QUEUES to rebase onto main (serial rebase queue — only one rebase-onto-main at a
   time to avoid conflicts; the queue is the integration point). Needs a `rebase-queue` script
   / lock so parallel branches integrate one at a time in merge order.
3. Once the rebase lands, the AAR is created (extends current `kanban-done` AAR write).
4. The builder is then PROMPTED to scan its own session for repeated steps / patterns of steps
   it took, and BUILD a skill or script that does them, so the next builder doesn't re-derive.
   This is the write-side of the self-improvement loop (wisdom §11 two-stage: capture then mine).
5. Evaluate rtk (https://github.com/rtk-ai/rtk, "rust token killer") for the builder/validator
   token budget and the mining step. Research its actual capability before adopting; if it
   reduces tokens per agent meaningfully it directly raises how many parallel builders fit
   under the account rate limit (see Concurrency).

## Ports
- Do NOT assign a port at the NEEDS_TESTING transition (current behavior reserves it for an
  unknown duration). Assign it on-demand, right as the VALIDATOR/testing agent starts up —
  pick the first free port then, since validation now runs inside IN_PROGRESS (shift-left).
  Move the port-allocation block out of `kanban-update`'s NEEDS_TESTING branch and into the
  validator spawn path.

## Validator (independence + separation)
- Validator authors the tests/scripts (functional test scripts and/or browser actions and/or
  both), NOT the builder. The builder's `--testing` should describe only how to bring up the
  test STATE; the assertions come from `acceptance/<feature>.md`, which the validator derives.
- The validator MUST NOT be made aware of the builder's infra-setup struggles or its need for a
  web action to set something up. Keep the validator's context clean of builder process —
  it only sees the running artifact and the acceptance contract. (Anti-drift: it cannot be
  led toward the builder's interpretation.)
- Anti-reward-hack (from prior design, still to build): builder and validator never negotiate;
  a contested verdict routes to the planner (owns the spec) or, after N rounds, to the human.
  Every validator assertion must trace to an acceptance line — an assertion with no contract
  line is `ticket-underspecified` (planner's gap), never a builder-defect.

## TS→PM feasibility (reframe — lean into the model's grain)
- Drop the rough-then-deep two-stage (the model keeps skipping the artificial mid-turn stop).
  Instead: TS reasons each feature all the way, then reports per-feature feasibility as ONE
  queued tool-call message to the PM (feature, feasible y/n, and if not, why). The full
  reasoning enriches the "why"; the PM translates it for the user. Delivery stays deterministic
  through the inbox queue.

## Lessons dissemination (KIV — deferred by owner)
- The write-side (AAR + self-mine into skills/scripts) still ships. HOW promoted lessons reach
  the right future builders is KIV: revisit after the core loop works end-to-end. Until then,
  mined skills/scripts just land in `.claude/skills` / `scripts/` and `knowledge/lessons.md`
  stays the flat store; do not build scoped-promotion routing yet.

## Test isolation — sister folders (owner directive)
- Run test attempts in a SISTER folder of software_factory_cc, not in-place, to avoid
  cluttering the source repo. Naming: `../attempt_<N>_<short-name>/` (e.g.
  `../attempt_1_roadmap-phase/`). The factory tooling already resolves everything through
  `KANBAN_PROJECT_ROOT` + `~/.claude/.coordinator-root`, so a harness can: copy/clone the
  factory bin+skills+agents into the sister dir (or reference them by absolute path), seed it
  with the frozen fixture artifacts for the stage under test, point `KANBAN_PROJECT_ROOT` at
  the sister dir, and run. Matches the wisdom's "many repo clones over fragile worktrees."
  Each attempt is self-contained and disposable; keep the ones that pass as frozen fixtures.
  Builder worktrees then live under `../attempt_N_x/../worktrees/` (spawn-builder already
  derives the worktree path from the repo root, so this works without change).

## Testing methodology (owner directive)
- Per stage: once the pipeline is verified working for that stage, KEEP the conversation
  history and output artifacts so testing the NEXT stage doesn't restart from scratch. The
  passing requirements artifacts (knowledge/prd/product.md, the 10 acceptance contracts, the
  feasibility verdicts from the 2026-07-06 run) are the frozen phase-1 fixture. Build each
  next-stage harness to CONSUME the prior stage's frozen artifacts (like test-kanban-ticket.sh
  seeds a fixed ticket).

## Model assignment during tests
- Planning agents (PM, TS) = Opus; executing agents (builder, validator) = Sonnet. Set via
  each agent's frontmatter `model:` and, for builders spawned without `--agent`, pass
  `--model sonnet` in spawn-builder. THIS main thread stays Fable — do not change the session
  model. Note: `CLAUDE_CODE_SUBAGENT_MODEL=claude-fable-5` (user settings) governs Task-tool
  subagents; confirm it doesn't override the tmux `--agent` sessions (it shouldn't — those get
  their model from frontmatter/flag), or the test agents will wrongly run Fable.

## Confirmed-working stages (freeze candidates)
- Requirements → gated handoff: SOLID (9 iterations green).
- Coherence pass → verifier gate → roadmap DAG → dispatch: confirmed on the 2026-07-06 run
  (92/100 gate, correct 10-ticket DAG, conditional escalation). Not yet perfect (needed the
  concurrency cap; builders never finished a ticket due to rate limit).
- Single-ticket build→validate loop: SOLID (green, defect-routing proven) but harness assumes
  the old validator-after-NEEDS_TESTING order — rework to validation-inside-IN_PROGRESS.
- NEVER confirmed end-to-end: a ticket going IN_PROGRESS → validated → NEEDS_TESTING → user →
  DONE in the real multi-ticket run. Next target, now unblocked.
