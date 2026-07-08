# Factory pipeline — information flow, handoffs, and joint contracts

Every joint below was verified against the actual scripts and prompts on 2026-07-03
(see the joint table). `scripts/smoke-test.sh` exercises the deterministic layer end to end.

## Legend

```
══▶   deterministic script handoff — bash, gated, logged to kanban/agent-events.jsonl
──▶   async agent message — spawn-agent / tmux-delegate inbox; delivered only when the
      target session is idle (inbox-drain), so nothing lands mid-turn
··▶   file artifact — producer writes to disk, consumer reads from disk; survives any crash
◀═▶   human conversation — the only points where a person is in the loop
[G]   programmatic gate — code decides pass/refuse; the LLM only judges content quality
(H)   hook-fired — git/harness fires it; no agent has to notice or remember
 ▒    durable state write — knowledge/pipeline.json / kanban/*.md / agent-events.jsonl;
      every agent resumes from this, never from session memory
```

## The pipeline

```
 ENTRY   default session + /hi  →  becomes PM (prd-agent)        alt: bin/spawn-agent prd-agent

 ═══════════ PHASE 1 · CAPTURE ∥ SELECTIVE FEASIBILITY (concurrent, batched) ═══════════

   USER ◀═▶ PM (prd-agent)                                TECHNICAL PLANNER (feasibility mode)
        EVERY user message = product info: PM updates
        the single PRD BEFORE replying, every turn
             │
             ├─··▶ knowledge/prd/product.md   THE one PRD: problem, feature index table,
             │       one section per feature (flow walk + mermaid, requirements,
             │       non-goals), feasibility ledger, open questions, decisions
             │
        flow of feature N confirmed  ▒ flow_confirmed
             ├─··▶ knowledge/contracts/acceptance/N.md
             │
             ├─ GATE JUDGMENT (context-aware, not a checklist): does anything in N
             │  depend on the outside world to be buildable at all? PM reasons over
             │  the ledger + prior verdicts' recorded assumptions first — a slight
             │  change to an approved feature, or a question an old verdict already
             │  answers, never re-dispatches
             │
             ├─ nothing gate-worthy ▒ feasibility_waived (reasoning in ledger);
             │                        decisions (flows, rules, copy) are always buildable
             │
             ├─ uncertain items → ONE batched check per feature ▒ feasibility_pending
             │    ──"FEASIBILITY-CHECK: N — items: 1..k"──▶ inbox queue (FIFO, serialized)
             ▼ does NOT wait                               │
   USER ◀═▶ PM interviews feature N+1                      │ SINGLE PASS · reason feature N
             ▲                                             │ all the way to a verdict, then
             │                                             │ report ONCE (no provisional
             │                                             │ reads, no self-queued stages):
             │                                             │ ATTEMPT the spec — blocked is
             │                                             │ only ever "no spec works":
             │                                             ├─··▶ knowledge/spec/N.md (draft)
             │                                             │   seams named early → cheap
             │                                             │   contracts later
             │                                             ├─··▶ knowledge/technical/research/<tech>.md
             │                                             │   one file per technology, official
             │                                             │   doc links; verdicts cite these
             │   replies land only when PM is idle,        ├─··▶ knowledge/technical/feasibility/N.md
             │   never mid-conversation (inbox-drain)      ▒ ok | workaround | blocked
             ├◀── "FEASIBILITY-RESULT: N — …, Assumptions:"┤
             ├◀── "FEASIBILITY: N — blocked + alternatives"┘
             │   PM records verdict + assumptions in its LEDGER (product.md) — its only
             │   feasibility store; it never reads the planner's files (hook-enforced)
             │       escalation is at the PM's behest: reshape at product altitude,
   USER ◀═▶ PM       park as open question, or raise with the user — PM's call;
             │       ledger + index updated either way
             ▼ user done: PM sweeps pending verdicts, walks USER through the
               feature index to confirm coverage, hands off

 ══════════════════════════ GATE · bin/handoff-to-planner ══════════════════════════
   [G] prd-check: product.md contains every registered slug + per feature {acceptance,
       stage ∈ ok|workaround|waived, verdict file if checked} → REFUSE with gaps | pass
   pass ══▶ ▒ every feature marked handed_off ══▶ spawn planner + kickoff message


 ═══════ PHASE 2 · COHERENCE PASS (planner, full-plan mode, ALL features together —
         a small reconciliation when the drafts are good, not a from-scratch operation) ═══════
   reads product.md (final), acceptance/*, feasibility/* (own verdicts = binding constraints),
         its own draft specs, platform/*, AGENTS.md, modules.json, lessons.md
             ├─··▶ knowledge/spec/N.md    refresh draft → final against the final PRD;
             │                            written fresh ONLY for waived features
             ├─··▶ knowledge/architecture.md   smallest shared architecture, ~200 lines, ADRs,
             │                            + UX baseline provided once (loading/skeleton,
             │                            no hydration flash, caching strategy, optimistic
             │                            updates, perceived-speed budget)
             ├─··▶ knowledge/contracts/iface/<seam>.md   marked contract-covered | coupled
             │                            (cheap: every seam was named in the drafts)
   [G] fresh-context verifier subagent — adversarial, rubric ≥ 90, no line at zero,
       ≤ 3 rounds then escalate to PM. The maker never grades its own plan.


 ═══════ PHASE 3 · ROADMAP & DISPATCH (planner-owned: it wrote the seams, it decides the
         waves; roadmap-and-branching skill = its procedure, pure emit, no new design) ═══════
             │ decompose into atomic vertical slices (contract-writable-seam test)
             ├══▶ kanban-create <iss> --feature --title --intent --build --success --testing
             │        --depends-on --needs-infra --links (incl. research/<tech>.md) [--milestone]
             │        └─··▶ kanban/<iss>.md  +  knowledge/contracts/<iss>-<dep>.md stubs
             ├─··▶ FILL each edge-contract stub from iface/<seam>.md — an unfilled stub
             │     marks the edge coupled and dispatch will hold the dependent ticket
   [G]       ├══▶ kanban-graph — acyclic, deps resolve, assertions covered
             ├─··▶ knowledge/build-plan.md — waves + merge order (durable record)
             └══▶ kanban-dispatch ══▶ spawn-builder.sh per READY ticket (ready-set = every
                    dep edge DONE or contract-filled; MAX_BUILDERS is only a rate ceiling)


 ═══════════ PHASE 4 · BUILD (one builder per ready branch, own tmux + worktree feat/<iss>) ═══════
   builder (sonnet) reads ··▶ HANDOFF.md (read-only copy of kanban/<iss>.md), AGENTS.md,
                     modules.json, knowledge/lessons.md, linked knowledge/technical/research/*
                     (the planner's findings — no re-research); builds against the FILLED edge
                     contracts, mocks dependencies; sets up its own infra (NEEDS_SETUP = last
                     resort, human-held credentials only)
   testing split: EVERYTHING an LLM can verify runs here, in the build — functional flows,
   edge cases, acceptance assertions, UX baseline (loading/skeleton states, no hydration
   flash or layout shift, cache hits on reload, empty/error states);
   the user is only ever asked for taste
             ├══▶ kanban-update <iss> IN_PROGRESS ▒   ← the WHOLE build-validate loop lives here
             │      ├──"VALIDATE: <iss>"──▶ spawn-agent validator-agent (fresh context, sonnet)
             │      │     (H) port allocated at validator boot (kanban-port → frontmatter)
             │      │     validator authors its own tests from the acceptance contract, every
             │      │     assertion traces to a contract line ▒ kanban/validation/<iss>.md
             │      ├◀─"VALIDATION-FAILED: …"── fix → re-request (≤3 rounds; contested verdict
             │      │     → planner CONTESTED-VERDICT / TICKET-GAP; round 4 → human)
             │      └── verdict: pass ▒
             ├══▶ kanban-update <iss> NEEDS_SETUP ──▶ coordinator surfaces infra ask ◀═▶ USER
             ├══▶ kanban-update <iss> NEEDS_TESTING
             │      [G] REFUSED unless: passing verdict file + test_command set + completion
             │          sections filled + worktree committed. Card generated, coordinator pinged.
             └── (integration happens in Phase 5 via rebase-queue, after approval)


 ═══════════ PHASE 5 · ACCEPT & INTEGRATE ═════════════
   coordinator ◀═▶ USER walks kanban/user-test-cards/<iss> on the live app (taste, not tests)
             ├══▶ kanban-done <iss> "<feedback>" → DONE ▒
             │      └──"APPROVED: run rebase-queue <iss>"──▶ builder
             ├══▶ rebase-queue <iss>: PR (if remote) → serial lock → rebase onto main →
             │      ff-merge ══▶ kanban-aar <iss> (AAR + lessons.md) → builder self-mines
             │      repeated steps into scripts/ + .claude/skills/
             │      (H post-merge hook)──▶ coordinator pinged + kanban-dispatch re-run
             │                                   └══▶ newly-ready coupled tickets dispatched
   all features DONE ══▶ sanity agent (final pass)


 ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
 │ DEEP REVIEWER — future seat, brownfield only: when the product is semi-built and new     │
 │ features are being added, it reviews the existing system BEFORE the new work enters      │
 │ Phase 1, so the PM and planner inherit reality instead of assumptions. Not built yet.    │
 └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
```

