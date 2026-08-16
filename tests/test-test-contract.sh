#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d)
cleanup() { rm -rf "$ROOT"; }
trap cleanup EXIT
cp -r "$SOURCE/tests/fixtures/factory-project/." "$ROOT/"
mkdir -p "$ROOT/bin"
cp "$SOURCE/bin/roadmap-sync" "$ROOT/bin/"
KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/roadmap-sync" --root "$ROOT" --sync-kanban >/dev/null
TICKET="$ROOT/kanban/account-screen.md"
grep -qx 'test_check: bin/project-test' "$TICKET"
grep -qx 'test_launcher: bin/project-dev' "$TICKET"
grep -qx 'test_check_args: \[\]' "$TICKET"
grep -qx 'test_launcher_args: \[\]' "$TICKET"
if grep -q '^test_command:' "$TICKET"; then
  echo 'legacy ambiguous test_command is present' >&2
  exit 1
fi
echo 'separate check and launcher contract: PASS'
