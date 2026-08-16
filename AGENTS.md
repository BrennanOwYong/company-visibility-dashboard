# Project Knowledge Base

Read this before building anything.

## Codex factory startup

- This repository is one factory instance for one product project.
- On first start, if `.factory/project.json` is absent, ask for the GitHub repository URL and run
  `bin/factory-bootstrap <url>`.
- Read `docs/product/PRD.md`, optional `docs/product/principles.md`, `docs/architecture/roadmap.json`, and only the active feature mini-PRDs.
- Run `bin/roadmap-sync --sync-kanban` after roadmap edits. The script, not an agent, computes the DAG.
- Dispatch one low-cost `factory_builder` subagent per ready ticket in its own Git worktree.
- A builder may signal readiness only after code, structured observability, self-tests, and module
  documentation are committed.
- The readiness event rebases onto `origin/main` before it wakes `factory_tester`.
- The tester never edits requirements or code. UI browser work goes to `factory_web_tester`.
- User testing is subjective UX only. Functional criteria must already pass.
- Keep all coordination state under `.factory/`; do not use a machine-global coordinator pointer.

## Three-layer project memory

1. `docs/product/`: the current PRD, optional cross-feature product principles, and one mini-PRD per active feature.
2. `docs/architecture/`: the parseable technical roadmap, current architecture, module decisions, contracts, and current-PRD lessons.
3. `docs/delivery/`: versioned tickets, audits, AARs, and staged improvement candidates.

Active documentation reflects only the latest PRD. Git history and AARs retain superseded history.

## Shared Modules

Format: [[module-name]] — what it does — instantiation: singleton|factory

(Populated during planning phase by coordinator.)

## Known Integrations

(Populated during planning phase.)

## Environment Variables

(Populated during pre-flight.)

## Rules

- Check this file before writing any new integration or module.
- If a module exists, use it.
- Add new reusable modules here when you create them.
- Link reusable modules to their current documents under `docs/architecture/modules/`.
