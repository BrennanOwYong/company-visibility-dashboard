#!/bin/bash
# test-kanban-ticket.sh — single-ticket lifecycle test: is one well-hydrated kanban ticket
# enough for a builder to ONE-SHOT the build, and does the independent validator (maker is
# never the tester) verify it against the contract and correctly diagnose any failure?
#
# The ticket below is deliberately small but fully hydrated (intent/build/success/testing all
# filled the way roadmap-and-branching would). The thesis under test: a ticket this informed
# fails only for reasons outside our control — and those get classified `external` with the
# NEEDS_SETUP protocol, while builder-defect / test-defect / ticket-underspecified
# classifications identify exactly WHY a failure happened (builder wrong vs test wrong vs
# ticket thin). Wisdom source: knowledge/factory-wisdom.md §4 (creator-verifier) and §5
# (done defined before building).
#
# Lifecycle exercised (shift-left): kanban-create → dispatch (worktree in the PRODUCT repo +
# real builder) → builder's own tests → builder spawns validator-agent while still
# IN_PROGRESS (port allocated at validator boot) → validator authors its OWN tests from the
# contract, runs them on the live app, writes kanban/validation/<iss>.md → only after a
# passing verdict does kanban-update accept NEEDS_TESTING (card + coordinator ping).
#
# Run history: kanban/test-runs/kanban-ticket/<timestamp>/. Real agents; budget 15-45 min.
# Cleanup of the build branch: this script removes worktree+branch+sessions on rerun.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export KANBAN_PROJECT_ROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"

ISS="iss-990-hello"
BUILD_TIMEOUT="${BUILD_TIMEOUT:-2400}"     # builder one-shot window: build + self-test + validation loop
VALIDATE_TIMEOUT="${VALIDATE_TIMEOUT:-1500}"
PRODUCT_REPO="$ROOT/product"               # product code never builds into the factory tree

RUN_DIR="$ROOT/kanban/test-runs/kanban-ticket/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"
RUN_LOG="$RUN_DIR/run.log"
EVENTS="$ROOT/kanban/agent-events.jsonl"
PASS=0; FAIL=0; MANUAL=0

log()   { printf '%s\n' "$*" | tee -a "$RUN_LOG"; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then log "  PASS   $d"; PASS=$((PASS+1)); else log "  FAIL   $d"; FAIL=$((FAIL+1)); fi; }
wait_for() {
  local t="$1"; shift; local start; start=$(date +%s)
  until "$@" >/dev/null 2>&1; do
    sleep 10
    if [ $(( $(date +%s) - start )) -ge "$t" ]; then return 1; fi
  done
  return 0
}
fm() { grep "^$2:" "$1" 2>/dev/null | head -1 | sed "s/^$2:[[:space:]]*//"; }   # fm <file> <key> (cut -f2- wrongly returns the whole line when the value is blank)

COORD_ROOT=$(cat "$HOME/.claude/.coordinator-root" 2>/dev/null)
[ "$COORD_ROOT" = "$ROOT" ] || { echo "ABORT: coordinator-root is '$COORD_ROOT'; run bin/factory-init.sh here first."; exit 1; }

log "Kanban single-ticket test — run dir: $RUN_DIR"

# Product repo (spawn-builder refuses the factory root as the build target)
if [ ! -d "$PRODUCT_REPO/.git" ]; then
  git init -q -b main "$PRODUCT_REPO"
  git -C "$PRODUCT_REPO" config user.email factory@local
  git -C "$PRODUCT_REPO" config user.name factory
  echo "# Product" > "$PRODUCT_REPO/README.md"
  git -C "$PRODUCT_REPO" add -A && git -C "$PRODUCT_REPO" commit -qm "init product repo"
fi

log "Cleaning previous $ISS state..."
tmux kill-session -t "$ISS" 2>/dev/null
tmux kill-session -t validator-agent 2>/dev/null
# Derive the worktree path from git itself (spawn-builder puts it at <product>/../worktrees/<iss>);
# a guessed path that misses leaves a stale worktree, and kanban-dispatch then SKIPS the
# issue as already-dispatched — no builder ever spawns.
git -C "$PRODUCT_REPO" worktree list --porcelain | awk '/^worktree /{p=$2} /^branch .*feat\/'"$ISS"'$/{print p}' \
  | while read -r WT; do git -C "$PRODUCT_REPO" worktree remove --force "$WT" 2>/dev/null; done
