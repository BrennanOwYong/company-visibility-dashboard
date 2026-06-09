#!/bin/bash
# spawn-builder.sh <issue-name> <handoff-doc-path> [--repo <repo-root>] [--port <port>] [--depends-on <iss1,iss2>] [--feature <feature-name>]
# Creates a git worktree in the specified repo, kanban issue entry, and tmux session for a builder agent.
set -e

ISSUE=""
HANDOFF=""
PORT="3001"
REPO_ROOT=""
DEPENDS_ON=""
FEATURE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO_ROOT="$2";    shift 2;;
    --port)        PORT="$2";         shift 2;;
    --depends-on)  DEPENDS_ON="$2";   shift 2;;
    --feature)     FEATURE_NAME="$2"; shift 2;;
    *)
      if [ -z "$ISSUE" ];   then ISSUE="$1"
      elif [ -z "$HANDOFF" ]; then HANDOFF="$1"
      fi
      shift;;
  esac
done

PROJECT_ROOT="$(pwd)"
REPO_ROOT="${REPO_ROOT:-$PROJECT_ROOT}"
FEATURE_NAME="${FEATURE_NAME:-$ISSUE}"

if [ -z "$ISSUE" ] || [ -z "$HANDOFF" ]; then
  echo "Usage: spawn-builder.sh <issue-name> <handoff-doc-path> [--repo <path>] [--port <port>] [--depends-on <iss1,iss2>] [--feature <name>]"
  exit 1
fi

if [ ! -f "$HANDOFF" ]; then
  echo "Handoff doc not found: $HANDOFF"
  exit 1
fi

if [ ! -d "$REPO_ROOT/.git" ]; then
  echo "No .git found in repo root: $REPO_ROOT"
  echo "Run git init or specify a valid --repo path."
  exit 1
fi

WORKTREE_PATH="$(dirname "$REPO_ROOT")/worktrees/$ISSUE"

# Create git worktree inside the specified repo
git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" -b "feat/$ISSUE" 2>/dev/null || {
  echo "Worktree or branch already exists for: feat/$ISSUE"
  exit 1
}

# Copy context files into worktree
cp "$HANDOFF" "$WORKTREE_PATH/HANDOFF.md"
[ -f "$PROJECT_ROOT/AGENTS.md" ]    && cp "$PROJECT_ROOT/AGENTS.md"    "$WORKTREE_PATH/AGENTS.md"
[ -f "$PROJECT_ROOT/modules.json" ] && cp "$PROJECT_ROOT/modules.json" "$WORKTREE_PATH/modules.json"

# Copy contract files relevant to this issue
if [ -d "$PROJECT_ROOT/knowledge/contracts" ]; then
  mkdir -p "$WORKTREE_PATH/knowledge/contracts"
  cp "$PROJECT_ROOT/knowledge/contracts/"*.md "$WORKTREE_PATH/knowledge/contracts/" 2>/dev/null || true
fi

# Copy lessons learned if present
[ -f "$PROJECT_ROOT/knowledge/lessons.md" ] && {
  mkdir -p "$WORKTREE_PATH/knowledge"
  cp "$PROJECT_ROOT/knowledge/lessons.md" "$WORKTREE_PATH/knowledge/lessons.md"
}

# Create kanban issue entry
mkdir -p "$PROJECT_ROOT/kanban/user-test-cards"
cat > "$PROJECT_ROOT/kanban/$ISSUE.md" << EOF
---
issue: $ISSUE
feature: $FEATURE_NAME
port: $PORT
repo: $REPO_ROOT
status: IN_PROGRESS
branch: feat/$ISSUE
worktree: $WORKTREE_PATH
dependsOn: $DEPENDS_ON
user_facing: true
test_command:
---

## What was built
(builder fills this in)

## How it works
(builder fills this in)

## Tests run
(builder fills this in — use - [x] format)

## Lessons learned
(builder fills this in — non-obvious discoveries only: API shapes, env gotchas, workarounds)

## Blocked on
(none)

## Feedback from user
(none)
EOF

# Create tmux session
tmux new-session -d -s "$ISSUE" -c "$WORKTREE_PATH" \
  -e "KANBAN_PROJECT_ROOT=$PROJECT_ROOT" \
  -e "FEATURE_NAME=$ISSUE" \
  -e "FEATURE_PORT=$PORT"

tmux send-keys -t "$ISSUE" "claude --dangerously-skip-permissions" Enter
sleep 4
tmux send-keys -t "$ISSUE" "Read HANDOFF.md, AGENTS.md, modules.json, and knowledge/lessons.md. Then start building. Update kanban via: kanban-update $ISSUE <STATUS> <notes>" Enter

echo ""
echo "Builder spawned: $ISSUE"
echo "  Feature    : $FEATURE_NAME"
echo "  Worktree   : $WORKTREE_PATH"
echo "  Branch     : feat/$ISSUE"
echo "  Repo       : $REPO_ROOT"
echo "  Port       : $PORT"
echo "  DependsOn  : ${DEPENDS_ON:-(none)}"
echo "  Kanban     : $PROJECT_ROOT/kanban/$ISSUE.md"
echo "  Watch      : tmux attach -t $ISSUE"
