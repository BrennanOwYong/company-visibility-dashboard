# Kanban skill

Use this skill at the start of every builder session and whenever you need to update ticket progress.

## Your issue file

Your kanban file is at `$KANBAN_PROJECT_ROOT/kanban/$FEATURE_NAME.md` (also copied into your worktree as HANDOFF.md).
The architect created it with your brief — read these sections first: **Intent**, **Build**, **Success criteria**, **Testing**, and **Dependencies** (issues you depend on + their contracts in `knowledge/contracts/`, and external infra the user must set up). The frontmatter holds: issue id, feature, status, milestone, dependsOn, needsInfra, links, repo. Then fill in the **What was built / How it works / Tests run / Lessons learned** sections as you go.

## Lifecycle — builder's view

```
spawn-builder creates your issue  →  status: NOT_STARTED
You begin                         →  kanban-update $FEATURE_NAME IN_PROGRESS "starting"
You build                         →  kanban-update $FEATURE_NAME IN_PROGRESS "what you're doing"
You need external infra set up     →  kanban-update $FEATURE_NAME NEEDS_SETUP "what the user must set up"
  user finishes the setup         →  resume; set IN_PROGRESS again
You finish the build              →  fill kanban sections, then:
                                     kanban-update $FEATURE_NAME NEEDS_TESTING "summary"
                                     ← assigns a port, auto-generates the test card, pings coordinator
You DO NOT call kanban-done       →  coordinator calls it after user approves → COMPLETE
```

Dependencies on other tickets do NOT block you: build against the contract in
knowledge/contracts/ and mock it. There is no "waiting on another issue" state.

## Status values

The canonical vocabulary, in pipeline order:

| Status | Who sets it | What it means |
|---|---|---|
| `NOT_STARTED` | spawn-builder | Ticket created, agent has not begun |
| `IN_PROGRESS` | Builder | Actively building |
| `NEEDS_SETUP` | Builder | Paused: user must set up external infra the agent cannot — state exactly what and who |
| `NEEDS_TESTING` | Builder | Build done, ready for the testing phase. **Assigns a port + triggers test card.** |
| `COMPLETE` | Coordinator (via kanban-done) | User approved, ticket closed |

## Commands

```bash
# Update progress at every meaningful stage — as often as needed
kanban-update $FEATURE_NAME IN_PROGRESS "implementing the checkout form"
kanban-update $FEATURE_NAME NEEDS_SETUP "user must create a Stripe account and add STRIPE_SECRET_KEY"

# When the build is done — fills kanban sections first, then:
kanban-update $FEATURE_NAME NEEDS_TESTING "checkout form complete, 4 Playwright tests pass"

# Check the full board
kanban-check
```

## What to fill in before calling NEEDS_TESTING

Open `$KANBAN_PROJECT_ROOT/kanban/$FEATURE_NAME.md` and fill in:

```markdown
## What was built
One paragraph. What the feature does from the user's perspective.

## How it works
Key implementation decisions. Data flow. Any non-obvious choices.

## Tests run
- [x] Description of each passing test (user-facing language, not technical)

Run browser tests with agent-browser before calling NEEDS_TESTING:
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
This writes the after-action-report to `kanban/aar/$FEATURE_NAME-aar.md`, extracts lessons to `knowledge/lessons.md`, marks COMPLETE, and checks if the dependency cluster is fully closed.
