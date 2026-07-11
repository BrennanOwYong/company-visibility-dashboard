# Software Factory — Claude Code config

This file is read automatically by Claude Code when opened in this directory.

**Entry behavior:** A default session onboards the user to `/hi`, which makes it the Product Manager (the PRD agent in `.claude/agents/`). After `/hi`, follow the PM role; it hands off to the technical planner via `handoff-to-planner`. Sessions launched with `--agent <name>` run as that agent. The coordinator/kanban rules below are the factory's internal reference for how the pipeline works — not instructions for the opening session to act on before `/hi`.

**Pipeline map:** PIPELINE.md holds the full flow diagram, the handoff-type legend, the verified producer/consumer joint table, and per-agent test procedures. Read it before changing any handoff.

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
   kanban-create <issue> --feature <name> --repo <product-repo> --title "<what to build>" --milestone <N> \
     --intent "..." --build "..." --success "..." --testing "..." \
     --depends-on <iss-a,iss-b> --needs-infra "Stripe account, OPENAI_API_KEY" --links "[[module]],[[iss]]"
   ```
   `--repo` points at the PRODUCT's own git repo (convention: `<project>/product`, git-initialized before dispatch) — never the factory tree; spawn-builder refuses the factory root.
   `--depends-on` = other issues this waits on (spec §6). `--needs-infra` = external infra the user must set up (spec §7; each surfaces as NEEDS_SETUP). `--milestone` + deps express what to build and when (spec §8). Status starts NOT_STARTED; a port is allocated when the ticket's validator boots (kanban-port).
6. kanban-create scaffolds an empty contract stub per dependency edge at `knowledge/contracts/<issue>-<dep>.md`. Fill each from spec §6 with the exact shape the dependency produces (endpoint path, request/response schema, event signature, data model). This is the interface spec the dependent's builder reads; because a dependent starts only after its dependency is DONE and merged, it builds against the real implementation, not a mock.
7. Run `kanban-graph` to verify the roadmap: no cycles, no dangling deps, and review the build waves (what is parallel, what waits) and the external-infra rollup against spec §8.
8. Dispatch builders via `kanban-dispatch` (calls spawn-builder.sh once per READY issue, creating each git worktree). Ready = every dependency edge DONE or its edge contract filled; an unfilled stub keeps the ticket waiting for its dependency to merge. One builder per ready independent branch, under the MAX_BUILDERS rate-limit ceiling. spawn-builder uses the issue you created — it does not overwrite it.

**Coordination loop (reactive — no polling):**
- Git post-merge hook pings this session when a ticket integrates; the kanban re-dispatches whatever became ready (deps now DONE).
- On NEEDS_SETUP: surface to the user the exact thing the builder needs (a login/account/key), resolve it, write the resolution to the kanban file, ping the builder.
- On NEEDS_USER_TESTING: validation already passed (RUNNING_TESTS → VALIDATED) — the ticket is waiting on the board's Test button. Point the user at the board; only taste is being judged. `needs_user_test:false` tickets never reach here (they auto-integrate).
- On user "all clear": `kanban-done <issue> "<feedback>"` closes and integrates the ticket. On reported issues: route to the PM agent to decide same-ticket fix vs new tickets.
- When all features are DONE: spawn the sanity agent (Sonnet) in a new tmux session.

**Models:** coordinator = Opus | builders = Sonnet 4.5 | research subagents = Sonnet | validator = Sonnet | sanity = Sonnet

## Software factory — builder rules

Builders run as `claude --dangerously-skip-permissions` in their own tmux session and git worktree.

**On start — read in this order:**
1. AGENTS.md — project knowledge base and module registry
2. modules.json — available reusable modules and their instantiation type
3. HANDOFF.md — briefing copy of your ticket. Its frontmatter is a typed link index: intent, build, success_criteria, testing, feasibility, and architecture each hold ONE link path to that section's canonical doc. Read the docs behind build and success_criteria always (they are required); a blank critical field means the ticket is missing that section — flag it. target_type declares how the build is run and tested (web, extension, cli, service, library).
4. `knowledge/lessons.md` — learnings from prior builders on this project
5. Every doc under the ticket's `## Additional references` (interface/research/module bullets) — the planner already researched your stack (exact APIs, gotchas, doc links); read its findings instead of re-researching

