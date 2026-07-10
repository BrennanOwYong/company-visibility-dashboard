# Per-phase build state (output-driven method) — updated 2026-07-10

Method (user directive): build a phase -> run it on the site-cloner problem statement
(knowledge/prd/product.md) -> read the phase's ACTUAL outputs as the iteration signal ->
fix -> freeze -> feed the next phase. Proof the pipeline is done = the site cloner comes out right.

## Phase status
- requirements (PM -> prd/product.md + acceptance): FROZEN (proven prior runs)
- planning (specs + architecture + iface contracts + feasibility): FROZEN
- roadmap (skill): PLUMBING-PROVEN in ../attempt_2_roadmap, NOT gold-frozen.
    Clue from inspecting the output (../attempt_2_roadmap/kanban/clone-site.md):
      (1) title empty  -> mechanical extraction wrong
      (2) --build is a POINTER, not the finalized implementation the skill contract requires
    ROOT CAUSE: roadmap ticket hydration is an LLM task (planner agent reasons each spec
      into --build/--title/--testing). A bash script cannot produce gold tickets.
    NEXT: run the roadmap stage via the PLANNER AGENT (spawn technical-planning-agent,
      it invokes the roadmap-and-branching skill) on the frozen plan, so --build carries the
      real implementation. THEN dispatch wave 0 and read the build outputs.
- build / validate / integrate: not yet run under the new pipeline. First empirical test = wave 0
    (wire-mesh, control-settings) -> build -> RUNNING_TESTS -> kanban-spawns-validator -> inspect.

## Blocker
Model session limit exhausted (resets ~08:10 Asia/Singapore). Heavy agent work (planner,
builders, workflows) fails until reset. Cheap file inspection by the main session still works.

## Assets from the interrupted harden workflow (kept as clues, not the driver)
- knowledge/technical/research/meta-harness.md, model-routing.md
- knowledge/KIV.md (all items fleshed + self-improvement loop entry)
- knowledge/audit/messaging-infra.md (only stage audit that persisted)

## Build-stage clues (2026-07-10, wave-0 live run of attempt_2)
- CLUE: spawn-builder only mirrored contracts/+research/ into the worktree, so a builder whose
  ## References named knowledge/spec/* or contracts/acceptance/* found them missing and copied
  them itself. FIX APPLIED: spawn-builder now mirrors prd/, spec/, contracts/, technical/,
  architecture.md (all reference-able layers). Effective for future dispatches.
- Wave 0 (wire-mesh, control-settings) dispatched on Sonnet; rate limit had reset; both took
  active turns and self-healed the missing files. Watch: kanban-ui /graph (nodes recolor live).

## Validate/integrate clue (2026-07-10)
- CLUE: validator ran `kanban-update wire-mesh VALIDATED` (needs_user_test=false) but status was
  written literally as VALIDATED instead of exec'ing kanban-done -> auto-DONE. The exec line exists
  in the bin. Root cause not yet isolated; WATCH the next VALIDATED (control-settings/receiver-core)
  with the re-synced bin. Manually ran kanban-done to unstick + re-synced factory bin -> attempt bin.
- LESSON: seed-attempt snapshots bin at seed time; later factory bin fixes must be re-synced into
  live attempts (or attempts should symlink bin). FIX-LATER: seed-attempt should symlink bin, not copy.
