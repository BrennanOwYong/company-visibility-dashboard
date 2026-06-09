#!/bin/bash
# factory-init.sh — runs on every SessionStart hook
# If factory.json exists in CWD, initialises factory state and sets coordinator mode.

PROJECT_ROOT="$(pwd)"

if [ ! -f "$PROJECT_ROOT/factory.json" ]; then
  exit 0
fi

export PATH="$HOME/.claude/bin:$PATH"

# Write coordinator sentinel (tmux session name or fallback)
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "main")
echo "$SESSION" > ~/.claude/.coordinator
echo "$PROJECT_ROOT" > ~/.claude/.coordinator-root

# Core directories
mkdir -p "$PROJECT_ROOT/kanban/user-test-cards"
mkdir -p "$PROJECT_ROOT/knowledge/contracts"

# AGENTS.md
if [ ! -f "$PROJECT_ROOT/AGENTS.md" ]; then
  cat > "$PROJECT_ROOT/AGENTS.md" << 'AGENTS'
# Project Knowledge Base

Read this before building anything.

## Shared Modules

Format: [[module-name]] — what it does — instantiation: singleton|factory

(Populated during planning phase by coordinator.)

## Known Integrations

(Populated during planning phase.)

## Environment Variables

(Populated during pre-flight.)

## Rules

- Check this file before writing any new integration or module.
- If a module exists, use it.
- Add new reusable modules here when you create them.
- Use [[module-name]] syntax to link to module docs in knowledge/.
AGENTS
fi

# modules.json
if [ ! -f "$PROJECT_ROOT/modules.json" ]; then
  echo '{"modules":[],"integrations":[],"services":[]}' > "$PROJECT_ROOT/modules.json"
fi

# Install post-merge hook in every repo defined in factory.json
# Supports single-repo (factory root has .git) and multi-repo (repos field in factory.json)
install_hook() {
  local repo_path="$1"
  local abs_repo
  # Resolve relative paths against PROJECT_ROOT
  if [[ "$repo_path" = /* ]]; then
    abs_repo="$repo_path"
  else
    abs_repo="$PROJECT_ROOT/$repo_path"
  fi
  local hook="$abs_repo/.git/hooks/post-merge"
  if [ -d "$abs_repo/.git" ]; then
    cp "$HOME/.claude/bin/post-merge-hook.sh" "$hook"
    chmod +x "$hook"
    echo "  post-merge hook installed: $abs_repo"
  fi
}

# Single-repo case
if [ -d "$PROJECT_ROOT/.git" ]; then
  install_hook "$PROJECT_ROOT"
fi

# Multi-repo case: parse repos field from factory.json
REPOS=$(node -e "
  try {
    const f = require('$PROJECT_ROOT/factory.json');
    if (f.repos) Object.values(f.repos).forEach(p => console.log(p));
  } catch(e) {}
" 2>/dev/null || true)

while IFS= read -r repo_path; do
  [ -n "$repo_path" ] && install_hook "$repo_path"
done <<< "$REPOS"

echo "FACTORY ACTIVE | project: $(basename $PROJECT_ROOT) | coordinator: $SESSION"
echo "You are the coordinator for this project. Run pre-flight with the user on their first message."
echo "Pre-flight: clarify features needed, which repos each belongs in, tools/access required, GitHub repo (optional), then plan."
echo "Repos available: $(node -e "try{const f=require('$PROJECT_ROOT/factory.json');console.log(Object.keys(f.repos||{}).join(', '))}catch(e){console.log('(single-repo)')}" 2>/dev/null)"
