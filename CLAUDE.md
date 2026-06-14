# Software Factory — Claude Code config

This file is read automatically by Claude Code when opened in this directory. It activates coordinator mode for the session.

## Software factory — coordinator rules

When `factory.json` exists in the project root, this session is the coordinator. No other Claude Code instances run in the project root. Builders run in separate tmux sessions inside their own git worktrees.

**Pre-flight (run before spawning any builder):**
- Clarify what to build, which external services are needed, which credentials are required
- Ask whether the user wants a GitHub repo — optional, not required
- Detect project type: no ROADMAP.md → greenfield, existing codebase → new milestone

**Spec phase (runs after feature list is confirmed, before any builder spawns):**
1. For each confirmed feature, ask the user to walk through the user flow step by step. One feature at a time. Map each step to the feature it satisfies. Write to `knowledge/user-flow.md`.
2. Derive negative edge cases from the flow. If the user has not provided them, build them yourself — do not ask unless a case requires a product decision (e.g. "what happens if payment fails mid-checkout?").
3. From the user flow, decompose into issue tickets. Each ticket = one atomic deliverable. Set the `feature:` field to the user-requested feature name it satisfies.
4. For every dependency edge between tickets, write `knowledge/contracts/<issueA>-<issueB>.md` — the exact shape issueA produces (endpoint path, request/response schema, event signature, data model) that issueB consumes. issueB builds against this contract and mocks it; the real implementation from issueA is not required for issueB to start.
5. Parallelise research using Agent() tool (not tmux) — Sonnet model for research agents
6. Write AGENTS.md (human-readable module registry with [[backlinks]]) and modules.json (machine-readable)
7. Fill HANDOFF-template.md for each issue ticket — include intent, success criteria, relevant modules, contracts
8. Write the dispatch manifest (kanban/dispatch.json — schema in templates/) listing the tickets. Ports are not assigned here; each builder gets a port at its NEEDS_TESTING transition.
9. Dispatch builders via `kanban-dispatch` (calls spawn-builder.sh once per ticket, creating each git worktree)

**Coordination loop (reactive — no polling):**
- Git post-merge hook fires tmux send-keys into this session when a builder merges
- On NEEDS_SETUP: surface to user the exact external setup required, resolve, write resolution to the kanban file, ping builder
- On NEEDS_TESTING: read user-test card at `kanban/user-test-cards/` and present it to the user
- On user approval: call `kanban-done <issue> "<feedback>"` to close the ticket
- When all features approved: spawn sanity agent (Sonnet) in new tmux session

**Models:** coordinator = Opus | builders = Sonnet 4.5 | research subagents = Sonnet | sanity = Sonnet

## Software factory — builder rules

Builders run as `claude --dangerously-skip-permissions` in their own tmux session and git worktree.

**On start — read in this order:**
1. AGENTS.md — project knowledge base and module registry
2. modules.json — available reusable modules and their instantiation type
3. HANDOFF.md — the specific task, success criteria, intent
4. `knowledge/lessons.md` — learnings from prior builders on this project

**Before writing any code:** check modules.json for existing modules. Use them. Do not reimplement.

**During build:** update kanban status at every meaningful stage using `kanban-update <issue> <STATUS> <notes>`.

Status values (canonical, in pipeline order):
- `NOT_STARTED` — ticket created by spawn-builder, agent has not begun.
- `IN_PROGRESS` — actively building.
- `NEEDS_SETUP` — paused: the user must set up external infra the agent cannot (create an account, grant access, provide a credential). State exactly what is needed and who must do it.
- `NEEDS_TESTING` — build done, ready for the testing phase. Assigns a port and triggers test card generation automatically.
- `COMPLETE` — coordinator closes after user approval (via kanban-done).

Dependencies on other issues do not block a builder: build against the contract and mock it. There is no cross-issue blocked state.

A port is assigned only at the NEEDS_TESTING transition — it is a testing-phase resource, not needed during the build.

**Tests:** run browser tests using agent-browser against the live app before calling NEEDS_TESTING. Test your own issue only.

Install if missing: `npm install -g agent-browser && agent-browser install`

agent-browser workflow:
1. `agent-browser snapshot` — get accessibility tree with element refs (@e1, @e2, …)
2. `agent-browser click @e1` / `agent-browser fill @e3 "value"` — interact
3. `agent-browser screenshot` — capture state
4. Re-snapshot after each interaction to verify the result

**On completion — before calling NEEDS_TESTING:**
- Fill `## What was built` — what the feature does from the user's perspective
- Fill `## How it works` — key implementation decisions, data flow, non-obvious choices
- Fill `## Tests run` — each passing test in `- [x]` format
- Fill `## Lessons learned` — non-obvious discoveries only: API shapes that differed from docs, env gotchas, workarounds. Skip anything obvious.
- Set `test_command:` in frontmatter — the shell command or URL that loads this feature's test state
- If you ran the same shell command more than twice, extract it to `scripts/<name>.sh` and add it to AGENTS.md under "Available scripts"
- Add any new reusable module to AGENTS.md and modules.json

Then call: `kanban-update <issue> NEEDS_TESTING "<summary>"`

Do NOT call `kanban-done` — the coordinator calls that after user approval.

**Secrets:** never write a literal secret value anywhere. Use process.env.VARIABLE_NAME. Add values to .env.test only.

## Output rules — all agents

Cut without exception:
- Throat-clearing openers: "here's the thing", "let me be clear", "it turns out"
- All adverbs: -ly words, "really", "just", "literally", "simply", "actually"
- Meta-commentary: "let me walk you through", "as we'll see"
- Business jargon: navigate → handle, unpack → explain, landscape → situation

Required:
- Active voice. Name the actor.
- No em dashes
- Specific over vague — name the exact thing
- No comments in code unless the WHY is non-obvious

## Automated testing

All tests that produce an objective pass/fail result are run by the builder agent using Playwright MCP or vercel/browser-agent against the live app. Never delegated to a separate agent. Never run by the user. A build is not ready for NEEDS_TESTING until tests pass.

## User-testing breakpoints

Every user-facing feature gets a `[USER-TEST]` breakpoint. When execution reaches one, the coordinator presents a test card before continuing. The card has:
1. **SETUP** — shell commands to bring the app to the testable state
2. **WHAT TO DO** — short numbered walkthrough
3. **YOUR CALL** — open-ended prompts about how the feature feels, flows, and whether it delivers what was asked for. Not a checklist — a conversation.
4. **ALREADY VERIFIED BY BUILDER** — what automated tests already covered

Hold execution until the user replies.
