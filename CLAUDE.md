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
7. Fill HANDOFF-template.md for each issue ticket — include intent, success criteria, port, relevant modules, contracts
8. Assign ports from 3001 upward — one per parallel builder
9. Create all git worktrees upfront via spawn-builder.sh

**Coordination loop (reactive — no polling):**
- Git post-merge hook fires tmux send-keys into this session when a builder merges
- On BLOCKED_ON: surface to user, resolve, write resolution to the kanban file, ping builder
- On BUILT: read user-test card at `kanban/user-test-cards/` and present it to the user
- On user approval: call `kanban-done <issue> "<feedback>"` to close the ticket
- When all features approved: spawn sanity agent (Sonnet) in new tmux session

**Models:** coordinator = Opus | builders = Sonnet 4.5 | research subagents = Sonnet | sanity = Sonnet

## Software factory — builder rules

Builders run as `claude --dangerously-skip-permissions` in their own tmux session and git worktree.

**On start — read in this order:**
1. AGENTS.md — project knowledge base and module registry
2. modules.json — available reusable modules and their instantiation type
3. HANDOFF.md — the specific task, success criteria, port, intent
4. `knowledge/lessons.md` — learnings from prior builders on this project

**Before writing any code:** check modules.json for existing modules. Use them. Do not reimplement.

**During build:** update kanban status at every meaningful stage using `kanban-update <issue> <STATUS> <notes>`.

Status values:
- `IN_PROGRESS` — actively building
- `NEEDS_ACTION` — blocked on something outside the computer (user must create an account, grant access, provide a credential). State exactly what action is needed and who must do it.
- `BLOCKED_ON` — blocked on another issue's output. State the issue id and what you need from it.
- `BUILT` — done, tests pass, ready for user testing. Triggers test card generation automatically.

**Tests:** run tests using Playwright MCP or vercel/browser-agent against the live app before calling BUILT. Test your own issue only.

**On completion — before calling BUILT:**
- Fill `## What was built` — what the feature does from the user's perspective
- Fill `## How it works` — key implementation decisions, data flow, non-obvious choices
- Fill `## Tests run` — each passing test in `- [x]` format
- Fill `## Lessons learned` — non-obvious discoveries only: API shapes that differed from docs, env gotchas, workarounds. Skip anything obvious.
- Set `test_command:` in frontmatter — the shell command or URL that loads this feature's test state
- If you ran the same shell command more than twice, extract it to `scripts/<name>.sh` and add it to AGENTS.md under "Available scripts"
- Add any new reusable module to AGENTS.md and modules.json

Then call: `kanban-update <issue> BUILT "<summary>"`

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

All tests that produce an objective pass/fail result are run by the builder agent using Playwright MCP or vercel/browser-agent against the live app. Never delegated to a separate agent. Never run by the user. A feature is not BUILT until tests pass.

## User-testing breakpoints

Every user-facing feature gets a `[USER-TEST]` breakpoint. When execution reaches one, the coordinator presents a test card before continuing. The card has:
1. **SETUP** — shell commands to bring the app to the testable state
2. **WHAT TO DO** — short numbered walkthrough
3. **YOUR CALL** — open-ended prompts about how the feature feels, flows, and whether it delivers what was asked for. Not a checklist — a conversation.
4. **ALREADY VERIFIED BY BUILDER** — what automated tests already covered

Hold execution until the user replies.