## Joint contracts — every producer/consumer pair, verified

| # | Producer → Consumer | Shape | Verified how |
|---|---|---|---|
| 1 | PM → planner (files) | `knowledge/prd/product.md` (single PRD; one `## <slug>` section per feature) + `contracts/acceptance/<slug>.md` | Paths identical in both prompts and in prd-check |
| 2 | PM → planner (msg) | `FEASIBILITY-CHECK: <slug> — items: …` — one batched message per feature, only items the PM judged gate-worthy after reasoning over prior verdicts' assumptions | Planner prompt keys on the prefix and answers the listed items; verdict files record assumptions to make re-check judgment possible |
| 3 | planner → gate | `pipeline-state` stage ∈ ok\|workaround\|waived; `knowledge/technical/feasibility/<slug>.md` required only when checked | prd-check tested pass/fail incl. waived path |
| 4 | planner → PM (msg) | ONE reply per check, after full reasoning: `FEASIBILITY-RESULT: … Assumptions: …` (self-contained — the PM ledgers verdict+assumptions in product.md and never reads planner files) or `FEASIBILITY:` (blocked report + alternatives; PM decides escalation) | Both prefixes handled in PM prompt; assumptions travel in the message; planner files live under hook-guarded knowledge/technical/ |
| 5 | gate → planner | kickoff message + all stages `handed_off` | smoke-test steps 0-1 (refusal AND success) |
| 6 | planner → skill | `knowledge/spec/` (drafted during feasibility, `status: final` after the coherence pass), `knowledge/architecture.md` (incl. UX baseline), `knowledge/contracts/iface/` | Skill's input list matches; wave order uses the PRD feature index's user-priority column |
| 7 | skill → kanban-create | 9 flags | kanban-create's parser accepts exactly these |
| 8 | kanban-create → builders | `kanban/<iss>.md` + `knowledge/contracts/<iss>-<dep>.md` stubs, FILLED by the planner from iface/ | Read in script; smoke-test step 2 |
| 9 | kanban-dispatch → spawn-builder | issue + deps per READY ticket (edge DONE or contract filled); stub edge holds the ticket | smoke-test steps 4/4b (hold-back AND release) |
| 10 | spawn-builder → builder | worktree + `HANDOFF.md` copy + `--model sonnet` + kickoff naming the read-first files incl. linked research docs | Read in script (`cp "$HANDOFF" .../HANDOFF.md`) |
| 11 | builder → validator | `spawn-agent validator-agent "VALIDATE: <iss> — …"` while IN_PROGRESS; port allocated at validator boot (kanban-port) | Read in scripts; kanban-port unit-tested (alloc/idempotence/next-free) |
| 12 | builder → kanban-update | 5 canonical statuses; NEEDS_TESTING gated on passing verdict + test_command + filled sections + committed worktree; card generated + coordinator pinged | Read in script; smoke-test step 5 |
| 13 | kanban-done → builder → rebase-queue | `APPROVED: run rebase-queue <iss>` → PR (if remote) + serial-lock rebase + ff-merge + kanban-aar + self-mining prompt | rebase-queue unit test 12/12 (dirty-refuse, land, lock wait/release, AAR) |
| 14 | merge → coordinator | post-merge hook tmux send-keys + re-runs kanban-dispatch (newly-ready tickets) | Hook installed by factory-init at session start |

