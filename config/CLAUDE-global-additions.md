## Software factory — coordinator rules

When a project has `factory.json` in its root, the Claude Code session that opens there is the coordinator. No other Claude Code instances run in the project root directory. Builders run in separate tmux sessions inside their own git worktrees.

**Pre-flight (run before spawning any builder):**
- Clarify what to build, which external services are needed, which credentials are required
- Ask whether the user wants a GitHub repo — optional, not required
- Detect project type: no ROADMAP.md → BMAD for greenfield, GSD new-milestone for existing

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
- On COMPLETE (user-facing feature): read user-test card at kanban/user-test-cards/ and present it
- On user approval: run git merge for that feature branch, post-merge hook fires automatically
- When all features approved: spawn sanity agent (Sonnet) in new tmux session

**Models:** coordinator = Opus | builders = Sonnet 4.5 | research subagents = Sonnet | sanity = Sonnet

## Software factory — builder rules

Builders run as `claude --dangerously-skip-permissions` in their own tmux session and git worktree.

**On start — read in this order:**
1. AGENTS.md — project knowledge base and module registry
2. modules.json — available reusable modules and their instantiation type
3. HANDOFF.md — the specific task, success criteria, port, intent

**Before writing any code:** check modules.json for existing modules. Use them. Do not reimplement.

**During build:** update kanban status at every meaningful stage using `kanban-update <issue> <STATUS> <notes>`.
Status values:
- `IN_PROGRESS` — actively building
- `NEEDS_ACTION` — blocked on something outside the computer (user must create an account, grant access, provide a credential, install hardware). State exactly what action is needed and who must do it.
- `BLOCKED_ON` — blocked on another issue's output. State the issue id and what you need from it.
- `COMPLETE` — done, tests pass

**Tests:** run tests using Playwright MCP or vercel/browser-agent against the live app before calling kanban-done. Test your own issue only.

**On completion:**
- Fill in kanban MD sections: what was built, how it works, tests run (- [x] format)
- Fill in `## Lessons learned` — non-obvious discoveries only: exact API shapes that differed from docs, surprising behaviours, env gotchas, workarounds. Skip obvious things.
- If you ran the same shell command more than twice during the build, extract it to `scripts/<name>.sh` in the project and add it to AGENTS.md under "Available scripts" with parameters documented.
- Add any new reusable module to AGENTS.md (with [[backlinks]]) and modules.json
- Call `kanban-done <issue> "plain summary"` — this extracts lessons, generates the user-test card, and pings coordinator

**Secrets:** never write a literal secret value anywhere. Use process.env.VARIABLE_NAME. Add values to .env.test only.
