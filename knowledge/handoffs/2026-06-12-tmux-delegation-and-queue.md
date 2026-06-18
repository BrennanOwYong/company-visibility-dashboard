# Handoff — tmux delegation + agent message queue

**Date:** 2026-06-12
**Branch:** claude/coat-phase-handoff-h48hq0
**Author agent:** coordinator (phase-handoff design)
**Status:** BUILT AND TESTED (delegation queue + readiness). Phase-agent wiring (PM/Architect) still pending.

Read this before touching delegation, spawn-builder, hooks, or the kanban ping path.
Two non-communicating agents editing this area will collide. This doc is the source of truth.

---

## Problem being solved

1. The coordinator's work phases do not hand off automatically between non-user-gated
   steps. One long-lived context does everything and bloats.
2. Inter-agent messaging is bare `tmux send-keys` with no readiness check. Messages can
   land on an agent that is mid-turn or at a permission prompt and be lost.

## Decisions locked with the user

- **All delegation goes through persistent interactive tmux agents**, NOT Agent/Task
  subagents. Reason: each delegated agent must persist (will soon link to company memory)
  and keep full agent capabilities (can itself delegate, can nest). Agent-tool subagents
  are ephemeral, cannot nest, and return only a summary. Rejected for this reason.
- **The tmux delegator becomes its own reusable tool.** Every delegation path routes
  through it: the kanban script AND individual agents. No caller uses raw `send-keys`.
- **A queue + readiness layer sits under the delegator** so a message is never delivered
  to an agent that is not idle at its prompt.
- Keep delegation **one layer deep for now.** Deeper nesting is owned by the user.

## Corrected phase model

```
PRODUCT MANAGER  (the main agent — the ONLY surface the user chats with)
  gathers requirements with the user; deliverable: requirements / PRD
  ↓ delegates via tmux delegator, auto once requirements confirmed
TECHNICAL LEAD / ARCHITECT  (persistent tmux agent, full capabilities)
  architects system, builds roadmap, writes interface contracts
  deliverable: roadmap + contracts
  ↓ triggers, auto once deliverable confirmed
KANBAN DISPATCH  (a SCRIPT, not an agent)
  dispatches builder agents (existing spawn-builder pattern)
... more phases to come
```

Each phase emits a named deliverable on disk. Confirmation of that deliverable
(artifact exists + valid) is what triggers the next stage. This is the
"programmatic, not token-based, no-user" handoff. PM→Architect is gated only by the
user signing off requirements; Architect→Kanban is fully automatic.

## Claude Code primitives in play (corrected)

- `phases.json` is NOT a Claude Code primitive. Any such file is a factory convention only.
- Real primitives: persistent tmux Claude sessions (delegation substrate),
  hooks (SessionStart / UserPromptSubmit / Stop) for readiness signalling,
  `tmux send-keys` for delivery.

## Queue + readiness design (BUILT)

State lives under `kanban/`:
- `kanban/agents/<agent>.state`  — `idle` | `busy` (who can receive now)
- `kanban/inbox/<agent>.jsonl`   — pending messages, one JSON object per line `{ts,msg}`

Tools in `bin/` (all built, executable, syntax-checked):
- `tmux-delegate <agent> <message>` — THE single public entry point for all delegation.
  Enqueues the message, then delivers now if the agent is idle, else leaves it queued.
- `agent-state <agent> <idle|busy>` — sets an agent's readiness. Called by its hooks.
- `inbox-drain <agent>` — if agent idle AND tmux session live AND inbox non-empty, pop ONE
  message, mark busy, `send-keys -l` the text then Enter. Called by the delegator and by
  the agent's own Stop hook.

Readiness uses Claude Code's native turn signals (the user's chosen "done talking" primitive):
- `Stop` hook → `bin/hook-agent-idle` → mark idle, then drain one queued message.
- `UserPromptSubmit` hook → `bin/hook-agent-busy` → mark busy (covers human + delegated input).
- Both hooks self-identify by tmux session name and NO-OP outside an active factory session.
- Installed user-level (merged into `~/.claude/settings.json` by factory-init, idempotent).

Bootstrap (first message to a brand-new builder): spawn-builder waits `BUILDER_BOOT_SECONDS`
(default 5) for the TUI to settle, marks the builder idle, then delegates. No pane-scraping.
After the first turn the Stop/UserPromptSubmit hooks own readiness exactly.

Delivery is serialized: one message per idle window. The agent goes busy on delivery and
drains the next queued message when it next finishes talking. No polling, no busy-wait.

