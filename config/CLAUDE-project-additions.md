# Additions for your project-level CLAUDE.md
# (e.g. C:\Users\<you>\.claude\CLAUDE.md on Windows / ~/.claude/CLAUDE.md on Linux)
# Append these sections.

## No slop — all agent output

Every agent's text output follows these rules. Applies to messages, code comments, handoff docs, kanban updates, and user-test cards.

Cut without exception:
- Throat-clearing openers: "here's the thing", "let me be clear", "the truth is", "it turns out"
- Emphasis crutches: "full stop", "let that sink in", "make no mistake", "this matters because"
- All adverbs: -ly words, "really", "just", "literally", "genuinely", "simply", "actually"
- Meta-commentary: "in this section", "let me walk you through", "as we'll see"
- Vague declaratives: "the implications are significant", "this is important", "the stakes are high"
- Business jargon: navigate → handle, unpack → explain, landscape → situation, double down → commit
- Binary contrasts: "not X but Y" — state Y, drop the negation
- False agency: name the person acting, not the abstract thing

Required:
- Active voice. Name the actor.
- No Wh- sentence starters — lead with subject or verb instead
- No em dashes
- No staccato fragmentation — no stacked short punchy sentences
- Specific over vague — name the exact thing

## Automated testing is run by the builder agent

All tests that can be expressed as a deterministic pass/fail — functional, regression, unit, sanity, acceptance, smoke, performance/load, security — are run by the builder agent itself using the Playwright MCP server or the vercel/browser-agent repo. Never delegated to a separate testing agent, never run by the user. The builder runs tests against the live app (not mocks) before calling kanban-done. A feature is not complete until tests pass.

The dividing line: if a test produces an objective result (it worked / it didn't), the builder owns it. If a test requires a human reaction (did it feel right?), the user owns it.

## User-testing breakpoints in planning

During the planning phase, every user-facing feature must be tagged with a `[USER-TEST]` breakpoint. When execution reaches one, pause and emit a scenario card before continuing. The card has four sections:

1. **SETUP** — a minimal runnable script (shell commands, seed commands, env flags) that brings the app to exactly the state needed to test this feature, including any prior-state dependencies.
2. **WHAT TO DO** — a short numbered walkthrough of the interaction path.
3. **WHAT YOU ARE JUDGING** — checkbox questions framed around human reaction and UX heuristics: does it feel fast or sluggish, is the flow intuitive, is anything surprising, would a first-time user understand what to do, does anything make you want to redo or skip a step. These are NOT pass/fail.
4. **ALREADY VERIFIED BY AGENT** — an explicit list of what automated tests already covered, so the user does not re-check it.

Close the card with a one-line prompt for the user's reply, and hold execution until the reply arrives.
