# Technical Spec: {{PROJECT_NAME}}

The architect's primary deliverable. Written from the PM's requirements
(`knowledge/user-flow.md` + `knowledge/edge-cases.md`) before any issue is created.
Everything downstream is derived from this doc: the module registry (AGENTS.md +
modules.json), every kanban issue (`kanban-create`), and the contracts.

Keep it the single source of design truth. If a decision changes, change it here first.

---

## 1. System overview
What is being built, in two or three paragraphs. The architecture shape: the
components/services, the datastores, the external integrations, and how a request flows
through them. A simple text diagram is enough.

## 2. Tech stack and key decisions
Languages, frameworks, datastores, and the notable libraries — each with the WHY.
Record rejected alternatives when the choice was close.
→ Feeds AGENTS.md "Known Integrations" and the build conventions.

## 3. Data model
The entities, their fields, and the relationships between them. The schemas that cross
issue boundaries live here so every builder references one definition.
→ Issues that touch an entity link back to this section.

## 4. Module decomposition
The reusable modules the build will share, each with its instantiation type
(singleton | factory) and one line on what it does.
→ Feeds modules.json (machine-readable) and AGENTS.md "Shared Modules" with [[backlinks]].
→ Builders MUST reuse these instead of reimplementing.

## 5. Component / issue map
How the system divides into atomic, independently buildable issues. One row per planned
issue: id, the feature it satisfies, what it builds, and which module(s) it owns or uses.
This is the bridge to `kanban-create` — each row becomes one issue.
→ Feeds `--feature`, `--title`, `--build`, `--intent`, `--success`, `--links`.

| issue | feature | what it builds | uses/owns modules |
|---|---|---|---|
| | | | |

## 6. Interfaces and contracts
The boundaries between issues — every place one issue consumes another's output. For each
edge, the exact shape: endpoint path, request/response schema, event signature, or data
model. The dependent issue builds against this and mocks it.
→ Feeds `--depends-on`; `kanban-create` scaffolds `knowledge/contracts/<issue>-<dep>.md`
  per edge — fill each from this section.

## 7. External infrastructure
External services, accounts, credentials, and env vars the user must set up that no agent
can (Stripe account, OPENAI_API_KEY, a provisioned database, an OAuth app, ...). One row
per item: what it is, which issues need it, and what the user must do.
→ Feeds `--needs-infra`; each surfaces to the user as NEEDS_SETUP when a builder reaches it.

| infra | needed by | what the user must do |
|---|---|---|
| | | |

## 8. Build sequencing and milestones
The order of work: which issues are independent (parallel) and which wait on others, grouped
into milestones/waves. State the reasoning, not just the order.
→ Feeds `--milestone` and `--depends-on`. Verify with `kanban-graph` (waves, cycles, dangling).

## 9. Cross-cutting concerns
Decisions that apply across issues so each builder handles them the same way: auth, error
handling, logging, config/secrets, security, performance budgets, accessibility.

## 10. Testing strategy
How the system is verified as a whole, and how a feature's test state is brought up (the
shape of each issue's `test_command`). Per-issue test steps live in the issue's Testing
section; the overall approach and shared fixtures live here.
→ Ties to the NEEDS_TESTING transition (a port is assigned then) and the user-test cards.

## 11. Non-goals
What is explicitly out of scope for this milestone. Prevents scope creep in issues.

## 12. Open questions and risks
Unresolved decisions and known risks. Anything deferred goes to `knowledge/KIV.md` with a
back-reference here.
