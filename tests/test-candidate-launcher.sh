#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
ROOT="$TMP/project"
WORKTREE="$TMP/candidate"
UI_PORT=$((31000 + RANDOM % 5000))
UI_PID=''
APP_PID=''
cleanup() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null || true
  [ -n "$UI_PID" ] && kill "$UI_PID" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

cp -r "$SOURCE/tests/fixtures/factory-project" "$ROOT"
mkdir -p "$ROOT/bin"
cp "$SOURCE/bin/roadmap-sync" "$ROOT/bin/"
cat >"$ROOT/bin/project-dev" <<'SH'
#!/bin/bash
printf 'main\n' >"$PROJECT_TEST_MARKER"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
SH
chmod +x "$ROOT/bin/project-dev"
git -C "$ROOT" init -q
git -C "$ROOT" config user.name test
git -C "$ROOT" config user.email test@example.invalid
git -C "$ROOT" add .
git -C "$ROOT" commit -qm main
git -C "$ROOT" branch -M main
git -C "$ROOT" worktree add -qb candidate "$WORKTREE"
sed -i "s/printf 'main/printf 'candidate/" "$WORKTREE/bin/project-dev"
git -C "$WORKTREE" add bin/project-dev
git -C "$WORKTREE" commit -qm candidate
CANDIDATE=$(git -C "$WORKTREE" rev-parse HEAD)

KANBAN_PROJECT_ROOT="$ROOT" "$ROOT/bin/roadmap-sync" --root "$ROOT" --sync-kanban >/dev/null
TICKET="$ROOT/kanban/account-screen.md"
sed -i "s#^repo:.*#repo: $ROOT#; s#^worktree:.*#worktree: $WORKTREE#; s#^candidate_commit:.*#candidate_commit: $CANDIDATE#" "$TICKET"

PROJECT_TEST_MARKER="$TMP/marker" KANBAN_PROJECT_ROOT="$ROOT" KANBAN_UI_PORT="$UI_PORT" \
  node "$SOURCE/kanban-ui/server.js" >"$TMP/ui.log" 2>&1 & UI_PID=$!
for _ in $(seq 1 50); do
  curl -fsS "http://127.0.0.1:$UI_PORT/" >/dev/null 2>&1 && break
  sleep .1
done
curl -fsS -X POST -H 'Content-Type: application/json' -d '{"issue":"account-screen"}' \
  "http://127.0.0.1:$UI_PORT/launch" >"$TMP/result.json"
grep -q '"ok":true' "$TMP/result.json"
grep -qx candidate "$TMP/marker"
APP_PID=$(python3 -c "import json; print(json.load(open('$ROOT/.factory/runtime/environments/account-screen.json'))['pid'])")
echo 'validated candidate launcher identity: PASS'
