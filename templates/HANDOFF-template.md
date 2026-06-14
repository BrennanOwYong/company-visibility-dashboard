# Handoff: {{FEATURE_NAME}}

## Your task
{{FEATURE_DESCRIPTION}}

## Why this feature exists
{{FEATURE_INTENT}}

## Success criteria
{{SUCCESS_CRITERIA}}

## Port
{{PORT}}

## Modules to use (check modules.json for full list)
{{RELEVANT_MODULES}}

## External services needed
{{EXTERNAL_SERVICES}}

## Contracts (dependencies built in parallel — real impl may not exist yet)
{{CONTRACTS}}
Build against these interfaces. Do not wait for the real implementation.
Contract files are in knowledge/contracts/.

## User-provided examples
{{INPUT_OUTPUT_EXAMPLES}}

## Instructions

1. Read AGENTS.md and modules.json before writing any code.
2. Use existing modules — do not reimplement what already exists.
3. Research official docs before implementing any new integration.
4. For contracted dependencies: mock the interface described in knowledge/contracts/ — do not call the real service.
5. Update kanban status at each stage:
   - `kanban-update {{FEATURE_NAME}} IN_PROGRESS "what you're doing"`
   - `kanban-update {{FEATURE_NAME}} NEEDS_SETUP "external infra the user must set up that you cannot"`
6. Test your feature. Tests must pass before marking ready.
7. Fill in the kanban MD file sections: what was built, how it works, tests run.
8. If you created a new reusable module, add it to AGENTS.md and modules.json.
9. Call `kanban-update {{FEATURE_NAME}} NEEDS_TESTING "plain-language summary"` when the build is done.
   Do NOT call kanban-done — the coordinator does that after the user approves.

## Do not
- Touch files outside your worktree scope.
- Hardcode secrets — use process.env.VARIABLE_NAME.
- Reimplement a module that already exists in modules.json.
- Mark done before tests pass.
- Call the real implementation of a contracted dependency — mock it.
