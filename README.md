# software_factory_cc

This is your project-specific Claude Code config. Clone it, drop it into your project folder, and run the installer. It turns Claude Code into a coordinator that plans work, spawns parallel builder agents, and tracks everything through a file-based kanban board.

## How to use this

Clone this repo into your project directory (or anywhere on the machine — it installs into `~/.claude`):

```bash
git clone https://github.com/BrennanOwYong/software_factory_cc.git
cd software_factory_cc
bash install.sh
```

Then follow the 5 manual steps the installer prints. After that, open Claude Code in any project folder that has a `factory.json` file and the factory activates automatically.

## What it does

The coordinator session (Claude Opus) asks you what you want to build, walks through the feature list with you, writes a spec, decomposes it into issue tickets, and spawns builder agents (Claude Sonnet) as parallel tmux sessions. Each builder works in its own git worktree. When a builder finishes, it pings the coordinator with a test card. You review it, give feedback, and the coordinator closes the ticket.

## Prerequisites

- **tmux** — manages builder sessions
  - Ubuntu/Debian: `sudo apt install tmux`
  - macOS: `brew install tmux`
  - Verify: `tmux -V`
- **Node.js 18+** — runs the kanban UI
- **Claude Code CLI** — installed and authenticated
- **WSL2 or Linux** — Windows native not supported

## Install

```bash
bash install.sh
```

Manual steps after install:
1. Add `factory-init.sh` as a `SessionStart` hook in `~/.claude/settings.json` (see `config/settings-patch.json`)
2. Append `config/CLAUDE-global-additions.md` to `~/.claude/CLAUDE.md`
3. Append `config/CLAUDE-project-additions.md` to your project's `CLAUDE.md`
4. Create `factory.json` in your project root (see `config/factory.json.example`)
5. Run `source ~/.bashrc`

## Starting a project

1. Put `factory.json` in your project root — this marks it as a factory project.
2. Open Claude Code in that directory — the coordinator activates automatically.
3. Tell it what you want to build. It will ask about features and user flows before writing any code.
4. Builders run in parallel. Watch progress with `kanban-check` or open the kanban UI.

## Kanban UI

Reads `kanban/*.md` in the project root and serves a board at `http://localhost:2999`. Shows tickets by status, which feature each ticket belongs to, the test card for BUILT tickets, and a Launch Test button that fires the builder's `test_command`.

```bash
KANBAN_PROJECT_ROOT=/path/to/your/project node kanban-ui/server.js
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
