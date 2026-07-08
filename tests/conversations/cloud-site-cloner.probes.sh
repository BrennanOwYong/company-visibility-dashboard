# cloud-site-cloner.probes.sh — expectations for cloud-site-cloner.deck, sourced by the
# driver (scripts/test-pm-conversation.sh). Defines pre_<id> (baseline capture before send),
# probe_<id> (checks after the PM turn), wait_<id> (async checkpoints). Uses the driver's
# helpers: check, manual, wait_for, doc_has, doc_mtime, pm_saw, check_count, log, and paths
# DOC / EVENTS / ROOT. Probes assert on files, state, events, panes — never on vibes.

VERDICT_GLOB="$ROOT/knowledge/technical/feasibility/*.md"
SPEC_GLOB="$ROOT/knowledge/spec/*.md"
RESEARCH_GLOB="$ROOT/knowledge/technical/research/*.md"

# ── 1. capture per message ──────────────────────────────────────────────────────────────────
probe_1() {
  check "product.md created"                     test -s "$DOC"
  check "problem captured (whatsapp in doc)"     doc_has "whatsapp"
  check "no handoff fired"                       sh -c "! grep -q '\"event\": \"handoff\"' '$EVENTS' 2>/dev/null"
  manual "PM should reply with empathy in plain language and ask clarifying questions, not pitch tech"
}

pre_2()   { M2_BEFORE=$(doc_mtime); }
probe_2() {
  check "doc updated this turn"                  sh -c "[ \"\$(stat -c %Y '$DOC')\" -gt \"$M2_BEFORE\" ]"
  check "passing requirement captured"           sh -c "grep -qiE 'one.line|address|code' '$DOC'"
}

# ── 2. flow confirmed -> acceptance + dispatch ─────────────────────────────────────────────
pre_3()   { BASE_CHECKS=$(check_count); }
probe_3() {
  check "an acceptance contract exists"          sh -c "ls '$ROOT'/knowledge/contracts/acceptance/*.md"
  check "a feature reached feasibility_pending+" sh -c "pipeline-state list | grep -qE 'feasibility_(pending|ok|workaround)'"
  # the delegate event lands when the PM's spawn-agent call runs — wait, don't snapshot
  check "FEASIBILITY-CHECK dispatched"           wait_for 90 count_gt "$BASE_CHECKS"
  check "TS session spawned"                     tmux has-session -t technical-planning-agent
}

# ── 3. two-stage reply over the queue ──────────────────────────────────────────────────────
wait_A() {
  if ! wait_for 90 count_gt 0; then
    log "  FAIL   nothing was dispatched — skipping the rough-read wait"; FAIL=$((FAIL+1)); return
  fi
  if wait_for "$ROUGH_TIMEOUT" pm_got "FEASIBILITY-ROUGH"; then
    log "  PASS   rough read delivered to PM"; PASS=$((PASS+1))
    check "two-stage order: no verdict file at rough time" sh -c "! ls $VERDICT_GLOB 2>/dev/null | grep -q ."
  else
    log "  FAIL   no FEASIBILITY-ROUGH within ${ROUGH_TIMEOUT}s"; FAIL=$((FAIL+1))
  fi
}

wait_B() {
  if ! wait_for 90 count_gt 0; then
    log "  FAIL   nothing was dispatched — skipping the deep-verdict wait"; FAIL=$((FAIL+1)); return
  fi
  if wait_for "$DEEP_TIMEOUT" sh -c "ls $VERDICT_GLOB"; then
    log "  PASS   verdict file written"; PASS=$((PASS+1))
    check "draft spec written during deepen"     sh -c "grep -ql 'status: draft' $SPEC_GLOB"
    check "verdict file records assumptions"     sh -c "grep -qil 'assumption' $VERDICT_GLOB"
    check "per-technology research file written" sh -c "ls $RESEARCH_GLOB"
    check "stage advanced to ok/workaround"      sh -c "pipeline-state list | grep -qE 'feasibility_(ok|workaround)'"
    wait_for 300 pm_got "FEASIBILITY-RESULT" \
      && { log "  PASS   FEASIBILITY-RESULT delivered to PM"; PASS=$((PASS+1)); } \
      || { log "  FAIL   no FEASIBILITY-RESULT reached the PM"; FAIL=$((FAIL+1)); }
    check "RESULT carries assumptions inline"    sh -c "grep '\"to\": \"prd-agent\"' '$EVENTS' | grep FEASIBILITY-RESULT | grep -qi 'Assumptions'"
    check "PM ledgered the verdict in product.md" sh -c "grep -qi 'assumption' '$DOC'"
  else
    log "  FAIL   no deep verdict within ${DEEP_TIMEOUT}s"; FAIL=$((FAIL+1))
  fi
  SPEC_COUNT_AT_B=$(ls $SPEC_GLOB 2>/dev/null | wc -l)
}

