#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git init --bare "$TMP/origin.git" >/dev/null
git clone "$TMP/origin.git" "$TMP/project" >/dev/null 2>&1
git -C "$TMP/project" config user.email factory@example.invalid
git -C "$TMP/project" config user.name Factory
git -C "$TMP/project" checkout -b main >/dev/null
mkdir -p "$TMP/project/kanban" "$TMP/project/bin"
printf 'base\n' > "$TMP/project/app.txt"
git -C "$TMP/project" add app.txt && git -C "$TMP/project" commit -m base >/dev/null
git -C "$TMP/project" push -u origin main >/dev/null
BASE=$(git -C "$TMP/project" rev-parse HEAD)
git -C "$TMP/project" worktree add -b feat/demo "$TMP/worktree" "$BASE" >/dev/null
printf 'feature\n' >> "$TMP/worktree/app.txt"
git -C "$TMP/worktree" add app.txt && git -C "$TMP/worktree" commit -m feature >/dev/null
CANDIDATE=$(git -C "$TMP/worktree" rev-parse HEAD)
cat > "$TMP/project/kanban/demo.md" <<EOF
---
issue: demo
title: Demo
status: NEEDS_USER_TESTING
repo: $TMP/project
worktree: $TMP/worktree
branch: feat/demo
audited_base: $BASE
candidate_commit: $CANDIDATE
feature_doc: docs/product/features/demo.md
architecture_doc: docs/architecture/features/demo.md
---
EOF
cp "$SOURCE/bin/ticket-integrate" "$SOURCE/bin/github-sync" "$TMP/project/bin/"
printf '#!/bin/bash\nexit 0\n' > "$TMP/project/bin/roadmap-sync"
printf '#!/bin/bash\nexit 0\n' > "$TMP/project/bin/kanban-dispatch"
printf '#!/bin/bash\nexit 0\n' > "$TMP/project/bin/factory-log"
printf '#!/bin/bash\nexit 0\n' > "$TMP/project/bin/factory-notify"
chmod +x "$TMP/project/bin/"*
mkdir -p "$TMP/fake-bin"
cat > "$TMP/fake-bin/gh" <<'SH'
#!/bin/bash
if [ "$1 $2" = "pr view" ]; then
  [ -n "${FACTORY_TEST_MERGED:-}" ] || exit 1
  printf '{"state":"MERGED","mergedAt":"now","mergeCommit":{"oid":"%s"}}\n' "$FACTORY_TEST_MERGED"
else
  echo 'https://github.example/pull/1'
fi
SH
chmod +x "$TMP/fake-bin/gh"
PATH="$TMP/fake-bin:$PATH" KANBAN_PROJECT_ROOT="$TMP/project" "$TMP/project/bin/ticket-integrate" demo >/dev/null
[ "$(git -C "$TMP/project" rev-parse main)" = "$BASE" ]
grep -q '^status: PR_OPEN$' "$TMP/project/kanban/demo.md"
[ "$(git --git-dir="$TMP/origin.git" rev-parse refs/heads/feat/demo)" = "$CANDIDATE" ]
git -C "$TMP/worktree" push origin feat/demo:main >/dev/null
PATH="$TMP/fake-bin:$PATH" FACTORY_TEST_MERGED="$CANDIDATE" KANBAN_PROJECT_ROOT="$TMP/project" "$TMP/project/bin/github-sync" >/dev/null
[ "$(git -C "$TMP/project" rev-parse main)" = "$CANDIDATE" ]
grep -q '^status: DONE$' "$TMP/project/kanban/demo.md"
echo 'GitHub PR lifecycle: PASS'
