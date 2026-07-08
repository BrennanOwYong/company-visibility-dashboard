# Factory wisdom — extracted principles and where this repo implements them

Source: [Software Factory Best Practises](https://app.notion.com/p/Software-Factory-Best-Practises-3654111839a88139a317cc96e0cb89ba) (Notion, fetched 2026-07-03). Nineteen sections distilled from 20+ practitioner talks. This file maps each principle onto this factory so drift is auditable: when the setup and the principle disagree, one of them needs a reason.

## The principles, condensed

1. **Context is engineered, not filled.** Minimum context for the minimal correct edit. Sub-agents exist for context control (fork to read a large area, return one short answer), not role-play. Past ~40% window fill, quality drops. Never scold a derailing agent; fresh context instead.
2. **Plan small, plan at altitude (CRISPY).** Models follow ~150-200 instructions; keep each prompt under ~40. Research gathers facts blind to the goal; opinions come later. Build vertically (thin end-to-end slices with working checkpoints), never horizontally by layer. The ~200-line design doc is the highest-leverage artifact; review the short docs, not the long plan.
3. **Read the code, not the plan.** Effort goes to the highest-leverage point: research and plan, where one correction prevents a hundred bad lines.
4. **The maker is never its own judge.** A separate fresh-context evaluator, adversarial stance, before any human sees the work. Tests written by the implementation confirm decisions instead of catching bugs.
5. **Define done before building.** Acceptance contracts authored at spec time, independent of implementation; the validator checks against these, not the builder's tests.
6. **Make the codebase agent-legible.** Prevent bug classes mechanically (lint, import boundaries) rather than finding them. Unique names keep search loops tight.
7. **Capture the why; make specs executable.** ADRs record why + rule + enforcement. PRDs stay light: why, problem, goal, journey.
8. **Deterministic control, durable state.** Structured handoffs (a written record, not live memory), hooks for determinism, state external to the agent's head so every stage is re-instantiable after disruption.
9. **Orchestrate like an engineer.** Deterministic code triggers work; the model handles only the ambiguous decisions. Serial writes, parallel reads.
10. **Right model per seat.** Careful reasoning for planning, code fluency for building, instruction-following for validation; different family for validation where possible.
11. **The system improves itself.** Error-to-rule, lessons capture, after-action mining.
12. **Recover with fresh context.** On derailment, kill and respawn with the same task; never argue with a poisoned trajectory.
13. **Friction is steering.** Humans stay at the few high-judgment points; everything reversible.
14. **The harness shrinks as models grow.** Planner/generator/evaluator is the durable trio; keep orchestration in editable prompts and skills, not hard-coded state machines.
15. **Agents only where ambiguity earns them.** If the decision tree is mappable, write code. Most production agents are deterministic software with small model loops.
16. **Deterministic tools over prose.** A documented function beats a markdown skill; a generated script beats re-parsing with the model.
17. **Aiming is the hard part.** Tune the instruction library and the verifiers between phases; the machinery is the easy 20%.
18. **Measure the last mile.** Failure-mode ontology, labels at review time, domain context over bigger models.
19. **Shipping, not coding, is the product.** Target 2-3x with human-level quality; 10x slop gets discarded in six months.

## Where this repo implements each

| Principle | Implementation here |
|---|---|
| 1 Context engineering | PM never sees knowledge/technical/ (hook-guard); planner forks research sub-agents; per-feature micro-PRDs over one giant spec |
| 2 Small plans, technical contact early | Per-feature FEASIBILITY-CHECK dispatched the moment a flow is confirmed, while requirements gathering continues; architecture.md capped ~200 lines; roadmap-and-branching builds vertical slices |
| 3 Read the code | Coordinator presents short docs and user-test cards; builders attach What-was-built/How-it-works to every ticket |
| 4 Maker never judges | Planner's Step 4 gate is a fresh-context adversarial verifier subagent, >=90 to pass, 3 rounds then escalate; user-testing validator drives the live app (agent-browser) |
| 5 Done defined first | prd-agent authors knowledge/contracts/acceptance/<slug>.md at spec time; roadmap-and-branching copies assertions into --success; validator checks those |
| 7 Capture the why | ADRs in architecture.md (why + rule + enforcement); micro-PRDs carry why/goal/journey only |
| 8 Deterministic control, durable state | bin/pipeline-state (knowledge/pipeline.json) + kanban files + agent-events.jsonl; every agent resumes from state on session start; handoffs are scripts (handoff-to-planner, spawn-agent), not messages an agent must notice |
| 9 Deterministic triggers | prd-check gates the handoff programmatically; post-merge hook triggers the coordinator; kanban-dispatch/kanban-graph compute waves from the dependency graph |
| 10 Model per seat | Coordinator Opus, builders Sonnet, research Sonnet (CLAUDE.md Models) |
| 11 Self-improvement | knowledge/lessons.md read by builders and planner; Lessons-learned section per ticket |
| 12 Fresh-context recovery | spawn-agent is idempotent; kill the tmux session and respawn re-instantiates from pipeline/kanban state |
| 14 Prompts over state machines | Pipeline logic lives in .claude/agents/*.md and skills/, scripts stay thin plumbing |
| 15/16 Code over agents | Existence checks (prd-check), state (pipeline-state), dispatch (kanban-*) are bash; the model only judges content quality and design |

Gaps to close deliberately, not by accident: 6 (no lint/import-boundary enforcement yet — per-project, added when a project exists), 10 (validation not yet routed to a different model family), 18 (no failure-mode ontology yet; agent-events.jsonl is the raw material).

## References

- https://app.notion.com/p/Software-Factory-Best-Practises-3654111839a88139a317cc96e0cb89ba (fetched 2026-07-03)
