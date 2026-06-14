# Keep In View (KIV)

Deferred design questions and unresolved open points. Review before starting related work.

---

## 1. Test state loading for non-web targets

User-test cards have a `test_command` field and the kanban UI will have a button that loads the testing state. Currently assumes a local dev server (`npm run dev` → `localhost:PORT`). Open question: how does this extend to:
- Chrome extensions (load unpacked into browser, navigate to extension popup)
- Desktop apps (Electron — launch binary, navigate to screen)
- Distributed systems (multiple services, may need orchestration script)
- Mobile apps (iOS/Android simulator)

No solution designed yet. Mark as KIV until the factory is tested on a chrome extension build.

**Why:** user raised this explicitly. Needs a concrete example (chrome extension build) before designing a general solution.
**How to apply:** when designing `test_command` for non-web features, flag that the pattern is unresolved and document what was done as a learning.

---

## 2. Full cognitive deviation accounting

Currently: the deviation clause says builders must surface when their output differs from the brief and explain why. Future: the LLM should be able to reason about whether a deviation is a legitimate course-correction vs sloppy work, automatically update the contract if the deviation changes the interface, and propagate that change to dependent issues.

Not implemented. Flagged as a future LLM capability.

**Why:** user noted this is "eventually a cognitive capability of the LLM." Current rule handles the human-readable surface; the automated propagation is deferred.

---

## 3. Automated script extraction from repeated bash commands

Current rule: builder must manually extract repeated commands to `scripts/<name>.sh` after running the same command 3+ times.

Future: the builder agent should detect repetition automatically (via session transcript analysis) and extract without being told. Could be implemented as a PostToolUse hook on Bash calls that counts identical/near-identical patterns and prompts extraction.

Not implemented beyond the rule. KIV.

---

## 4. First real factory test target: Chrome extension

Once the factory spec phase and issue ticket system are complete, build a Chrome extension from scratch using the factory. This will stress-test:
- Non-web test state loading (KIV item 1)
- Multi-repo or single-repo decision for extensions
- Whether BMAD or GSD is better for a greenfield extension
- Whether the contract system handles manifest.json / background service worker boundaries

---

## 5. Git provider integration for kanban actions

Kanban actions (post-merge ping to coordinator, status transitions, AAR generation) are currently triggered by local git post-merge hooks installed by `factory-init.sh`. This requires the hook to be present on every developer machine and only fires on local merges.

Future: support webhook-based triggers from any git service provider so that remote merges, pull request events, and branch pushes trigger kanban updates without local hook installation. Providers to support:
- GitHub (GitHub Actions, repository webhooks)
- GitLab (CI/CD pipelines, project webhooks)
- Bitbucket (Pipelines, webhooks)

The kanban scripts (`kanban-update`, `post-merge-hook.sh`) should remain the canonical implementation; the provider integrations are thin adapters that call them.

Not designed yet. KIV until the factory is used in a team setting with a remote git host.

---

## 6. RBAC'd SOP and company data

RBAC'd SOP and company data.

---

## 7. tmux session liveness ↔ kanban state mapping

The dispatcher's status view originally reconciled tmux session liveness against
declared kanban status to derive a `DEAD` state (session gone before testing).
Pulled out — the mapping depends on an unresolved architecture question:

- **Single agent per feature module** — one tmux session owns one ticket for its
  whole life, so session-gone-before-complete cleanly means that ticket died.
- **Single agent builds many features** — one session spans multiple tickets, so
  session liveness no longer maps 1:1 to a ticket's state and "dead" is ambiguous.

No conclusive performance evidence yet on which model is better. Until that lands,
do NOT couple tmux liveness to kanban state. Kanban status (declared by the agent)
is the only source of truth for a ticket's state; `kanban-check` shows the board
from declared status alone.

**Why:** user is researching the agent↔feature mapping; performance inconclusive.
**How to apply:** keep liveness/crash detection out of dispatch and status views
until the mapping is decided. Revisit `DEAD`/restart logic then.
