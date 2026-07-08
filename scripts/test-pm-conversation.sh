#!/bin/bash
# test-pm-conversation.sh [deck] — deck-driven LIVE conversation test of the PM (prd-agent)
# and technical planner. Default deck: tests/conversations/cloud-site-cloner.deck.
#
# The DECK is the fixed input data (TAB-separated: TYPE ID EXPECT TEXT) so the same
# conversation can be replayed run after run to test pipeline adherence. The sibling
# <deck>.probes.sh defines the expectations as functions: pre_<id> (baseline capture before
# sending), probe_<id> (checks after the PM's turn), wait_<id> (async checkpoints). Objective
# checks -> PASS/FAIL; judgment checks -> MANUAL with the PM's reply captured for review.
#
# RUN HISTORY — every run stores its full record under:
#   kanban/test-runs/<deck-name>/<YYYYmmdd-HHMMSS>/
#     run.log             annotated conversation: every message, its EXPECT tag, every check
#     pm-transcript.txt   full PM tmux pane
#     ts-transcript.txt   full planner tmux pane
#     events.jsonl        the agent-events stream for this run
#     knowledge/          snapshot of everything the agents wrote
# Compare two runs of the same deck:
#   diff <(grep -oE '(PASS|FAIL|MANUAL).*' A/run.log) <(grep -oE '(PASS|FAIL|MANUAL).*' B/run.log)
#
# Runs in the factory repo root (runtime state is gitignored; busy/idle hooks resolve the root
# via ~/.claude/.coordinator-root). WIPES runtime state at start. Real opus agents + web
# research: budget 30-90 minutes. The final stage is a real handoff: the planner will emit
# tickets and kanban-dispatch will spawn REAL builders — kill their tmux sessions if unwanted.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export KANBAN_PROJECT_ROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"

DECK="${1:-$ROOT/tests/conversations/cloud-site-cloner.deck}"
PROBES="${DECK%.deck}.probes.sh"
[ -f "$DECK" ]   || { echo "deck not found: $DECK"; exit 1; }
[ -f "$PROBES" ] || { echo "probes not found: $PROBES"; exit 1; }

TURN_TIMEOUT="${TURN_TIMEOUT:-420}"
ROUGH_TIMEOUT="${ROUGH_TIMEOUT:-900}"
DEEP_TIMEOUT="${DEEP_TIMEOUT:-2400}"
HANDOFF_TIMEOUT="${HANDOFF_TIMEOUT:-900}"
PLAN_TIMEOUT="${PLAN_TIMEOUT:-3600}"

DECK_NAME="$(basename "$DECK" .deck)"
RUN_DIR="$ROOT/kanban/test-runs/$DECK_NAME/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"
RUN_LOG="$RUN_DIR/run.log"
STATE_F="$ROOT/kanban/agents/prd-agent.state"
EVENTS="$ROOT/kanban/agent-events.jsonl"
DOC="$ROOT/knowledge/prd/product.md"
PASS=0; FAIL=0; MANUAL=0

log()     { printf '%s\n' "$*" | tee -a "$RUN_LOG"; }
pm_pane() { tmux capture-pane -pJ -t prd-agent -S -3000 2>/dev/null; }
ts_pane() { tmux capture-pane -pJ -t technical-planning-agent -S -3000 2>/dev/null; }

check() { # check <desc> <cmd...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then log "  PASS   $desc"; PASS=$((PASS+1))
  else                          log "  FAIL   $desc"; FAIL=$((FAIL+1)); fi
}
manual() { # manual <desc> — logs the PM reply tail for human judgment
  log "  MANUAL $1 — review the PM reply below:"
  pm_pane | tail -25 | sed 's/^/  | /' | tee -a "$RUN_LOG" >/dev/null
  MANUAL=$((MANUAL+1))
}
wait_for() { # wait_for <timeout_s> <cmd...> -> 0 on success, 1 on timeout
  local t="$1"; shift; local start; start=$(date +%s)
  until "$@" >/dev/null 2>&1; do
    sleep 5
    if [ $(( $(date +%s) - start )) -ge "$t" ]; then return 1; fi
  done
  return 0   # explicit: a while/until loop otherwise returns the last BODY command's status
}

doc_has()   { grep -qi "$1" "$DOC" 2>/dev/null; }
doc_mtime() { stat -c %Y "$DOC" 2>/dev/null || echo 0; }
pm_saw()    { pm_pane | grep -qF "$1"; }
check_count() { # cumulative FEASIBILITY-CHECK dispatches, from the durable delegate events
  # (pane text scrolls/collapses and inbox lines pop on delivery — both lie; events don't)
  grep '"event": "delegate"' "$EVENTS" 2>/dev/null | grep '"to": "technical-planning-agent"' \
    | grep -c "FEASIBILITY-CHECK" || true
}
pm_got() { # pm_got <prefix> — did any agent delegate a message with this prefix to the PM?
  grep '"event": "delegate"' "$EVENTS" 2>/dev/null | grep '"to": "prd-agent"' | grep -qF "$1"
}
count_gt() { [ "$(check_count)" -gt "$1" ]; }   # functions are invisible inside sh -c —
count_eq() { [ "$(check_count)" -eq "$1" ]; }   # probes must call these directly via wait_for/check

