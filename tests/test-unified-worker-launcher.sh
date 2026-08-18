#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
grep -q 'spawn-role' "$ROOT/bin/spawn-builder.sh"
grep -q 'spawn-role' "$ROOT/bin/spawn-validator"
grep -q 'spawn-role' "$ROOT/bin/spawn-agent"
grep -q 'runtime/agents' "$ROOT/bin/agent-state"
grep -q 'runtime/inbox' "$ROOT/bin/tmux-delegate"
grep -q 'runtime/inbox' "$ROOT/bin/inbox-drain"
if rg -q 'BOOT_DEADLINE|BUILDER_BOOT_SECONDS|codex --dangerously' \
  "$ROOT/bin/spawn-builder.sh" "$ROOT/bin/spawn-validator" "$ROOT/bin/spawn-agent"; then
  echo 'unified worker launcher: duplicate bootstrap logic found' >&2
  exit 1
fi
grep -q 'SessionStart readiness proof' "$ROOT/bin/spawn-role"
grep -q 'factory-\$ROLE.toml' "$ROOT/bin/spawn-role"
if FACTORY_ROLE=builder python3 "$ROOT/.codex/hooks/requirements_guard.py" <<<'{"tool_input":{"patch":"*** Update File: docs/product/PRD.md"}}' | grep -q 'permissionDecision'; then :; else
  echo 'unified worker launcher: product document guard missed apply_patch input' >&2; exit 1
fi
grep -A2 "prerequisite.*has no ticket" "$ROOT/bin/kanban-dispatch" | grep -q 'return 1'
echo 'unified worker launcher: PASS'
