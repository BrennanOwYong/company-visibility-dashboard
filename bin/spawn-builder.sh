#!/bin/bash
# spawn-builder.sh <issue-name> <handoff-doc-path> [--repo <repo-root>] [--port <port>] [--depends-on <iss1,iss2>] [--feature <feature-name>]
# Creates a git worktree in the specified repo, kanban issue entry, and tmux session for a builder agent.
set -e

SCRIPT_DIR_SB="$(cd "$(dirname "$0")" && pwd)"

ISSUE=""
HANDOFF=""
PORT=""   # assigned later, at the NEEDS_TESTING transition — not at spawn
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

# Product code never builds into the factory tree itself — last time it tangled product
# files into the factory's own repo. The ticket's repo (or --repo) must point at the
# product's own git repo (convention: <project>/product, git-initialized before dispatch).
if [ "$REPO_ROOT" = "$PROJECT_ROOT" ] && [ -f "$PROJECT_ROOT/factory.json" ]; then
  echo "REFUSED: repo resolves to the factory project root ($PROJECT_ROOT)."
  echo "Point the ticket's repo: field (or --repo) at the product repo, e.g. $PROJECT_ROOT/product (git init it first)."
  exit 1
fi

WORKTREE_PATH="$(dirname "$REPO_ROOT")/worktrees/$ISSUE"

# Create git worktree inside the specified repo
git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" -b "feat/$ISSUE" 2>/dev/null || {
  echo "Worktree or branch already exists for: feat/$ISSUE"
  exit 1
}

KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/factory-log" branch_created issue="$ISSUE" branch="feat/$ISSUE"

# Copy context files into worktree
cp "$HANDOFF" "$WORKTREE_PATH/HANDOFF.md"
[ -f "$PROJECT_ROOT/AGENTS.md" ]    && cp "$PROJECT_ROOT/AGENTS.md"    "$WORKTREE_PATH/AGENTS.md"
[ -f "$PROJECT_ROOT/modules.json" ] && cp "$PROJECT_ROOT/modules.json" "$WORKTREE_PATH/modules.json"

# Copy contract files relevant to this issue — the per-edge contracts, the iface shapes
# they point to, and the planner's research docs the ticket links. The worktree lives in
# the PRODUCT repo, so nothing under the factory's knowledge/ is reachable from it.
if [ -d "$PROJECT_ROOT/knowledge/contracts" ]; then
  mkdir -p "$WORKTREE_PATH/knowledge/contracts"
  cp "$PROJECT_ROOT/knowledge/contracts/"*.md "$WORKTREE_PATH/knowledge/contracts/" 2>/dev/null || true
  [ -d "$PROJECT_ROOT/knowledge/contracts/iface" ] && \
    cp -r "$PROJECT_ROOT/knowledge/contracts/iface" "$WORKTREE_PATH/knowledge/contracts/iface" 2>/dev/null || true
fi
if [ -d "$PROJECT_ROOT/knowledge/technical/research" ]; then
  mkdir -p "$WORKTREE_PATH/knowledge/technical"
  cp -r "$PROJECT_ROOT/knowledge/technical/research" "$WORKTREE_PATH/knowledge/technical/research" 2>/dev/null || true
fi

# Copy lessons learned if present
[ -f "$PROJECT_ROOT/knowledge/lessons.md" ] && {
  mkdir -p "$WORKTREE_PATH/knowledge"
  cp "$PROJECT_ROOT/knowledge/lessons.md" "$WORKTREE_PATH/knowledge/lessons.md"
}

# The worktree is the builder session's project root, so project hooks must exist HERE.
# Reference the factory's hook by absolute path — the product worktree carries no bin/.
# (The busy/idle delivery hooks are user-level with absolute paths; only the ticket
# write-guard is project-level.)
mkdir -p "$WORKTREE_PATH/.claude"
cat > "$WORKTREE_PATH/.claude/settings.json" << SEOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Grep|Glob|Bash|Edit|Write|Task|Agent",
        "hooks": [
          { "type": "command", "command": "bash $PROJECT_ROOT/bin/hook-guard-ticket" }
        ]
      }
    ]
  }
}
SEOF

