# Software Factory — Claude Code config

This file is read automatically by Claude Code when opened in this directory.

**Entry behavior:** A default session onboards the user to `/hi`, which makes it the Product Manager (the PRD agent in `.claude/agents/`). After `/hi`, follow the PM role; it hands off to the technical planner via `handoff-to-planner`. Sessions launched with `--agent <name>` run as that agent. The coordinator/kanban rules below are the factory's internal reference for how the pipeline works — not instructions for the opening session to act on before `/hi`.

## Software factory — coordinator rules

When `factory.json` exists in the project root, this session is the coordinator. No other Claude Code instances run in the project root. Builders run in separate tmux sessions inside their own git worktrees.

**Pre-flight (run before spawning any builder):**
- Clarify what to build, which external services are needed, which credentials are required
- Ask whether the user wants a GitHub repo — optional, not required
- Detect project type: no ROADMAP.md → greenfield, existing codebase → new milestone

**Spec phase (runs after feature list is confirmed, before any builder spawns):**
1. For each confirmed feature, ask the user to walk through the user flow step by step. One feature at a time. Map each step to the feature it satisfies. Write to `knowledge/user-flow.md`.
2. Derive negative edge cases from the flow. If the user has not provided them, build them yourself — do not ask unless a case requires a product decision (e.g. "what happens if payment fails mid-checkout?").
3. Write the technical spec at `knowledge/technical-spec.md` (template in templates/). This is the architect's primary deliverable and the single source of design truth — everything below is derived from it. It captures: system overview, tech stack + decisions, data model, module decomposition, the component/issue map, interfaces + contracts, external infrastructure, build sequencing/milestones, cross-cutting concerns, testing strategy, non-goals, open questions. Parallelise research (Agent() tool, Sonnet) to inform its decisions.
4. Extract the module registry from the spec: AGENTS.md (human-readable, [[backlinks]]) and modules.json (machine-readable).
5. Decompose the spec's component/issue map into atomic issues, creating each with `kanban-create`. Every field comes straight from the spec — there is no separate handoff to author:
   ```
   kanban-create <issue> --feature <name> --title "<what to build>" --milestone <N> \
     --intent "..." --build "..." --success "..." --testing "..." \
     --depends-on <iss-a,iss-b> --needs-infra "Stripe account, OPENAI_API_KEY" --links "[[module]],[[iss]]"
   ```
   `--depends-on` = other issues this waits on (spec §6). `--needs-infra` = external infra the user must set up (spec §7; each surfaces as NEEDS_SETUP). `--milestone` + deps express what to build and when (spec §8). Status starts NOT_STARTED; no port is assigned until NEEDS_TESTING.
6. kanban-create scaffolds an empty contract stub per dependency edge at `knowledge/contracts/<issue>-<dep>.md`. Fill each from spec §6 with the exact shape the dependency produces (endpoint path, request/response schema, event signature, data model). The dependent issue builds against it and mocks it; the real implementation is not required to start.
7. Run `kanban-graph` to verify the roadmap: no cycles, no dangling deps, and review the build waves (what is parallel, what waits) and the external-infra rollup against spec §8.
8. Dispatch builders via `kanban-dispatch` (calls spawn-builder.sh once per issue, creating each git worktree). spawn-builder uses the issue you created — it does not overwrite it. Each builder gets a port at its NEEDS_TESTING transition.

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