## Testing individual agents (outputs + workflow adherence)

The deterministic layer first: `bash scripts/smoke-test.sh` — 19 assertions over gate refusal,
gate pass, tickets, graph, worktrees, ready-set dispatch (hold-back and release), status
updates, and serial integration (rebase-queue → main + AAR). Zero LLM involvement (stubbed
`CLAUDE_BIN=true`). Run it after any plumbing change.

The full live-agent conversation test: `scripts/test-pm-conversation.sh [deck]` — deck-driven
so the SAME input data replays run after run. The deck (default
`tests/conversations/cloud-site-cloner.deck`, TAB-separated TYPE/ID/EXPECT/TEXT) is the fixed
conversation of a non-technical user; its sibling `.probes.sh` holds the expectations as
`pre_/probe_/wait_` functions keyed by record id. Every run stores its full history under
`kanban/test-runs/<deck-name>/<timestamp>/` — `run.log` (each message, its EXPECT tag, every
PASS/FAIL/MANUAL), both tmux transcripts, the event stream, and a snapshot of everything the
agents wrote. Compare two runs of the same deck:
`diff <(grep -oE '(PASS|FAIL|MANUAL).*' A/run.log) <(grep -oE '(PASS|FAIL|MANUAL).*' B/run.log)`.
Covers capture-per-message, dispatch, the single-pass feasibility reply, no-re-trigger on
minor edits, the blocked-verdict pushback loop, hook-refused then successful handoff, and the
final coherence pass. Real opus agents: budget 30-90 minutes; the final stage dispatches REAL
builders. (NOTE: the deck probes predate the single-pass reply — rework any `FEASIBILITY-ROUGH`
expectations before trusting a run.)

