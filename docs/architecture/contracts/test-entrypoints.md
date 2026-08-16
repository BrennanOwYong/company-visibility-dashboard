# Test Entrypoint Contracts

## Terms

- The **candidate check** is a terminating command that tests the whole pull-request candidate.
- The **test environment launcher** is a persistent command that serves the exact candidate for
  browser-control and subjective user testing.

These are separate commands because a check must finish and a server must stay active.

## `bin/project-test`

`bin/project-test` is the only whole-project candidate check used after rebase and by GitHub Actions.
It accepts no feature selector. Every feature branch must pass the same complete check.

Before product application code exists, it validates the factory infrastructure. Once root
`package.json` exists, it also requires a lock file and the application scripts `typecheck`, `lint`,
`test:unit`, `test:contract`, `test:browser`, and `test:events`. It installs the locked dependencies
when necessary and runs all six scripts. A missing script is a failure, not a skipped test.

Application scripts must cover migrations, provider simulators, page-definition validation,
security boundaries, accessibility, positive/negative browser journeys, and correlated event-chain
assertions as assigned in the feature architecture views. Live provider smoke tests remain a
separate external gate because they require approved accounts.

The command returns zero only when all applicable checks pass. It must not start a persistent server,
change product data outside test fixtures, dispatch work, or require production credentials.

## `bin/project-dev`

`bin/project-dev` is the only reviewed persistent launcher for browser and user tests. It starts the
application through the required `dev:test` package script and replaces itself with that process.

The launched application must:

- Bind only to loopback and use the dynamic `PORT` environment variable supplied by the factory.
- Serve `GET /health` without authentication only as a process-readiness result. The response must
  contain no configuration or secret detail.
- Load deterministic test fixtures and safe simulated provider/model behavior unless approved test
  environment variables select real external test systems.
- Include an `evaluation-page` fixture after the generated-page feature exists.
- Persist test state inside the candidate's isolated test environment, not production.
- Remain active until it receives a termination signal and shut down cleanly.
- Never use a source watcher that changes files in the validated candidate worktree.

The Test Me page chooses the landing path from `docs/architecture/roadmap.json`. A healthy launcher
does not mean the feature passed; the independent browser tester and user still judge the declared
journey.

## Required landing routes

| Feature | Route |
|---|---|
| `dashboard-shell` | `/` |
| `connected-social-tools` | `/connected-tools` |
| `company-memory` | `/memory` |
| `page-builder-chat` | `/pages/new` |
| `generated-dashboard-pages` | `/pages/evaluation-page` |

Unavailable future routes are not required before their feature is built. Each builder must add its
route and fixtures before that feature can signal readiness.