## Tests run (this session)
- Busy agent → message held in inbox, not delivered. PASS
- Idle agent with no live tmux session → drain no-ops, message retained. PASS
- Multiple queued messages, special chars (`;` `&`) → JSON-encoded, survive round-trip. PASS
- Unknown state → delivery held (safe default). PASS
- Live tmux session, idle → exact message delivered via send-keys, state flips to busy,
  inbox emptied. PASS

## Callers to migrate off raw send-keys

- `bin/spawn-builder.sh:114-116`  (drop `sleep 4`, use delegator + booted marker)
- `bin/post-merge-hook.sh:31-35`
- `bin/kanban-update:47-48`  (BUILT ping)
- `bin/kanban-resolved:21`

## Open questions for the user

- Exact readiness mechanism: hook-based busy/idle (recommended, in this doc) vs tmux
  pane-content scraping. Awaiting confirmation before the invasive hook install.
- Whether readiness hooks install at user level (`~/.claude/settings.json`, affects all
  sessions on the machine) or per-worktree.

## What this author changed this session

- Added `bin/tmux-delegate`, `bin/agent-state`, `bin/inbox-drain`, `bin/hook-agent-idle`,
  `bin/hook-agent-busy`.
- `bin/factory-init.sh`: installs the two readiness hooks into `~/.claude/settings.json`
  (idempotent merge) and seeds the coordinator's idle state.
- `bin/spawn-builder.sh`: dropped the blind `sleep 4`; first instruction now goes through
  the delegator after a bootstrap settle + idle seed.
- `bin/post-merge-hook.sh`, `bin/kanban-update`, `bin/kanban-resolved`: all four raw
  `tmux send-keys` pings replaced with `tmux-delegate`.

## Kanban Dispatch phase (BUILT AND TESTED — 2026-06-13)

The third phase box (`KANBAN DISPATCH — a SCRIPT, not an agent`) is now built as
`bin/kanban-dispatch`. It is the orchestration layer over `spawn-builder.sh`:
`spawn-builder` creates ONE builder (worktree + tmux Claude session + context +
first instruction); `kanban-dispatch` turns the architect's whole output into all
the builders and reports their combined state.

### CANONICAL STATE VOCABULARY (corrected by user 2026-06-14)
Single-token (UPPERCASE_SNAKE, so `awk '{print $2}'` parsing holds), pipeline order:
`NOT_STARTED → IN_PROGRESS → NEEDS_SETUP → NEEDS_TESTING → COMPLETE`
- `NOT_STARTED` — spawn-builder seeds this; agent has not begun.
- `IN_PROGRESS` — building.
- `NEEDS_SETUP` — paused: user must set up external infra the agent cannot (was NEEDS_ACTION).
- `NEEDS_TESTING` — build done, ready to test (was BUILT). Assigns a port + test card.
- `COMPLETE` — user approved.
`BLOCKED_ON` is REMOVED — the contract-mock model means builders never wait on each
other. Migrated across all runtime scripts, the UI, telemetry tools, CLAUDE.md, SKILL,
HANDOFF template, README. (Inference flagged to user: BLOCKED_ON dropped because the
5-state list was given as complete; consistent with the locked contract decoupling.)

### Port timing (corrected by user 2026-06-14)
A port is a TESTING-phase resource. It is NOT assigned at spawn/dispatch. It is
allocated only at the `NEEDS_TESTING` transition, by `kanban-update`: first free port
from 3001 up, skipping ports already held by other tickets, written to the kanban file.
spawn-builder no longer sets a port or FEATURE_PORT. The manifest carries no ports.

### Architect → Dispatch contract  [SUPERSEDED 2026-06-14 — see the kanban-primitives section below]
The dispatch.json manifest described here was RETIRED. The architect now creates kanban
issues directly via `kanban-create`; `kanban-dispatch` reads NOT_STARTED issues. Kept for
history only — `dependsOn` does NOT gate spawning (builders mock deps), and spawn-builder
is still called once per issue (per-agent, tracked).

### Commands
- `kanban-dispatch [manifest]` — dispatch every not-yet-dispatched ticket. Idempotent
  (skips tickets that already have a `kanban/<issue>.md`). Logs to `kanban/dispatch-log.jsonl`.
- `kanban-dispatch --dry-run` — preview spawns, launch nothing.
- `kanban-dispatch --force` — re-dispatch even tickets with an existing entry.
- Board view is `kanban-check`. The dispatcher no longer has a `--status` mode.