**Before writing any code:** check modules.json for existing modules. Use them. Do not reimplement.

**Infra is your job:** set up what your build needs yourself — create the local service, wire the integration, install and run the tool. NEEDS_SETUP is the LAST resort, reserved for a credential, account, or access that only the human holds; a tool that fights you is a problem to solve, not a reason to stop.

**During build:** update kanban status at every meaningful stage using `kanban-update <issue> <STATUS> <notes>`.

Status values (canonical, in pipeline order). You are your ticket's single persistent builder — you keep your context for the ticket's whole life, including every re-validation round:
- `NOT_STARTED` — ticket created; its dependencies are not all DONE yet.
- `IN_PROGRESS` — you are building and self-testing, against your dependencies' REAL merged code (not mocks).
- `NEEDS_SETUP` — blocked on something only the human can provide: a credential, an account, an access grant. You have already tried to set it up yourself. Always include remarks stating exactly what you need and who can provide it.
- `RUNNING_TESTS` — you are done building, filled the completion sections, set `test_command`, and committed. You set this; **the KANBAN then spawns your validator** — you do NOT spawn it. When the validator queues `VALIDATION-FAILED`, fix the defects and set `RUNNING_TESTS` again to re-trigger it. On a passing verdict the kanban routes the ticket onward and you are done.
- `NEEDS_USER_TESTING` — validation passed and the ticket needs a human's taste; the kanban sets this (only for `needs_user_test:true` tickets). Not yours to set.
- `DONE` — integrated onto main (kanban / kanban-done sets it).

Dependencies are already built and merged into your branch's base — build against the real code and run it end to end. There is no cross-issue blocked state.

**Contested verdicts:** you never negotiate with the validator and it never negotiates with you. If a defect verdict misreads the contract, route the dispute to the planner, who owns the spec: `spawn-agent technical-planning-agent "CONTESTED-VERDICT: <issue> — assertion <n>, <why the verdict misreads the contract>"`. After three failed rounds on the same assertion the validator escalates to the human; do not grind a fourth.