For LLM agents, the pattern is always: real agent, controlled inputs, assert on the files,
state, and event stream it leaves behind — never on what it says.

**Observe any agent read-only:** `tmux attach -rt <agent>` (detach: `Ctrl-b d`).
**Audit trail:** `tail -f kanban/agent-events.jsonl` and `bin/pipeline-state list`.

### PM (prd-agent) solo

```bash
bin/spawn-agent prd-agent && tmux attach -t prd-agent
```
Give it a small fake product (2 features: one whose buildability depends on the outside
world, e.g. "syncs with Google Calendar", one purely internal, e.g. "an about page"). Assert:
- capture-by-default: state a requirement in passing mid-conversation — it must appear in
  `knowledge/prd/product.md` in the same turn, under the right feature or Open questions
- single PRD shape: feature index table with both slugs, a `## <slug>` section each with a
  mermaid flow; `knowledge/contracts/acceptance/<slug>.md` appears when a flow is confirmed
- gate judgment: the Calendar feature dispatches ONE batched FEASIBILITY-CHECK
  (`tmux ls` shows the planner; PM keeps interviewing without waiting); the about page gets
  `feasibility_waived` with reasoning in the ledger and the planner is never spawned for it
- verdict reuse: after the Calendar verdict lands, change button copy on that feature — no
  new dispatch may fire; then add a second calendar-adjacent ask an existing verdict already
  answers — expect ledger reuse, not a re-dispatch; then change the feature in a way that
  breaks a recorded assumption (e.g. "sync must also work with no internet") — a fresh
  batched check MUST fire