### tmux liveness ↔ kanban state is KIV (item 7)
The earlier `--status`/`DEAD` reconciliation (deriving "session gone before testing")
was REMOVED. Whether liveness maps to a ticket's state depends on the unresolved
single-agent-per-module vs single-agent-many-features question (user researching,
performance inconclusive). Until decided: kanban status declared by the agent is the
only source of truth; do not couple tmux liveness to state. See KIV.md item 7.

### Tests run (2026-06-13 dispatch + 2026-06-14 vocab/port)
- Dispatcher: missing handoff skipped; `\x1f` separator keeps empty dependsOn from
  swallowing repo (was a bug, fixed); idempotency skip; dry-run arg construction. PASS
- Port assigned ONLY at NEEDS_TESTING; IN_PROGRESS leaves port empty; allocator skips a
  port already held (→ 3002, 3003); re-NEEDS_TESTING keeps the same port. PASS
- kanban-check renders new vocabulary; card + coordinator ping fire on NEEDS_TESTING. PASS
- All changed shell + node files syntax-clean.
- Latent bug fixed: bin scripts were committed non-executable (100644) but invoked bare
  by name via PATH → would fail "Permission denied" in a real session. Now 100755 +
  factory-init chmods on install.
- Not exercised: real `spawn-builder` shell-out (launches actual claude); arg
  construction verified via --dry-run, queue path tested in prior session.

## Kanban primitives + issue-sourced dispatch (BUILT AND TESTED — 2026-06-14)

The architect now creates the kanban issues directly from the roadmap; the issue is the
single source of truth and the builder's brief. The dispatch.json manifest is RETIRED.

New primitives (the local-markdown backend of a future pluggable tracker — KIV 8):
- `kanban-create <issue> --feature <name> [--title --milestone --intent --build --success
  --testing --depends-on a,b --needs-infra "X, Y" --links "[[m]],[[i]]" --repo]` — writes
  one issue with all roadmap data. status NOT_STARTED, no port. Refuses to overwrite.
  Scaffolds an empty contract stub per dependency edge at
  `knowledge/contracts/<issue>-<dep>.md` for the architect to fill.
- `kanban-graph [--json]` — reads all issues, prints build WAVES (topological levels =
  what to build and when), the external-infra rollup, and flags dependency cycles and
  dangling deps. Lets the architect verify the roadmap before dispatch.

Canonical issue data model (frontmatter): issue, feature, title, status, milestone, port
(empty until NEEDS_TESTING), repo, branch, worktree (filled at spawn), dependsOn,
needsInfra, links, user_facing, test_command. Body: Intent / Build / Success criteria /
Testing / Dependencies, then the builder-filled sections.

Wiring changes:
- `kanban-dispatch` now reads `kanban/*.md` where status==NOT_STARTED (no manifest). The
  issue file IS the handoff passed to spawn-builder. Idempotent via the `worktree` field
  (set at spawn). `--dry-run` / `--force` retained.
- `spawn-builder` no longer authors the issue body — if the issue exists (architect made
  it) it uses it and only fills branch/worktree (and repo if blank). Creates a minimal
  issue via `kanban-create` only when none exists.
- CLAUDE.md spec phase rewritten: decompose → `kanban-create` per issue → fill contracts
  → `kanban-graph` to verify → `kanban-dispatch`. README + SKILL updated.

Tests (2026-06-14): kanban-create full data + contract scaffold + refuse-overwrite PASS;
kanban-graph waves/infra/cycle/dangling PASS; dispatch reads NOT_STARTED issues, skips
worktree-set and IN_PROGRESS issues PASS. Real spawn (launches claude) not exercised;
arg path verified via --dry-run.

## Technical spec — the architect's primary deliverable (added 2026-06-14)

Gap found by user: the architect phase created issues but nothing captured the system
design they derive FROM. Added `templates/technical-spec.md` → architect writes
`knowledge/technical-spec.md` before decomposing. It is the single source of design truth.

Covers/captures (each section feeds a downstream artifact):
1. System overview · 2. Tech stack + decisions (→ AGENTS.md) · 3. Data model ·
4. Module decomposition (→ modules.json / AGENTS.md, [[backlinks]]) ·
5. Component/issue map (→ one kanban-create per row: feature/title/build/intent/success/links) ·
6. Interfaces + contracts (→ --depends-on; kanban-create scaffolds the contract stubs) ·
7. External infrastructure (→ --needs-infra → NEEDS_SETUP) ·
8. Build sequencing/milestones (→ --milestone/--depends-on; verified by kanban-graph) ·
9. Cross-cutting concerns · 10. Testing strategy (→ test_command / NEEDS_TESTING) ·
11. Non-goals · 12. Open questions/risks (→ KIV).

