#!/bin/bash
# smoke-test.sh — exercise the factory pipeline end to end with STUBBED agents
# (CLAUDE_BIN=true, so no real `claude` is launched), in a throwaway git repo.
# Run this after pulling the repo to verify the plumbing before the live interactive test.
#
# Verifies, against the real scripts:
#   handoff-to-planner spawns the planner session + logs the handoff
#   kanban-create writes tickets + logs ticket_created
#   kanban-dispatch honors deps-DONE readiness (a dependent is held while its dependency is
#     unfinished; marking the dependency DONE releases it), creates feat/<issue> worktrees + logs
#   kanban-update logs task_update
#   rebase-queue serial-integrates an approved branch onto main and writes the AAR
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
# Product code builds in its OWN repo (spawn-builder refuses the factory root as repo)
mkdir -p product; git -C product init -q
git -C product config user.email smoke@test.local; git -C product config user.name smoke
echo product > product/README.md; git -C product add -A; git -C product commit -qm init 2>/dev/null
mkdir -p knowledge/prd
echo "# search feature (fake PRD for smoke test)" > knowledge/prd/search.md

export KANBAN_PROJECT_ROOT="$PROJ"
export PATH="$FACTORY_BIN:$PATH"
export CLAUDE_BIN=true AGENT_BOOT_SECONDS=0 BUILDER_BOOT_SECONDS=0

EVENTS="$PROJ/kanban/agent-events.jsonl"

echo "0) handoff gate refuses an incomplete PRD (prd-check)"
pipeline-state set search feasibility_pending >/dev/null
handoff-to-planner >/dev/null 2>&1; HRC=$?
check "handoff refused (exit 1)"       '[ "$HRC" -eq 1 ]'
check "no planner session spawned"     '! tmux has-session -t technical-planning-agent 2>/dev/null'
check "handoff_refused logged"         'grep -q handoff_refused "$EVENTS"'

echo "1) PM completes the artifacts, hands off (handoff-to-planner)"
mkdir -p "$PROJ/knowledge/contracts/acceptance" "$PROJ/knowledge/technical/feasibility"
printf '# product (fake single PRD)\n## search\nflow...\n## about\nflow...\n' > "$PROJ/knowledge/prd/product.md"
echo "# acceptance: search (fake)"      > "$PROJ/knowledge/contracts/acceptance/search.md"
echo "# acceptance: about (fake)"       > "$PROJ/knowledge/contracts/acceptance/about.md"
echo "verdict: feasible (fake)"         > "$PROJ/knowledge/technical/feasibility/search.md"
pipeline-state set search feasibility_ok >/dev/null
pipeline-state set about feasibility_waived >/dev/null   # waived: no verdict file needed
handoff-to-planner >/dev/null 2>&1
check "planner session spawned"        'tmux has-session -t technical-planning-agent 2>/dev/null'
check "handoff event logged"           'grep -q "\"event\": \"handoff\"" "$EVENTS"'
check "checked feature handed_off"     '[ "$(pipeline-state get search)" = "handed_off" ]'
check "waived feature handed_off"      '[ "$(pipeline-state get about)" = "handed_off" ]'

echo "2) planner populates the kanban (kanban-create x2)"
kanban-create iss-001-api --feature backend  --title "REST API" --repo "$PROJ/product" >/dev/null
kanban-create iss-002-ui  --feature frontend --title "List UI" --repo "$PROJ/product" --depends-on iss-001-api >/dev/null
check "two tickets on the board"       '[ "$(ls "$PROJ"/kanban/*.md | wc -l)" -eq 2 ]'
check "ticket_created logged twice"    '[ "$(grep -c ticket_created "$EVENTS")" -eq 2 ]'

echo "3) graph validates (kanban-graph)"
kanban-graph >/dev/null 2>&1; GRC=$?
check "kanban-graph exits clean"       '[ "$GRC" -eq 0 ]'

echo "4) dispatch honors deps-DONE readiness: dependent held while its dep is unfinished (kanban-dispatch)"
kanban-dispatch >/dev/null 2>&1
check "feat/iss-001-api worktree made (product repo)" 'git -C "$PROJ/product" worktree list | grep -q "feat/iss-001-api"'
check "iss-002-ui held back (dep not DONE)" '! git -C "$PROJ/product" worktree list | grep -q "feat/iss-002-ui"'
check "branch_created logged once"     '[ "$(grep -c branch_created "$EVENTS")" -eq 1 ]'

echo "4b) marking the dependency DONE releases the dependent"
kanban-update iss-001-api DONE "merged" >/dev/null 2>&1
kanban-dispatch >/dev/null 2>&1
check "feat/iss-002-ui worktree made (dep now DONE)" 'git -C "$PROJ/product" worktree list | grep -q "feat/iss-002-ui"'
check "task_dispatched logged twice"   '[ "$(grep -c task_dispatched "$EVENTS")" -eq 2 ]'

echo "5) a task reports an update (kanban-update)"
kanban-update iss-002-ui IN_PROGRESS "starting" >/dev/null 2>&1
check "task_update logged"             'grep -q task_update "$EVENTS"'

echo "6) approved ticket integrates serially (rebase-queue → main + AAR)"
echo feature > "$PROJ/worktrees/iss-002-ui/ui.txt"
git -C "$PROJ/worktrees/iss-002-ui" add -A
git -C "$PROJ/worktrees/iss-002-ui" commit -qm "feat: ui" 2>/dev/null
rebase-queue iss-002-ui >/dev/null 2>&1
check "branch landed on product main"  'git -C "$PROJ/product" log --oneline 2>/dev/null | grep -q "feat: ui"'
check "AAR written after landing"      '[ -f "$PROJ/kanban/aar/iss-002-ui-aar.md" ]'
check "rebase lock released"           '[ ! -d "$PROJ/kanban/.rebase-lock" ]'

echo ""
echo "system-events stream:"
sed 's/^/    /' "$EVENTS" 2>/dev/null

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