- altitude discipline probes: ask "should we use Postgres?" — it must reframe to behavior;
  ask it to read `knowledge/technical/` — the hook must block (the refusal appears in its pane)
- premature handoff probe: say "hand off now" while a verdict is pending — `handoff_refused`
  must appear in events and no planner full-pass may start

### Planner, feasibility mode solo (no PM needed)

Author a fixture `knowledge/prd/product.md` with a `## search` section (plus its acceptance
contract), then:
```bash
bin/pipeline-state set search flow_confirmed
bin/spawn-agent technical-planning-agent "FEASIBILITY-CHECK: search — items: 1. results return under one second on 1M records. Read the 'search' section of knowledge/prd/product.md and knowledge/contracts/acceptance/search.md if present. Write knowledge/technical/feasibility/search.md, update pipeline-state, reply to prd-agent."
```
Assert: `knowledge/technical/feasibility/search.md` exists with a verdict line and doc links;
`pipeline-state get search` is `feasibility_ok|workaround|blocked`; the reply message is queued
(`kanban/inbox/prd-agent.jsonl`) or a prd-agent session was spawned. For adherence, seed an
impossible feature (e.g. "works with the laptop off with no remote component") and require the
`FEASIBILITY:` escalation path, not a fake ok.

### Planner, full-plan mode solo

Complete the fixture so `bin/prd-check` passes, then `bin/handoff-to-planner` and attach.
Assert: `knowledge/spec/<slug>.md` per feature; `knowledge/architecture.md` near 200 lines with
ADRs; `knowledge/contracts/iface/*` each marked contract-covered or coupled; the transcript
shows a fresh-context verifier subagent ran BEFORE the skill was invoked; then tickets exist,
`kanban-graph` exits clean, and dispatch fired. Adherence probe: delete one acceptance file
mid-run is not needed — instead check it honored a `workaround` constraint recorded in Phase 1.

### Builder solo

```bash
bin/kanban-create iss-900-demo --feature demo --title "hello page" --intent "smallest testable slice" --build "static page saying hello" --success "page loads and shows hello" --testing "open the page"
bin/kanban-dispatch iss-900-demo
tmux attach -rt iss-900-demo
```
Assert: worktree `feat/iss-900-demo` exists with `HANDOFF.md`; status walked
NOT_STARTED → IN_PROGRESS → NEEDS_TESTING (never DONE — that is kanban-done's job); while
IN_PROGRESS the builder spawned validator-agent and a port appeared in the ticket frontmatter
at validator boot; `kanban/validation/iss-900-demo.md` holds a passing verdict BEFORE the
NEEDS_TESTING transition; a card exists in `kanban/user-test-cards/`; the ticket's
What-was-built / How-it-works / Tests-run / Lessons-learned sections are filled.

### Workflow adherence, objectively

The expected event sequence per feature is:
`pipeline_stage flow_confirmed → feasibility_pending → feasibility_ok|workaround →
handed_off → handoff → agent_spawned → ticket_created → branch_created → task_dispatched →
task_update…` — grep `kanban/agent-events.jsonl` for order violations. `bin/kanban-eval`
scores coordinator responsiveness and per-builder adherence from the same stream.

## References

- knowledge/factory-wisdom.md — the principles this shape implements, with the Notion source link
- scripts/smoke-test.sh — executable specification of the deterministic layer
