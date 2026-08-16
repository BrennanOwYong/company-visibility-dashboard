#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
cp -r "$SOURCE/tests/fixtures/factory-project/." "$ROOT/"
mkdir -p "$ROOT/bin"
cp "$SOURCE/bin/roadmap-sync" "$SOURCE/bin/criterion-audit" "$ROOT/bin/"
KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/roadmap-sync" --root "$ROOT" --sync-kanban >/dev/null
if KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/criterion-audit" account-screen record DC-01 PASS \
  --kind browser --test 'positive account journey' --journey positive --evidence screenshot.png --events account.loaded 2>/dev/null; then
  echo "browser evidence without steps was accepted" >&2; exit 1
fi
KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/criterion-audit" account-screen record DC-01 PASS \
  --kind browser --test 'positive and negative account journeys' --journey positive --journey negative --steps 'open account -> details visible; unavailable -> retry visible' \
  --evidence screenshot.png --events account.loaded >/dev/null
KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/criterion-audit" account-screen finalize >/dev/null
grep -q '| DC-01 | PASS | browser |' "$ROOT/kanban/audit/account-screen-criteria.md"
echo 'browser criterion evidence: PASS'
