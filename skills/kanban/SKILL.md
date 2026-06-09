# Kanban skill

Use this skill at the start of every builder session and whenever you need to update ticket progress.

## Your issue file

Your kanban file is at `$KANBAN_PROJECT_ROOT/kanban/$FEATURE_NAME.md`.
It contains: issue id, parent feature name, port, repo, status, dependencies, and sections you must fill in.

## Lifecycle — builder's view

```
spawn-builder creates your issue  →  status: IN_PROGRESS
You build                         →  kanban-update $FEATURE_NAME IN_PROGRESS "what you're doing"
You hit a blocker
  human/external needed           →  kanban-update $FEATURE_NAME NEEDS_ACTION "who must do what"
  waiting on another issue        →  kanban-update $FEATURE_NAME BLOCKED_ON "ISS-id: what you need"
  coordinator unblocks you        →  kanban-resolved is called for you, resume work
You finish building + tests pass  →  fill kanban sections, then:
                                     kanban-update $FEATURE_NAME BUILT "summary"
                                     ← this auto-generates the test card and pings coordinator
You DO NOT call kanban-done       →  coordinator calls it after user approves
```

## Status values

Any string is valid. The following have special meaning:

| Status | Who sets it | What it means |
|---|---|---|
| `IN_PROGRESS` | Builder | Actively building |
| `NEEDS_ACTION` | Builder | Blocked on human or external action — state exactly what and who |
| `BLOCKED_ON` | Builder | Waiting on another issue's output — state issue id and what you need |
| `BUILT` | Builder | Done, tests pass, ready for user testing. **Triggers test card.** |
| `COMPLETE` | Coordinator (via kanban-done) | User approved, ticket closed |

## Commands

```bash
# Update progress at every meaningful stage — as often as needed
kanban-update $FEATURE_NAME IN_PROGRESS "implementing the checkout form"
kanban-update $FEATURE_NAME NEEDS_ACTION "need Stripe secret key from user"
kanban-update $FEATURE_NAME BLOCKED_ON "ISS-003: need /api/user response shape"

# When done building and tests pass — fills kanban sections first, then:
kanban-update $FEATURE_NAME BUILT "checkout form complete, 4 Playwright tests pass"

# Check the full board
kanban-check
```

## What to fill in before calling BUILT

Open `$KANBAN_PROJECT_ROOT/kanban/$FEATURE_NAME.md` and fill in:

```markdown
## What was built
One paragraph. What the feature does from the user's perspective.

## How it works
Key implementation decisions. Data flow. Any non-obvious choices.

## Tests run
- [x] Description of each passing test (user-facing language, not technical)

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
This writes the after-action-report to `kanban/aar/$FEATURE_NAME-aar.md`, extracts lessons to `knowledge/lessons.md`, marks COMPLETE, and checks if the dependency cluster is fully closed.
