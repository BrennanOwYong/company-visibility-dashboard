#!/bin/bash
# post-merge hook — fires after git merge in a builder repo
# Detects which feature branch was just merged and pings coordinator.
# Install to: <repo>/.git/hooks/post-merge

COORDINATOR=$(cat ~/.claude/.coordinator 2>/dev/null)
[ -z "$COORDINATOR" ] && exit 0

# Get the branch that was just merged (MERGE_HEAD exists during a merge)
MERGED_BRANCH=$(git log --merges -1 --format="%s" 2>/dev/null | grep -oP "feat/\K[^'\" ]+" || true)

# Fallback: check what branch ORIG_HEAD was on
if [ -z "$MERGED_BRANCH" ]; then
  MERGED_BRANCH=$(git name-rev --name-only ORIG_HEAD 2>/dev/null | sed 's|feat/||' | sed 's|remotes/origin/feat/||' || true)
fi

[ -z "$MERGED_BRANCH" ] && exit 0

# Resolve KANBAN_PROJECT_ROOT from .coordinator file or env
KANBAN_ROOT=$(cat ~/.claude/.coordinator-root 2>/dev/null || echo "")
[ -z "$KANBAN_ROOT" ] && exit 0

KANBAN_FILE="$KANBAN_ROOT/kanban/$MERGED_BRANCH.md"
[ ! -f "$KANBAN_FILE" ] && exit 0

STATUS=$(grep "^status:" "$KANBAN_FILE" | awk '{print $2}')

if [ "$STATUS" = "DONE" ]; then
  KANBAN_PROJECT_ROOT="$KANBAN_ROOT" tmux-delegate "$COORDINATOR" \
    "[$MERGED_BRANCH] merged and integrated. Status: DONE."
else
  KANBAN_PROJECT_ROOT="$KANBAN_ROOT" tmux-delegate "$COORDINATOR" \
    "[$MERGED_BRANCH] merged. Status: $STATUS"
fi

# A landed branch can make coupled tickets ready (their dep is merged) — recompute the
# ready-set and dispatch whatever became buildable. Idempotent; safe to fire every merge.
KANBAN_PROJECT_ROOT="$KANBAN_ROOT" kanban-dispatch >/dev/null 2>&1 || true