# Briefing copies are factory context, not product code — exclude them so the
# clean-worktree gate before NEEDS_TESTING doesn't trip on them and no builder
# commits factory files into the product repo.
mkdir -p "$REPO_ROOT/.git/info"
for p in HANDOFF.md AGENTS.md modules.json knowledge/ .claude/; do
  grep -qxF "$p" "$REPO_ROOT/.git/info/exclude" 2>/dev/null || echo "$p" >> "$REPO_ROOT/.git/info/exclude"
done

# Kanban issue: the architect may already have created it via kanban-create with the
# full roadmap data (deps, infra, intent, testing). Do not clobber it — create a minimal
# one only if missing, then fill the spawn-time fields.
mkdir -p "$PROJECT_ROOT/kanban/user-test-cards"
KFILE="$PROJECT_ROOT/kanban/$ISSUE.md"
if [ ! -f "$KFILE" ]; then
  KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/kanban-create" "$ISSUE" \
    --feature "$FEATURE_NAME" --repo "$REPO_ROOT" ${DEPENDS_ON:+--depends-on "$DEPENDS_ON"} >/dev/null
fi
# branch + worktree are always spawn-time; set repo only if the architect left it blank
sed -i "s|^branch:.*|branch: feat/$ISSUE|" "$KFILE"
sed -i "s|^worktree:.*|worktree: $WORKTREE_PATH|" "$KFILE"
CUR_REPO=$(grep "^repo:" "$KFILE" | sed 's/^repo:[[:space:]]*//')
[ -z "$CUR_REPO" ] && sed -i "s|^repo:.*|repo: $REPO_ROOT|" "$KFILE"

# Create tmux session. No FEATURE_PORT — a port is allocated when the ticket's
# validator boots (kanban-port) and read from the kanban file frontmatter.
# Builders run Sonnet (planning = Opus, execution = Sonnet); CLAUDE_CODE_SUBAGENT_MODEL
# is overridden per-session so the user-level setting cannot force a frontier model
# onto the builder's Task subagents.
tmux new-session -d -s "$ISSUE" -c "$WORKTREE_PATH" \
  -e "PATH=$PROJECT_ROOT/bin:$PATH" \
  -e "KANBAN_PROJECT_ROOT=$PROJECT_ROOT" \
  -e "FEATURE_NAME=$ISSUE" \
  -e "BUILDER_ISSUE=$ISSUE" \
  -e "CLAUDE_CODE_SUBAGENT_MODEL=${BUILDER_MODEL:-sonnet}"

tmux send-keys -t "$ISSUE" "${CLAUDE_BIN:-claude} --dangerously-skip-permissions --model ${BUILDER_MODEL:-sonnet}" Enter

# Bootstrap readiness: wait for the claude TUI to settle on first boot, then mark idle.
# This one-time settle covers boot only; steady-state readiness is hook-driven (Stop=idle).
sleep "${BUILDER_BOOT_SECONDS:-5}"
KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/agent-state" "$ISSUE" idle

# Deliver the first instruction through the delegator queue — never raw send-keys.
KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR_SB/tmux-delegate" "$ISSUE" \
  "Read HANDOFF.md, AGENTS.md, modules.json, knowledge/lessons.md, and every research doc your ticket links under knowledge/technical/research/ — the planner already researched your stack; read its findings instead of re-researching. Mark started with: kanban-update $ISSUE IN_PROGRESS \"starting\". Then build. Set up your own infra as part of the build (local services, integrations, tools); NEEDS_SETUP is the LAST resort, only for a credential/account/access that only the human holds. Test as you code. When your own tests pass, while still IN_PROGRESS spawn the independent validator: spawn-agent validator-agent \"VALIDATE: $ISSUE — <feature, one line>\" (your test port lands in the ticket frontmatter when it boots). Fix everything its VALIDATION-FAILED lists and re-request until it passes — kanban-update refuses NEEDS_TESTING without a passing verdict; NEEDS_TESTING holds only taste for the user."

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
