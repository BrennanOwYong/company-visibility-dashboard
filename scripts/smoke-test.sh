#!/bin/bash
# smoke-test.sh — exercise the factory pipeline end to end with STUBBED agents
# (CLAUDE_BIN=true, so no real `claude` is launched), in a throwaway git repo.
# Run this after pulling the repo to verify the plumbing before the live interactive test.
#
# Verifies, against the real scripts:
#   handoff-to-planner spawns the planner session + logs the handoff
#   kanban-create writes tickets + logs ticket_created
#   kanban-dispatch creates feat/<issue> worktrees/branches + logs branch_created/task_dispatched
#   kanban-update logs task_update
# It does NOT test real agent reasoning — only that the system actions fire and are logged.
set -u

FACTORY_BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
TMP="$(mktemp -d)"
PROJ="$TMP/proj"

cleanup() {
  for s in technical-planning-agent iss-001-api iss-002-ui; do tmux kill-session -t "$s" 2>/dev/null; done
  rm -rf "$TMP"
}
trap cleanup EXIT

PASS=0; FAIL=0
check() { # check "desc" "test-expression"
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1)); else echo "  FAIL  $1"; FAIL=$((FAIL+1)); fi
}

# ---- set up a throwaway factory project ----
mkdir -p "$PROJ"; cd "$PROJ" || exit 1
git init -q
git config user.email smoke@test.local; git config user.name smoke
echo "smoke" > README.md; git add -A
git commit -qm init 2>/dev/null || echo "  (note: git commit unavailable in this env; continuing — worktree add still works)"
touch factory.json
mkdir -p knowledge/prd
echo "# search feature (fake PRD for smoke test)" > knowledge/prd/search.md

export KANBAN_PROJECT_ROOT="$PROJ"
export PATH="$FACTORY_BIN:$PATH"
export CLAUDE_BIN=true AGENT_BOOT_SECONDS=0 BUILDER_BOOT_SECONDS=0

EVENTS="$PROJ/kanban/agent-events.jsonl"

echo "1) PM hands off to the planner (handoff-to-planner)"
handoff-to-planner >/dev/null 2>&1
check "planner session spawned"        'tmux has-session -t technical-planning-agent 2>/dev/null'
check "handoff event logged"           'grep -q "\"event\": \"handoff\"" "$EVENTS"'

echo "2) planner populates the kanban (kanban-create x2)"
kanban-create iss-001-api --feature backend  --title "REST API" >/dev/null
kanban-create iss-002-ui  --feature frontend --title "List UI" --depends-on iss-001-api >/dev/null
check "two tickets on the board"       '[ "$(ls "$PROJ"/kanban/*.md | wc -l)" -eq 2 ]'
check "ticket_created logged twice"    '[ "$(grep -c ticket_created "$EVENTS")" -eq 2 ]'

echo "3) graph validates (kanban-graph)"
kanban-graph >/dev/null 2>&1; GRC=$?
check "kanban-graph exits clean"       '[ "$GRC" -eq 0 ]'

echo "4) dispatch creates branches + spawns coding agents (kanban-dispatch)"
kanban-dispatch >/dev/null 2>&1
check "feat/iss-001-api worktree made" 'git -C "$PROJ" worktree list | grep -q "feat/iss-001-api"'
check "feat/iss-002-ui worktree made"  'git -C "$PROJ" worktree list | grep -q "feat/iss-002-ui"'
check "branch_created logged twice"    '[ "$(grep -c branch_created "$EVENTS")" -eq 2 ]'
check "task_dispatched logged twice"   '[ "$(grep -c task_dispatched "$EVENTS")" -eq 2 ]'

echo "5) a task reports an update (kanban-update)"
kanban-update iss-001-api IN_PROGRESS "starting" >/dev/null 2>&1
check "task_update logged"             'grep -q task_update "$EVENTS"'

echo ""
echo "system-events stream:"
sed 's/^/    /' "$EVENTS" 2>/dev/null

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