# ── 4. minor change must NOT re-trigger ────────────────────────────────────────────────────
pre_4()   { BASE_CHECKS=$(check_count); M4_BEFORE=$(doc_mtime); }
probe_4() {
  check "doc updated"                            sh -c "[ \"\$(stat -c %Y '$DOC')\" -gt \"$M4_BEFORE\" ]"
  check "no new FEASIBILITY-CHECK"               count_eq "$BASE_CHECKS"
}

# ── 5. the infeasible ask ──────────────────────────────────────────────────────────────────
pre_5()   { BASE_CHECKS=$(check_count); }
probe_5() {
  check "captured in doc (asleep/lid)"           sh -c "grep -qiE 'asleep|lid' '$DOC'"
  check "new FEASIBILITY-CHECK dispatched"       wait_for 90 count_gt "$BASE_CHECKS"
  manual "PM must record the wish and dispatch — not lecture the user about sleep states itself"
}

# ── 6. premature handoff -> hook refusal ───────────────────────────────────────────────────
probe_6() {
  wait_for 120 sh -c "grep -q handoff_refused '$EVENTS'" \
    && { log "  PASS   handoff_refused event logged"; PASS=$((PASS+1)); } \
    || { log "  FAIL   no handoff_refused event"; FAIL=$((FAIL+1)); }
  check "no successful handoff event"            sh -c "! grep -q '\"event\": \"handoff\"' '$EVENTS'"
  manual "PM should relay the exact gap list to the user in plain terms"
}

# ── 7. blocked verdict, deep-only-if-feasible, PM pushback ─────────────────────────────────
wait_C() {
  if ! pipeline-state list 2>/dev/null | grep -qE 'feasibility_(pending|blocked)'; then
    log "  FAIL   no check in flight for the infeasible feature — skipping the blocked wait"; FAIL=$((FAIL+1)); return
  fi
  if wait_for "$DEEP_TIMEOUT" sh -c "grep -qil blocked $VERDICT_GLOB 2>/dev/null || pipeline-state list | grep -q feasibility_blocked"; then
    log "  PASS   blocked verdict recorded"; PASS=$((PASS+1))
    check "no spec built for the blocked feature (deep-only-if-feasible)" \
      sh -c "[ \"\$(ls $SPEC_GLOB 2>/dev/null | wc -l)\" -eq \"${SPEC_COUNT_AT_B:-1}\" ]"
    wait_for 300 pm_got "FEASIBILITY:" \
      && { log "  PASS   blocked report (FEASIBILITY:) reached the PM"; PASS=$((PASS+1)); } \
      || { log "  FAIL   blocked report never reached the PM"; FAIL=$((FAIL+1)); }
  else
    log "  FAIL   TS did not block the sleep feature within ${DEEP_TIMEOUT}s — it must push back"; FAIL=$((FAIL+1))
  fi
  sleep 10   # let the PM process the report before the user argues
}

pre_7()   { BASE_CHECKS=$(check_count); }
probe_7() {
  check "no re-dispatch while arguing"           count_eq "$BASE_CHECKS"
  manual "PM must NOT cave or promise it; explain in product terms; offer the cloud alternative"
}

pre_8()   { BASE_CHECKS=$(check_count); }
probe_8() {
  check "decision recorded in doc"               sh -c "grep -qi 'decision' '$DOC'"
  check "no new dispatch (verdict reuse)"        count_eq "$BASE_CHECKS"
}

# ── 8. finish, handoff passes ──────────────────────────────────────────────────────────────
probe_9() {
  wait_for "$HANDOFF_TIMEOUT" sh -c "grep -q '\"event\": \"handoff\"' '$EVENTS'" \
    && { log "  PASS   handoff event fired"; PASS=$((PASS+1)); } \
    || { log "  FAIL   no successful handoff within ${HANDOFF_TIMEOUT}s"; FAIL=$((FAIL+1)); }
  check "no feature left blocked/pending"        sh -c "! pipeline-state list | grep -qE 'feasibility_(blocked|pending)'"
  check "features marked handed_off"             sh -c "pipeline-state list | grep -q handed_off"
}

# ── 9. final coherence pass ────────────────────────────────────────────────────────────────
wait_D() {
  if wait_for "$PLAN_TIMEOUT" sh -c "test -s '$ROOT'/knowledge/architecture.md"; then
    log "  PASS   architecture.md written"; PASS=$((PASS+1))
    check "specs flipped to final"               sh -c "grep -ql 'status: final' $SPEC_GLOB"
    check "iface contracts written"              sh -c "ls '$ROOT'/knowledge/contracts/iface/*.md"
    check "architecture cites research files"    sh -c "grep -q 'technical/research' '$ROOT'/knowledge/architecture.md"
    wait_for 900 sh -c "ls '$ROOT'/kanban/iss-*.md 2>/dev/null | grep -q ." \
      && { log "  PASS   tickets emitted"; PASS=$((PASS+1)); } \
      || { log "  MANUAL tickets not seen yet — check the TS session"; MANUAL=$((MANUAL+1)); }
  else
    log "  FAIL   no architecture.md within ${PLAN_TIMEOUT}s"; FAIL=$((FAIL+1))
  fi
}
