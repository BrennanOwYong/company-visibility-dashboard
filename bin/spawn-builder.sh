#!/bin/bash
# spawn-builder.sh <issue-name> <handoff-doc-path> [--repo <repo-root>] [--port <port>] [--depends-on <iss1,iss2>] [--feature <feature-name>]
# Creates a git worktree in the specified repo, kanban issue entry, and tmux session for a builder agent.
set -euo pipefail

SCRIPT_DIR_SB="$(cd "$(dirname "$0")" && pwd)"

ISSUE=""
HANDOFF=""
PORT=""   # assigned later, allocated when the validator boots — not at spawn
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

# One factory instance owns one project repository. Builders still work only in isolated worktrees.
WORKTREE_PATH="${FACTORY_WORKTREE_ROOT:-$(dirname "$REPO_ROOT")/worktrees}/$ISSUE"

# Create git worktree inside the specified repo
MAIN_BRANCH=main
git -C "$REPO_ROOT" fetch origin "$MAIN_BRANCH"
git -C "$REPO_ROOT" config core.hooksPath .githooks
[ "$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null)" = main ] || {
  echo "[$ISSUE] REFUSED: the visible project checkout must be on local main before dispatch"; exit 1;
}
if ! git -C "$REPO_ROOT" diff --quiet HEAD -- docs/product docs/architecture; then
  echo "[$ISSUE] REFUSED: planning documents must be committed on local main before dispatch"
  exit 1
fi
[ "$(git -C "$REPO_ROOT" rev-parse HEAD)" = "$(git -C "$REPO_ROOT" rev-parse origin/main)" ] || {
  echo "[$ISSUE] REFUSED: commit planning documents on local main and synchronize main with origin before dispatch"
  exit 1
}
DISPATCH_BASE=$(git -C "$REPO_ROOT" rev-parse "origin/$MAIN_BRANCH")
git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" -b "feat/$ISSUE" "$DISPATCH_BASE" 2>/dev/null || {
  echo "Worktree or branch already exists for: feat/$ISSUE"
  exit 1
}
git -C "$WORKTREE_PATH" push -u origin "feat/$ISSUE"

KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/factory-log" branch_created issue="$ISSUE" branch="feat/$ISSUE"

# The planner and roadmap compiler must create the thin ticket before dispatch.
mkdir -p "$PROJECT_ROOT/kanban/user-test-cards"
KFILE="$PROJECT_ROOT/kanban/$ISSUE.md"
[ -f "$KFILE" ] || { echo "[$ISSUE] missing roadmap-generated ticket; run roadmap-sync --sync-kanban"; exit 1; }
# branch + worktree are always spawn-time; set repo only if the architect left it blank
sed -i "s|^branch:.*|branch: feat/$ISSUE|" "$KFILE"
sed -i "s|^worktree:.*|worktree: $WORKTREE_PATH|" "$KFILE"
sed -i "s|^dispatch_base:.*|dispatch_base: $DISPATCH_BASE|" "$KFILE"
CUR_REPO=$(grep "^repo:" "$KFILE" | sed 's/^repo:[[:space:]]*//')
[ -z "$CUR_REPO" ] && sed -i "s|^repo:.*|repo: $REPO_ROOT|" "$KFILE"

KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/spawn-role" \
  --role builder --session "$ISSUE" --ticket "$ISSUE" --cwd "$WORKTREE_PATH" \
  --model "${BUILDER_MODEL:-gpt-5.6-luna}" \
  --message "Build ticket $ISSUE. Read its context manifest and linked sources. Signal READY_FOR_TESTING only after committed code, observability, self-tests, and module documentation are pushed."

KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/kanban-update" "$ISSUE" IN_PROGRESS "builder handoff acknowledged"

KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/factory-log" task_dispatched issue="$ISSUE" feature="$FEATURE_NAME"

echo ""
echo "Builder spawned: $ISSUE"
echo "  Feature    : $FEATURE_NAME"
echo "  Worktree   : $WORKTREE_PATH"
echo "  Branch     : feat/$ISSUE"
echo "  Repo       : $REPO_ROOT"
echo "  Port       : ${PORT:-(assigned at testing)}"
echo "  DependsOn  : ${DEPENDS_ON:-(none)}"
echo "  Kanban     : $PROJECT_ROOT/kanban/$ISSUE.md"
echo "  Watch      : tmux attach -t $ISSUE"