A port is allocated the moment your validator boots (the kanban's RUNNING_TESTS reaction runs kanban-port) — read it from your ticket's frontmatter and serve the app there. Until then, no port is reserved.

**UX baseline (every user-facing surface, no exceptions):** the architecture provides these once; use its provision, do not reinvent or skip:
- A loading/skeleton state for every async operation; no dead screens while data fetches
- Empty and error states designed, not defaulted
- No hydration flash, no layout shift when data arrives
- Caching per the architecture's stated strategy; repeat visits must not refetch what is fresh
- Optimistic updates where the architecture marks them safe
- Perceived speed is a requirement: first paint and first interaction inside the architecture's budget

**Quality SOP (shift-left — these are BUILD activities, not a later audit):** while building, not after: performance (no N+1 patterns, no unbounded queries/loops, respect the architecture's perceived-speed budget), code quality (typed seams with no `any`, unique greppable names, no dead code, conventional patterns over clever ones), security (validate every input at the boundary, parameterized queries only, secrets via env only, no exposed debug surfaces, idempotent webhook ingress), and UX best practices (the UX baseline below). The validator re-checks what is objectively assertable; anything you skipped here is your defect when it does.

**Tests:** run browser tests using agent-browser against the live app before calling RUNNING_TESTS. Test your own issue only. Everything an LLM can verify is YOUR job during the build: functional flows, edge cases, empty/error states, the acceptance assertions in `--success`, and the UX baseline above (throttle the network to see the loading states; reload to verify cache hits; watch for layout shift). The user is only ever asked for taste — feel, flow, visual coherence, perceived speed. An objectively checkable item that reaches the user's Test step is your defect.

Install if missing: `npm install -g agent-browser && agent-browser install`

agent-browser workflow:
1. `agent-browser snapshot` — get accessibility tree with element refs (@e1, @e2, …)
2. `agent-browser click @e1` / `agent-browser fill @e3 "value"` — interact
3. `agent-browser screenshot` — capture state
4. Re-snapshot after each interaction to verify the result

**On completion — before calling RUNNING_TESTS:**
- ALL completion writes go into the CANONICAL ticket at `$KANBAN_PROJECT_ROOT/kanban/<issue>.md` — HANDOFF.md in your worktree is a read-only briefing copy; nothing downstream reads it (kanban-update refuses RUNNING_TESTS while the canonical file holds placeholders)
- Commit everything on your `feat/<issue>` branch — code, scripts, all of it (kanban-update refuses RUNNING_TESTS while the worktree is dirty; an uncommitted build is lost when the worktree is pruned). Merging to main happens after the ticket is validated (and, for user-test tickets, approved) — not now.
- Fill `## What was built` — what the feature does from the user's perspective
- Fill `## How it works` — key implementation decisions, data flow, non-obvious choices
- Fill `## Tests run` — each passing test in `- [x]` format
- Fill `## Lessons learned` — non-obvious discoveries only: API shapes that differed from docs, env gotchas, workarounds. Skip anything obvious.
- Set `test_command:` in frontmatter — the shell command or URL that loads this feature's test state
- If you ran the same shell command more than twice, extract it to `scripts/<name>.sh` and add it to AGENTS.md under "Available scripts"
- Add any new reusable module to AGENTS.md and modules.json

Then call: `kanban-update <issue> RUNNING_TESTS "<summary>"` — the kanban spawns your validator. Stay in the session; fix any `VALIDATION-FAILED` and set `RUNNING_TESTS` again to re-trigger it.

Do NOT call `kanban-done` and do NOT set NEEDS_USER_TESTING or DONE — the kanban and coordinator own those.

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

## Automated testing — two layers, maker is never the tester

Layer 1, the builder: every objective test it can express (functional, edge cases, states, UX baseline) runs during the build against the live app. A build is not ready for RUNNING_TESTS until the builder's own tests pass. These prove the builder's interpretation.

Layer 2, the validator: on RUNNING_TESTS the kanban spawns the ticket's OWN persistent `validator-agent` (fresh context, session `val-<issue>`). It authors its OWN tests from the ticket's success criteria and the acceptance contract — before looking at the builder's tests — and runs them on the real running system. It writes `kanban/validation/<issue>.md` with per-assertion verdicts; every failure is classified `builder-defect` (queued back to the builder session, which fixes and re-triggers RUNNING_TESTS), `test-defect` (its own test was wrong; corrected and recorded), `ticket-underspecified` (routed to the planner as TICKET-GAP), or `external` (out of our control → NEEDS_SETUP with exactly what is needed). On a passing verdict it runs `kanban-update <issue> VALIDATED`, and the kanban routes onward. The user is reached only after validation passes, and only for taste.

## User-testing breakpoints

A `needs_user_test:true` ticket, once validated, waits at NEEDS_USER_TESTING for the human. The board's **Test** button sets up that ticket's whole environment — checks out its branch, runs its startup scripts, injects creds, lands the user on the right page — so the user only clicks one thing, then judges taste. A prep/explainer page shows what they're about to test and how it relates to the product, reassures them the technology is already validated, and offers Skip. The user's feedback ("all clear" or specific issues) is the only human input; issues route to the PM agent to decide same-ticket fix vs new tickets. Backend (`needs_user_test:false`) tickets never surface to the user.
