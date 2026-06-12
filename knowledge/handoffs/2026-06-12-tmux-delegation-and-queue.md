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

## Still TODO (next agent / next session)
- Wire the actual phase agents: spawn a persistent `architect` tmux session and have the PM
  delegate to it via `tmux-delegate`; on the architect's deliverable, trigger kanban dispatch.
- Decide the PM->Architect trigger (PM does it on requirements sign-off) and the
  Architect->kanban trigger (deliverable-exists check, e.g. a Stop-hook gate or kanban script).
- Update CLAUDE.md coordinator rules to describe the PM/Architect/kanban phase model and to
  mandate `tmux-delegate` for every delegation (ban raw send-keys).
