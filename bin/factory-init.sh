#!/bin/bash
# factory-init.sh — runs on every SessionStart hook
# Bootstraps factory coordinator mode for a HUMAN-DRIVEN session. Spawned agent sessions
# skip it: a builder booting in its worktree must not scaffold factory files there (they
# would dirty the product repo), and neither builders nor planning agents may overwrite
# the coordinator sentinels — every ping would route to the last-booted agent.

PROJECT_ROOT="$(pwd)"

if [ -n "$BUILDER_ISSUE" ]; then
  echo "FACTORY ACTIVE | builder session: $BUILDER_ISSUE (init skipped — worktree stays clean)"
  exit 0
fi

if [ -z "$FACTORY_AGENT" ] && [ ! -f "$PROJECT_ROOT/factory.json" ]; then
  printf '{"project":"%s","repos":{}}\n' "$(basename "$PROJECT_ROOT")" > "$PROJECT_ROOT/factory.json"
fi

# Directory containing this script — works whether run from bundle or ~/.claude/bin
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"

export PATH="$SCRIPT_DIR:$PATH"

# The whole system invokes these scripts bare by name via PATH; ensure they are
# executable even if the checkout dropped the exec bit.
chmod +x "$SCRIPT_DIR"/* 2>/dev/null || true

# Add script dir to ~/.bashrc so builders launched in new shells also find the scripts
if ! grep -qF "$SCRIPT_DIR" "$HOME/.bashrc" 2>/dev/null; then
  echo "export PATH=\"$SCRIPT_DIR:\$PATH\" # claude-factory" >> "$HOME/.bashrc"
fi

# Install all repo skills so agents can invoke them (kanban, roadmap-and-branching, ...)
for SKILL_DIR in "$SCRIPT_DIR/../skills/"*/; do
  [ -d "$SKILL_DIR" ] || continue
  SKILL_NAME=$(basename "$SKILL_DIR")
  mkdir -p "$HOME/.claude/skills/$SKILL_NAME"
  cp "$SKILL_DIR/SKILL.md" "$HOME/.claude/skills/$SKILL_NAME/SKILL.md" 2>/dev/null || true
done

# Install /hi global slash command
mkdir -p "$HOME/.claude/commands"
cp "$SCRIPT_DIR/../.claude/commands/hi.md" "$HOME/.claude/commands/hi.md" 2>/dev/null || true

# Install user-level readiness hooks so every factory agent reports when it is
# done talking (Stop) or busy (UserPromptSubmit). Guarded: the hook scripts no-op
# outside an active factory tmux session, so other Claude sessions are unaffected.
# Merge into ~/.claude/settings.json without clobbering existing hooks (idempotent).
node -e '
  const fs=require("fs"), os=require("os"), path=require("path");
  const f=path.join(os.homedir(),".claude","settings.json");
  let s={}; try{ s=JSON.parse(fs.readFileSync(f,"utf8")) }catch(e){}
  s.hooks=s.hooks||{};
  const dir=process.argv[1];
  function ensure(event,script){
    s.hooks[event]=s.hooks[event]||[];
    if(JSON.stringify(s.hooks[event]).includes(script)) return;
    s.hooks[event].push({hooks:[{type:"command",command:"bash "+path.join(dir,script)}]});
  }
  ensure("Stop","hook-agent-idle");
  ensure("UserPromptSubmit","hook-agent-busy");
  fs.mkdirSync(path.dirname(f),{recursive:true});
  fs.writeFileSync(f, JSON.stringify(s,null,2));
' "$SCRIPT_DIR" 2>/dev/null || true

# Write coordinator sentinel (tmux session name or fallback). Spawned agents never do —
# the coordinator is the human-driven session, and the sentinel must keep naming it.
if [ -z "$FACTORY_AGENT" ]; then
  SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "main")
  echo "$SESSION" > ~/.claude/.coordinator
  echo "$PROJECT_ROOT" > ~/.claude/.coordinator-root

  # Seed the coordinator's own readiness so builder pings can reach it
  KANBAN_PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR/agent-state" "$SESSION" idle
fi

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
    cp "$SCRIPT_DIR/post-merge-hook.sh" "$hook"
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

# Onboarding message. Only shown for a default (no-agent) session; spawned agent
# sessions (--agent ...) carry their own prompt and run autonomously.
AGENT_TYPE=""
[ ! -t 0 ] && AGENT_TYPE=$(cat 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('agent_type','') or '')" 2>/dev/null)

echo "FACTORY ACTIVE | project: $(basename $PROJECT_ROOT)"
if [ -z "$AGENT_TYPE" ]; then
  echo ""
  echo "Welcome to the software factory. How this works:"
  echo "  1. Type /hi to begin. I become your Product Manager and gather your"
  echo "     requirements through a short conversation (saved to knowledge/prd/)."
  echo "  2. Once you confirm them, I hand off to the technical planner, which"
  echo "     designs the plan and creates the tickets and feature branches."
  echo ""
  echo "[assistant] Greet the user in one or two sentences and tell them to type /hi to start."
  echo "Do not gather requirements or act as coordinator until they run /hi."
fi