The PM's deliverable is `knowledge/user-flow.md` (the kanban UI serves it as the "PRD"
page). The technical spec is the architect's layer on top. Not yet surfaced in the UI —
a `/spec` route mirroring `/prd` is an easy follow-up.

CLAUDE.md spec phase rewritten: user-flow → edge-cases → **technical-spec** → AGENTS/modules
→ kanban-create issues → contracts → kanban-graph → kanban-dispatch.

## PM + Architect agent personas + roadmap skill (added 2026-06-18)

Grounded in the user's Notion (Condensed Wisdom + the PRD Agent / Technical Planning Agent
specs). The three-agent spec: PRD agent (product truth) → acceptance contracts (definition of
done) → technical planning agent (how + build map) → builders → adversarial validation gate.
Each a separate context (instruction budget + bias guard).

Created from the verbatim Notion prompts:
- `.claude/agents/prd-agent.md` — requirements agent, product altitude, stays non-technical.
  Writes `knowledge/prd/<feature>.md`, then hands off. tools: Read/Write/Edit/Glob/Grep. opus.
- `.claude/agents/technical-planning-agent.md` — features lead, architecture derived to fit.
  Per-feature plan → derive architecture → iface contracts + acceptance reachability → plan
  validation gate (rubric, self-harden + independent review) → invoke roadmap-and-branching.
  tools add Bash/Task/WebSearch/WebFetch; skills: roadmap-and-branching. opus.
- `skills/roadmap-and-branching/SKILL.md` — the planner's extra skill. Decomposes the validated
  plan by the contract-writable-seam test (separable→parallel tickets, coupled→sequenced),
  hydrates one self-sufficient ticket per atomic task via `kanban-create` (intent/build/success/
  testing/deps/infra/links all pulled from the plan — the one-and-done builder bar), verifies
  with `kanban-graph`, records `knowledge/build-plan.md`, then `kanban-dispatch` spawns branches.
- factory-init now installs ALL `skills/*` (was kanban-only). Agents are project-scoped in
  `.claude/agents/` (auto-discovered; run via `claude --agent <name>`).

Knowledge layout the specs introduce (richer than the monolithic technical-spec.md):
`knowledge/prd/<feature>.md`, `knowledge/contracts/acceptance/<feature>.md`,
`knowledge/spec/<feature>.md`, `knowledge/architecture.md`, `knowledge/contracts/iface/<seam>.md`,
`knowledge/platform/*.md`, `knowledge/build-plan.md`. All gitignored as runtime outputs.

OPEN RECONCILIATIONS (next session):
- `templates/technical-spec.md` (monolithic, added 2026-06-14) is superseded by the per-feature
  `knowledge/spec/<feature>.md` + `architecture.md` layout. Decide: keep as a thin overview or retire.
- `kanban-create` scaffolds flat `knowledge/contracts/<issue>-<dep>.md`; the planner writes
  `knowledge/contracts/iface/<seam>.md`. Align the paths (have the skill point --links at the real
  iface contracts, or move kanban-create's stub path under contracts/iface).
- AUTO-HANDOFF NOT WIRED. PM writes the PRD and stops; making it AUTOMATICALLY trigger the planner
  needs a trigger (PM Stop hook → tmux-delegate launches the planner). Both agents need user
  interaction (PM converses; planner's gate needs approval), so they run as sessions, not nested
  subagents. User will test manual handoff first; wire the auto-trigger next if wanted.

## Still TODO (next agent / next session)
- Wire the PM→planner auto-handoff trigger (above).
- Optional: add a `/spec` route to kanban-ui/server.js serving knowledge/technical-spec.md,
  mirroring the existing `/prd` route (serves user-flow.md).
- KIV 8: expose the dispatch KICKOFF as a standalone function an external agent calls
  (not baked into a phase), and put all tracker access behind an interface so Jira/Linear/
  GitHub-Issues adapters can replace the markdown backend. Data model above is the contract.
- Wire the phase agents: persistent `architect` tmux session; PM delegates via
  `tmux-delegate`; architect calls the kickoff function once `kanban-graph` is clean.
- Define the TESTING phase: who serves the app on the assigned port and who runs the test
  (tester agent vs user). Port allocation at NEEDS_TESTING is in place; the consumer is not.
- Resolve KIV 7 (agent↔feature mapping) before adding any liveness/crash detection.
