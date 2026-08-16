---
name: software-factory
description: Initialize and operate one autonomous Codex software factory per project, with mini-PRD tickets, deterministic DAG dispatch, isolated worktrees, structured observability, independent tests, and current-PRD memory.
---

# Software Factory

On session start, read the project `AGENTS.md`. If `.factory/project.json` is absent, ask for the
GitHub repository URL and run `bin/factory-bootstrap <url>`.

Use `docs/product/PRD.md`, optional product principles, and `docs/product/features/<id>.md` as the
only product truth. Use `docs/architecture/roadmap.json` as the only chronology/dependency source. Run
`bin/roadmap-sync --sync-kanban`; never infer graph edges in an agent prompt.

Dispatch ready tickets to `factory_builder` agents in isolated worktrees. A builder instruments and
self-tests required event chains, pushes each useful commit, then signals `READY_FOR_TESTING`. The
program rebases onto `origin/main` and reruns tests before waking `factory_tester`. The tester
records criterion-level and quality-axis evidence and never changes requirements or code. UI browser
execution belongs to `factory_web_tester`. Escalate to the user only for human-held external setup or
subjective UX after all objective criteria pass. After approval, push the exact tested commit and
open a GitHub pull request. Never merge locally. Observe the GitHub merge, fast-forward local main,
then mark DONE and dispatch newly ready work. An AAR is advisory and contains only repeated
module-specific procedures, skill candidates, and non-obvious trip-ups.
