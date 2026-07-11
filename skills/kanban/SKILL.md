# Kanban skill

Use this skill at the start of every builder session and whenever you need to update ticket progress.

## Your issue file

Your kanban file is at `$KANBAN_PROJECT_ROOT/kanban/$FEATURE_NAME.md` (also copied into your worktree as HANDOFF.md).
The architect created it with your brief. The frontmatter is a typed link index: **intent**, **build**, **success_criteria**, **testing**, **feasibility**, and **architecture** each hold ONE link path to that section's canonical doc — read the linked docs, starting with build and success_criteria (always required; a blank critical field means the ticket is missing that section — flag it). The frontmatter also holds: issue, feature, title, status, milestone, repo, branch, worktree, port, dependsOn, needsInfra, needs_user_test, landing_url, test_command, and **target_type** (web | extension | cli | service | library — how the build is tested and shown). Overflow links live under **## Additional references** as labeled bullets, e.g. `- interface(session-bundle): knowledge/contracts/iface/session-bundle.md`, `- research(extension-capture): knowledge/technical/research/extension-capture.md`, `- module(wire): [[wire]]`. Then fill in the **What was built / How it works / Tests run / Lessons learned** sections as you go.

## Lifecycle — builder's view

```
spawn-builder creates your issue  →  status: NOT_STARTED
You begin                         →  kanban-update $FEATURE_NAME IN_PROGRESS "starting"
You build                         →  kanban-update $FEATURE_NAME IN_PROGRESS "what you're doing"
You need something only a human has→  kanban-update $FEATURE_NAME NEEDS_SETUP "exactly what you need + who provides it"
  user finishes the setup         →  resume; set IN_PROGRESS again
You finish the build              →  fill kanban sections + set test_command + commit, then:
                                     kanban-update $FEATURE_NAME RUNNING_TESTS "summary"
                                     ← the KANBAN spawns your validator (you do NOT spawn it)
Validator queues VALIDATION-FAILED →  fix the defects, then RUNNING_TESTS again to re-trigger it
On a passing verdict              →  the kanban routes the ticket onward; you are done
You DO NOT call kanban-done, NEEDS_USER_TESTING, or DONE — the kanban and coordinator own those
```

Your dependencies are already built and merged into your branch's base — build against the REAL
code in knowledge/contracts/ interfaces, not a mock. There is no "waiting on another issue" state.

## Status values

The canonical vocabulary, in pipeline order:

| Status | Who sets it | What it means |
|---|---|---|
| `NOT_STARTED` | dispatch | Ticket created; its dependencies are not all DONE yet |
| `IN_PROGRESS` | Builder | Actively building on real merged deps |
| `NEEDS_SETUP` | Builder | Paused: a human must provide a credential/account/access — state exactly what and who |
| `RUNNING_TESTS` | Builder | Build done + committed; the kanban spawns the validator to test the real system |
| `NEEDS_USER_TESTING` | Kanban | Validated; a `needs_user_test` ticket waits for the human's Test step on the board |
| `DONE` | Kanban / kanban-done | Integrated onto main |

## Commands

```bash
# Update progress at every meaningful stage — as often as needed
kanban-update $FEATURE_NAME IN_PROGRESS "implementing the checkout form"
kanban-update $FEATURE_NAME NEEDS_SETUP "user must create a Stripe account and add STRIPE_SECRET_KEY"

# When the build is done — fills kanban sections first, then:
kanban-update $FEATURE_NAME RUNNING_TESTS "checkout form complete, 4 Playwright tests pass"

# Check the full board
kanban-check
```

## What to fill in before calling RUNNING_TESTS

Open `$KANBAN_PROJECT_ROOT/kanban/$FEATURE_NAME.md` and fill in:

```markdown
## What was built
One paragraph. What the feature does from the user's perspective.

## How it works
Key implementation decisions. Data flow. Any non-obvious choices.

## Tests run
- [x] Description of each passing test (user-facing language, not technical)

Run browser tests with agent-browser before calling RUNNING_TESTS:
```bash
npm install -g agent-browser && agent-browser install   # once per machine
agent-browser snapshot          # get element refs
agent-browser click @e1         # interact
agent-browser screenshot        # verify
```

## Lessons learned
Non-obvious discoveries only:
- API shape that differed from docs
- Env quirk or gotcha
- Workaround for a specific bug
Skip anything a competent developer would expect.

test_command: <command or URL that loads this feature's test state>
```

If you ran the same shell command more than twice, extract it to `scripts/<name>.sh` and add it to AGENTS.md under "Available scripts".

## Reading prior lessons

`knowledge/lessons.md` contains lessons from previous builders on this project.  
Read it before starting — it may save you from known gotchas.

## Coordinator's view (for reference)

The coordinator calls `kanban-done` after user approval:
```bash
kanban-done $FEATURE_NAME "user feedback summary" "any additional notes"
```
This writes the after-action-report to `kanban/aar/$FEATURE_NAME-aar.md`, extracts lessons to `knowledge/lessons.md`, marks DONE, and checks if the dependency cluster is fully closed.
