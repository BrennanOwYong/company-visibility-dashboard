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

if [ "$STATUS" = "COMPLETE" ]; then
  CARD="$KANBAN_ROOT/kanban/user-test-cards/$MERGED_BRANCH-card.md"
  [ ! -f "$CARD" ] && KANBAN_PROJECT_ROOT="$KANBAN_ROOT" kanban-generate-card "$MERGED_BRANCH"
  tmux send-keys -t "$COORDINATOR" \
    "[$MERGED_BRANCH] merged. Status: COMPLETE. User test card at $CARD" Enter
else
  tmux send-keys -t "$COORDINATOR" \
    "[$MERGED_BRANCH] merged. Status: $STATUS" Enter
fi