send() { # send <id> <expect> <message> — deliver, wait for the PM turn to finish
  local id="$1" expect="$2" msg="$3"
  local snippet; snippet=$(printf '%s' "$msg" | cut -c1-40)
  local inbox="$ROOT/kanban/inbox/prd-agent.jsonl"
  log ""; log "════ MSG $id  [EXPECT: $expect]"; log "USER> $msg"
  tmux-delegate prd-agent "$msg" >/dev/null
  # Submission signal: OUR line has left the inbox AND the PM is busy (UserPromptSubmit hook).
  # Pane text is NOT a submission signal — send-keys shows the text in the input box before
  # Enter lands, which once let every probe run mid-turn against a still-idle state file.
  if ! wait_for 240 sh -c "! grep -qF \"\$0\" '$inbox' 2>/dev/null && [ \"\$(cat '$STATE_F' 2>/dev/null)\" = busy ]" "$snippet"; then
    log "  FAIL   message never submitted to the PM (queue stuck?)"; FAIL=$((FAIL+1)); return 1
  fi
  # Turn completion: state returns to idle via the Stop hook.
  if ! wait_for "$TURN_TIMEOUT" sh -c "[ \"\$(cat '$STATE_F' 2>/dev/null)\" = idle ]"; then
    log "  FAIL   PM turn did not finish within ${TURN_TIMEOUT}s"; FAIL=$((FAIL+1)); return 1
  fi
  return 0
}

# ─── reset the runtime ground ──────────────────────────────────────────────────────────────
COORD_ROOT=$(cat "$HOME/.claude/.coordinator-root" 2>/dev/null)
if [ "$COORD_ROOT" != "$ROOT" ]; then
  echo "ABORT: ~/.claude/.coordinator-root is '$COORD_ROOT', not this repo — busy/idle hooks would write elsewhere."
  echo "Run bin/factory-init.sh from the repo root first."; exit 1
fi

log "Deck: $DECK_NAME  |  Run: $RUN_DIR"
log "Wiping runtime state and killing agent sessions..."
for s in prd-agent technical-planning-agent; do tmux kill-session -t "$s" 2>/dev/null; done
rm -rf "$ROOT"/knowledge/prd "$ROOT"/knowledge/technical/feasibility "$ROOT"/knowledge/spec \
       "$ROOT"/knowledge/contracts/acceptance "$ROOT"/knowledge/contracts/iface \
       "$ROOT"/knowledge/pipeline.json "$ROOT"/knowledge/architecture.md \
       "$ROOT"/knowledge/build-plan.md "$ROOT"/knowledge/_PLAN_BLOCKED.md \
       "$ROOT"/kanban/inbox "$ROOT"/kanban/agents
: > "$EVENTS" 2>/dev/null || true

# shellcheck source=/dev/null
. "$PROBES"

spawn-agent prd-agent >/dev/null
log "PM session up. Playing the deck."

# ─── play the deck ─────────────────────────────────────────────────────────────────────────
while IFS=$'\t' read -r -u 3 type id expect text; do
  case "$type" in ''|'#'*) continue;; esac
  case "$type" in
    SEND)
      declare -F "pre_$id" >/dev/null && "pre_$id"
      send "$id" "$expect" "$text" || true
      declare -F "probe_$id" >/dev/null && "probe_$id"
      ;;
    WAIT)
      log ""; log "════ WAIT-$id  [EXPECT: $expect]"
      if declare -F "wait_$id" >/dev/null; then "wait_$id"
      else log "  FAIL   deck names WAIT-$id but $PROBES defines no wait_$id"; FAIL=$((FAIL+1)); fi
      ;;
    *) log "  FAIL   unknown deck record type '$type' (id $id)"; FAIL=$((FAIL+1));;
  esac
done 3< "$DECK"

# ─── store the run history ─────────────────────────────────────────────────────────────────
pm_pane > "$RUN_DIR/pm-transcript.txt" 2>/dev/null
ts_pane > "$RUN_DIR/ts-transcript.txt" 2>/dev/null
cp "$EVENTS" "$RUN_DIR/events.jsonl" 2>/dev/null || true
cp -r "$ROOT/knowledge" "$RUN_DIR/knowledge" 2>/dev/null || true
log ""
log "Run stored: $RUN_DIR"
log "RESULT: $PASS passed, $FAIL failed, $MANUAL manual-review items"
log "(agents left running for inspection; a rerun wipes live state, the run dir is permanent)"
[ "$FAIL" -eq 0 ]
