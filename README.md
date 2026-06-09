# software_factory_cc

Clone this repo. Open Claude Code inside it. The factory starts automatically — no install step, no config.

```bash
git clone https://github.com/BrennanOwYong/software_factory_cc.git my-project
cd my-project
claude .
```

## Prerequisites

**tmux** is required. Builders run as parallel tmux sessions.

Check if installed:
```bash
which tmux        # prints path if installed
tmux -V           # prints version
```

Install if missing:
```bash
# Ubuntu / Debian / WSL
sudo apt install tmux

# macOS
brew install tmux
```

Check if your current terminal is already inside a tmux session:
```bash
echo $TMUX        # non-empty = you're in tmux, empty = you're not
```

You do **not** need to be inside a tmux session yourself. Any terminal on a machine that has tmux installed can spawn tmux sessions. The factory spawns builders into tmux regardless of whether your own shell is in one.

Other requirements:
- **Node.js 18+** — for the kanban UI
- **Claude Code CLI** — installed and authenticated
- **WSL2 or Linux** — Windows native not supported

## What it does

The coordinator (Claude Opus) asks what you want to build, walks through each feature's user flow with you, writes a spec and contracts, then spawns parallel builder agents (Claude Sonnet) as tmux sessions. Each builder works in an isolated git worktree. When a builder finishes and tests pass, it generates a test card and pings the coordinator. You review it, give feedback, and the coordinator closes the ticket.

## How it activates

`CLAUDE.md` and `.claude/settings.json` in this repo root are picked up automatically by Claude Code. On session start, `bin/factory-init.sh` runs and detects `factory.json` — that's what puts the session into coordinator mode. Edit `factory.json` to point at your repos.

## Kanban UI

```bash
KANBAN_PROJECT_ROOT=$(pwd) node kanban-ui/server.js
```

Opens at `http://localhost:2999`. Shows all tickets by status, the feature each belongs to, test card content for BUILT tickets, and a Launch Test button. The PRD (product requirements) page is linked from the header.

## Kanban scripts

Scripts live in `bin/`. They are added to your PATH automatically on first session start.

| Script | Who calls it | What it does |
|---|---|---|
| `kanban-update <issue> <status> [notes]` | Builder | Updates ticket status; BUILT triggers test card |
| `kanban-check` | Anyone | Prints board state to terminal |
| `kanban-done <issue> <feedback>` | Coordinator | Writes after-action report, marks COMPLETE |
| `kanban-generate-card <issue>` | Auto on BUILT | Writes user test card |
| `kanban-resolved <issue>` | Coordinator | Unblocks a BLOCKED_ON ticket |
| `kanban-perf` | Anyone | Timing report from telemetry |
| `spawn-builder.sh` | Coordinator | Creates worktree + kanban entry + tmux session |
| `factory-init.sh` | SessionStart hook | Registers coordinator, installs post-merge hooks |

## Ticket lifecycle

```
spawn-builder  →  IN_PROGRESS
builder works  →  kanban-update IN_PROGRESS / NEEDS_ACTION / BLOCKED_ON
tests pass     →  kanban-update BUILT  (test card generated, coordinator pinged)
user approves  →  kanban-done  (after-action report written, ticket COMPLETE)
```

## File layout

```
my-project/
  CLAUDE.md               ← coordinator + builder rules (this repo)
  .claude/settings.json   ← SessionStart hook (this repo)
  factory.json            ← edit this: point at your repos
  bin/                    ← all scripts (added to PATH on first run)
  kanban-ui/              ← kanban board server
  skills/kanban/          ← kanban skill, copied to ~/.claude/skills/ on first run
  kanban/                 ← created on first run
    <issue>.md
    user-test-cards/
    aar/
    telemetry.jsonl
  knowledge/              ← created on first run
    user-flow.md
    lessons.md
    contracts/
```

## Kanban UI

Reads `kanban/*.md` in the project root and serves a status board at `http://localhost:2999`.

```bash
KANBAN_PROJECT_ROOT=/path/to/your/project node kanban-ui/server.js
```

The UI shows tickets by status, the feature each ticket belongs to, test card content for BUILT tickets, and a Launch Test button that runs the builder's `test_command` in the background.

## Kanban scripts

All scripts live in `~/.claude/bin/` after install. Builders invoke them via the kanban skill (`Skill({skill:"kanban"})`).

| Script | Who calls it | What it does |
|---|---|---|
| `kanban-update <issue> <status> [notes]` | Builder | Updates ticket status; BUILT triggers test card generation |
| `kanban-check` | Anyone | Renders current board state in the terminal |
| `kanban-done <issue> <feedback>` | Coordinator | Writes after-action report, extracts lessons, marks COMPLETE |
| `kanban-generate-card <issue>` | Auto (on BUILT) | Writes user test card to `kanban/user-test-cards/` |
| `kanban-resolved <issue>` | Coordinator | Unblocks a BLOCKED_ON ticket and pings the builder |
| `kanban-perf` | Anyone | Timing report from telemetry |
| `kanban-eval` | Anyone | Quality report |
| `spawn-builder.sh` | Coordinator | Creates worktree + kanban entry + tmux session |
| `factory-init.sh` | SessionStart hook | Registers coordinator session, installs post-merge hooks |

## Ticket lifecycle

```
spawn-builder → IN_PROGRESS
builder works → kanban-update IN_PROGRESS / NEEDS_ACTION / BLOCKED_ON
tests pass    → kanban-update BUILT  (auto-generates test card, pings coordinator)
user approves → kanban-done  (writes after-action report, marks COMPLETE)
```

## File layout (per project)

```
project-root/
  factory.json              # activates factory mode
  kanban/
    <issue>.md              # one ticket per issue
    user-test-cards/        # generated test cards
    aar/                    # after-action reports
    telemetry.jsonl         # event log for kanban-perf
  knowledge/
    user-flow.md            # written during spec phase
    lessons.md              # extracted builder learnings
    contracts/              # interface contracts between issues
```
