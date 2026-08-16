---
name: kanban
description: Operate one roadmap-derived factory ticket through build, independent validation, optional UX review, and a GitHub pull request.
---

# Ticket lifecycle

Read the thin record at `kanban/<ticket>.md`. Follow its `feature_doc` and `architecture_doc` links.
The feature document is the requirement source. Do not copy or edit it.

Use these states:

- `NOT_STARTED`: prerequisites on the roadmap are not complete.
- `IN_PROGRESS`: the builder works in its Git worktree.
- `NEEDS_SETUP`: a person must supply external access or setup.
- `RUNNING_TESTS`: an independent tester tests the rebased candidate.
- `NEEDS_USER_TESTING`: objective tests passed; a person can select Test Me in the factory UI.
- `PR_OPEN`: the exact tested commit is in a GitHub pull request.
- `DONE`: GitHub merged the pull request and local main fast-forwarded from remote main.

Builders push each useful commit to `origin/feat/<ticket>`. They record structured frontend and
backend events and inspect those events while testing. An AAR is advisory. Use it only to record
repeated module-specific setup and test steps, skill candidates, and non-obvious trip-ups. Never
delay mandatory testing for an absent AAR.

For a web feature, convert the product document's numbered Positive flow and Negative and recovery
flow into browser journeys. Use agent-browser. Record the ordered actions, visible results,
screenshots, console output, network evidence, and correlated application events against each DC ID.

Only the Product Manager changes `docs/product/**`. Only the technical planner changes
`docs/architecture/roadmap.json`. GitHub is the only merge authority.