git -C "$PRODUCT_REPO" worktree prune 2>/dev/null; git -C "$PRODUCT_REPO" branch -D "feat/$ISS" 2>/dev/null
if [ -f "$ROOT/kanban/dispatch-log.jsonl" ]; then
  grep -v "\"$ISS\"" "$ROOT/kanban/dispatch-log.jsonl" > "$ROOT/kanban/dispatch-log.tmp" 2>/dev/null
  mv "$ROOT/kanban/dispatch-log.tmp" "$ROOT/kanban/dispatch-log.jsonl"
fi
rm -f "$ROOT/kanban/$ISS.md" "$ROOT/kanban/validation/$ISS.md" "$ROOT"/kanban/user-test-cards/*"$ISS"* 2>/dev/null
git -C "$PRODUCT_REPO" worktree list | grep -q "feat/$ISS" && { echo "ABORT: stale worktree for feat/$ISS still present"; exit 1; }

log ""; log "════ 1. Create the fully-hydrated ticket (what roadmap-and-branching would emit)"
kanban-create "$ISS" --feature hello-orders --title "Static order-ping page" --repo "$PRODUCT_REPO" \
  --intent "Prove the ticket→builder→validator loop: a shop owner wants a page confirming test orders at a glance. Smallest end-to-end user-facing slice." \
  --build "One static page (plain HTML+JS, no framework, no server code): heading 'Hello Shop'; a button labeled 'Ping'; an order list below. Clicking Ping appends one 'order received' entry to the list. When the list is empty show the text 'no orders yet' (designed empty state, not blank). Persist the list across reloads with localStorage (cached, not refetched). Serve with a static file server started by test_command. No build step." \
  --success "1. Page loads at test_command URL showing heading 'Hello Shop'. 2. Before any click, the list area shows 'no orders yet'. 3. Clicking Ping once shows exactly one 'order received' entry and hides 'no orders yet'. 4. Clicking Ping three times shows exactly three entries. 5. Reloading the page keeps the entries (cache/persistence). 6. No layout shift when entries appear (list area has reserved space)." \
  --testing "Run test_command (builder sets it: static server on the assigned port + URL). Verify each success criterion in order with agent-browser: snapshot, click @Ping, re-snapshot, screenshot, reload, re-snapshot." \
  >/dev/null
mkdir -p "$ROOT/knowledge/contracts/acceptance"
cat > "$ROOT/knowledge/contracts/acceptance/hello-orders.md" <<'EOF'
# Acceptance — hello-orders
Done criteria: a shop owner can open the page, see it is empty in plain words, press Ping to
record a test order, see each press add exactly one entry, and find the entries still there
after closing and reopening the page.
User-facing acceptance: 1. Open the page; confirm the heading and the 'no orders yet' message.
2. Press Ping once; confirm one 'order received' entry appears and the empty message is gone.
3. Press Ping twice more; confirm exactly three entries. 4. Reload; confirm the three entries
remain. 5. Confirm nothing on the page jumps or shifts as entries appear.
EOF
check "ticket created"                       test -s "$ROOT/kanban/$ISS.md"
check "ticket carries success criteria"      sh -c "grep -q 'no orders yet' '$ROOT/kanban/$ISS.md'"
check "feature acceptance contract present"  test -s "$ROOT/knowledge/contracts/acceptance/hello-orders.md"

log ""; log "════ 2. Dispatch ONE builder; the WHOLE build-validate loop runs inside IN_PROGRESS"
kanban-dispatch >/dev/null 2>&1
check "worktree/branch created (product repo)" sh -c "git -C '$PRODUCT_REPO' worktree list | grep -q 'feat/$ISS'"
check "builder session up"                   tmux has-session -t "$ISS"

# The builder itself spawns the validator while IN_PROGRESS; the harness only watches.
VFILE="$ROOT/kanban/validation/$ISS.md"
if wait_for "$BUILD_TIMEOUT" sh -c "test -s '$VFILE'"; then
  log "  PASS   builder requested validation and a verdict was written (shift-left loop ran)"; PASS=$((PASS+1))
else
  log "  FAIL   no validation verdict within ${BUILD_TIMEOUT}s — builder never completed the build-validate loop"; FAIL=$((FAIL+1))
fi
check "port allocated at validator boot"     sh -c "grep -q port_assigned '$EVENTS' && fm_port=\$(grep '^port:' '$ROOT/kanban/$ISS.md' | awk '{print \$2}'); echo \"\$fm_port\" | grep -qE '^[0-9]+$'"
check "verdict frontmatter present"          sh -c "grep -qE '^verdict: (pass|fail)' '$VFILE'"
check "per-assertion table present"          sh -c "grep -cE 'PASS|FAIL' '$VFILE' | grep -qv '^0$'"
check "validation event logged"              sh -c "grep -q validation_verdict '$EVENTS'"

log ""; log "════ 3. NEEDS_TESTING only after a passing verdict (gate order from the event stream)"
if wait_for "$VALIDATE_TIMEOUT" sh -c "grep -q '^status: NEEDS_TESTING' '$ROOT/kanban/$ISS.md'"; then
  log "  PASS   ticket reached NEEDS_TESTING"; PASS=$((PASS+1))
  check "passing verdict on file"            sh -c "grep -qE '^verdict: pass' '$VFILE'"
  # Event order: the first passing validation_verdict must precede the NEEDS_TESTING update
  check "verdict precedes NEEDS_TESTING"     sh -c "python3 -c \"
import json,sys
v=n=None
for line in open('$EVENTS'):
    try: e=json.loads(line)
    except: continue
    if v is None and e.get('event')=='validation_verdict' and e.get('issue')=='$ISS' and e.get('verdict')=='pass': v=e['ts']
    if n is None and e.get('event')=='task_update' and e.get('issue')=='$ISS' and e.get('status')=='NEEDS_TESTING': n=e['ts']
sys.exit(0 if v is not None and n is not None and v<=n else 1)\""
  TESTCMD=$(fm "$ROOT/kanban/$ISS.md" test_command)
  check "test_command set by builder"        sh -c "[ -n '$TESTCMD' ]"
  check "user-test card generated"           sh -c "ls '$ROOT'/kanban/user-test-cards/ | grep -qi '$ISS\\|hello'"
  check "builder filled Tests run"           sh -c "grep -A3 '## Tests run' '$ROOT/kanban/$ISS.md' | grep -q '\\[x\\]'"
  check "worktree committed (clean)"         sh -c "WT=\$(fm '$ROOT/kanban/$ISS.md' worktree); [ -n \"\$WT\" ] && [ -z \"\$(git -C \"\$WT\" status --porcelain)\" ]"
elif grep -qE '^verdict: fail' "$VFILE" 2>/dev/null; then
  check "every failure is classified"        sh -c "grep -qiE 'builder-defect|test-defect|ticket-underspecified|external' '$VFILE'"
  log "  MANUAL verdict=FAIL and no NEEDS_TESTING (correctly refused) — read $VFILE: the classification IS the diagnosis"; MANUAL=$((MANUAL+1))
else
  log "  FAIL   no NEEDS_TESTING within ${VALIDATE_TIMEOUT}s and no failing verdict to explain it"; FAIL=$((FAIL+1))
fi

log ""; log "════ 4. Store run history"
cp "$ROOT/kanban/$ISS.md" "$RUN_DIR/ticket.md" 2>/dev/null || true
cp "$VFILE" "$RUN_DIR/validation.md" 2>/dev/null || true
cp "$EVENTS" "$RUN_DIR/events.jsonl" 2>/dev/null || true
tmux capture-pane -pJ -t "$ISS" -S -3000 > "$RUN_DIR/builder-transcript.txt" 2>/dev/null || true
tmux capture-pane -pJ -t validator-agent -S -3000 > "$RUN_DIR/validator-transcript.txt" 2>/dev/null || true
log "Run stored: $RUN_DIR"
log "RESULT: $PASS passed, $FAIL failed, $MANUAL manual-review items"
[ "$FAIL" -eq 0 ]
