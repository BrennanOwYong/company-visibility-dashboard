#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if grep -q 'setInterval' "$ROOT/kanban-ui/server.js"; then
  echo 'event-driven UI test: polling timer found' >&2
  exit 1
fi
grep -q "req.url === '/webhooks/github'" "$ROOT/kanban-ui/server.js"
grep -q 'x-hub-signature-256' "$ROOT/kanban-ui/server.js"
grep -q "current.replaceWith(next)" "$ROOT/kanban-ui/server.js"
grep -q 'webhook head does not match validated candidate' "$ROOT/bin/github-webhook"
echo 'event-driven ticket updates: PASS'
