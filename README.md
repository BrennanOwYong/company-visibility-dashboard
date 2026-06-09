# software_factory_cc

A coordination harness for Claude Code that runs a main coordinator session managing parallel builder agents in isolated git worktrees. Builders report progress via a file-based kanban board. A kanban UI server visualises ticket state and lets you launch test environments from the browser.

## What this is

The coordinator (Claude Opus) plans work, decomposes features into issue tickets, writes handoff specs, and spawns builder agents (Claude Sonnet) in tmux sessions. Each builder works in its own git worktree and reports status via the kanban scripts. Git post-merge hooks ping the coordinator when a build completes. The coordinator reviews the test card and calls kanban-done to close the ticket.

## Prerequisites

- **tmux** — required for builder session management
  - Ubuntu/Debian: `sudo apt install tmux`
  - macOS: `brew install tmux`
  - Verify: `tmux -V`
- **Node.js 18+** — required for kanban-ui and telemetry scripts
- **Claude Code CLI** — installed and authenticated
- **WSL2 or Linux** — Windows native not supported

## Install

```bash
git clone https://github.com/BrennanOwYong/software_factory_cc.git
cd software_factory_cc
bash install.sh
```

Then follow the 5 manual steps printed by the installer:
1. Add `factory-init.sh` as a `SessionStart` hook in `~/.claude/settings.json` (see `config/settings-patch.json`)
2. Append `config/CLAUDE-global-additions.md` to `~/.claude/CLAUDE.md`
3. Append `config/CLAUDE-project-additions.md` to your project's `CLAUDE.md`
4. Create `factory.json` in your project root (see `config/factory.json.example`)
5. Run `source ~/.bashrc`

## Usage

1. Create `factory.json` in your project root (marks it as a factory project).
2. Open Claude Code in that directory — the coordinator session activates automatically.
3. Tell the coordinator what features you want. It will ask clarifying questions, build the spec, and spawn builders.
4. Builders run in parallel tmux sessions. Watch progress with `kanban-check`.
5. When a builder finishes, the coordinator pings you with a test card. Run the kanban UI to review it.

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
