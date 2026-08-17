#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d)
PORT=$((31000 + RANDOM % 10000))
PID=''
cleanup() { [ -n "$PID" ] && kill "$PID" 2>/dev/null || true; rm -rf "$ROOT"; }
trap cleanup EXIT
cp -r "$SOURCE/tests/fixtures/factory-project/." "$ROOT/"
mkdir -p "$ROOT/bin"
cp "$SOURCE/bin/roadmap-sync" "$ROOT/bin/"
KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/roadmap-sync" --root "$ROOT" --sync-kanban >/dev/null
sed -i 's/^status: .*/status: NEEDS_USER_TESTING/' "$ROOT/kanban/help-screen.md"
KANBAN_PROJECT_ROOT="$ROOT" KANBAN_UI_PORT="$PORT" node "$SOURCE/kanban-ui/server.js" >"$ROOT/ui.log" 2>&1 & PID=$!
for _ in $(seq 1 30); do curl -fsS "http://127.0.0.1:$PORT/user-tests" >"$ROOT/page" 2>/dev/null && break; sleep .1; done
grep -q 'Help screen' "$ROOT/page"
grep -q 'Test Me' "$ROOT/page"
curl -fsS "http://127.0.0.1:$PORT/" >"$ROOT/board"
grep -q 'href="/ticket/help-screen"' "$ROOT/board"
echo 'UX test selector: PASS'
