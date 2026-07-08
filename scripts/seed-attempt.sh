#!/bin/bash
# seed-attempt.sh <N> <short-name> [--from <stage>]
# Creates a disposable SISTER test folder ../attempt_<N>_<short-name>/ seeded with the
# frozen phase-1 fixture, per the test-isolation directive: attempts never run in-place.
#
# Seeds: factory tooling (bin, .claude, skills, templates, CLAUDE.md, PIPELINE.md) and the
# frozen requirements fixture (prd, acceptance contracts, feasibility verdicts, specs,
# architecture, iface contracts, research). kanban/ starts EMPTY — the roadmap phase under
# test creates the tickets. A dedicated product repo is git-initialized at <attempt>/product;
# spawn-builder refuses anything else.
#
# Run the attempt with KANBAN_PROJECT_ROOT pointed at the attempt dir:
#   KANBAN_PROJECT_ROOT=<attempt> <attempt>/bin/handoff-to-planner     # roadmap phase
#   KANBAN_PROJECT_ROOT=<attempt> <attempt>/bin/factory-watch          # observe
set -e

FACTORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="$1"; NAME="$2"
if [ -z "$N" ] || [ -z "$NAME" ]; then
  echo "Usage: seed-attempt.sh <N> <short-name>"
  exit 1
fi
ATTEMPT="$(dirname "$FACTORY_ROOT")/attempt_${N}_${NAME}"
if [ -d "$ATTEMPT" ]; then
  echo "Attempt dir already exists: $ATTEMPT (attempts are immutable; pick a new N/name)"
  exit 1
fi

mkdir -p "$ATTEMPT"

# ---- factory tooling ----
cp -r "$FACTORY_ROOT/bin"       "$ATTEMPT/bin"
cp -r "$FACTORY_ROOT/.claude"   "$ATTEMPT/.claude"
cp -r "$FACTORY_ROOT/skills"    "$ATTEMPT/skills"
cp -r "$FACTORY_ROOT/templates" "$ATTEMPT/templates" 2>/dev/null || true
cp "$FACTORY_ROOT/CLAUDE.md"    "$ATTEMPT/CLAUDE.md"
cp "$FACTORY_ROOT/PIPELINE.md"  "$ATTEMPT/PIPELINE.md"
[ -f "$FACTORY_ROOT/AGENTS.md" ]    && cp "$FACTORY_ROOT/AGENTS.md"    "$ATTEMPT/AGENTS.md"
[ -f "$FACTORY_ROOT/modules.json" ] && cp "$FACTORY_ROOT/modules.json" "$ATTEMPT/modules.json"
touch "$ATTEMPT/factory.json"

# ---- frozen phase-1 fixture ----
mkdir -p "$ATTEMPT/knowledge/contracts"
cp -r "$FACTORY_ROOT/knowledge/prd"                  "$ATTEMPT/knowledge/prd"
cp -r "$FACTORY_ROOT/knowledge/contracts/acceptance" "$ATTEMPT/knowledge/contracts/acceptance"
cp -r "$FACTORY_ROOT/knowledge/contracts/iface"      "$ATTEMPT/knowledge/contracts/iface"
cp -r "$FACTORY_ROOT/knowledge/technical"            "$ATTEMPT/knowledge/technical"
cp -r "$FACTORY_ROOT/knowledge/spec"                 "$ATTEMPT/knowledge/spec"
cp "$FACTORY_ROOT/knowledge/architecture.md"         "$ATTEMPT/knowledge/architecture.md"
for f in factory-wisdom.md gold-standard.md target-types.md lessons.md; do
  [ -f "$FACTORY_ROOT/knowledge/$f" ] && cp "$FACTORY_ROOT/knowledge/$f" "$ATTEMPT/knowledge/$f"
done

# ---- pipeline state: every fixture feature sits just before handoff ----
# stage = feasibility_ok when a verdict file exists, else feasibility_waived, so
# handoff-to-planner's prd-check passes and the roadmap phase is the thing under test.
mkdir -p "$ATTEMPT/kanban"
for acc in "$ATTEMPT/knowledge/contracts/acceptance/"*.md; do
  slug=$(basename "$acc" .md)
  if [ -f "$ATTEMPT/knowledge/technical/feasibility/$slug.md" ]; then
    KANBAN_PROJECT_ROOT="$ATTEMPT" "$ATTEMPT/bin/pipeline-state" set "$slug" feasibility_ok "seeded from frozen fixture" >/dev/null
  else
    KANBAN_PROJECT_ROOT="$ATTEMPT" "$ATTEMPT/bin/pipeline-state" set "$slug" feasibility_waived "seeded from frozen fixture (no external dependency)" >/dev/null
  fi
done

# ---- the product's own repo (builders build HERE, never in the factory tree) ----
git init -q -b main "$ATTEMPT/product"
git -C "$ATTEMPT/product" config user.email factory@local
git -C "$ATTEMPT/product" config user.name factory
printf '# Product\nBuilt by the software factory. Do not put factory tooling here.\n' > "$ATTEMPT/product/README.md"
git -C "$ATTEMPT/product" add -A
git -C "$ATTEMPT/product" commit -qm "init product repo"

echo "Attempt seeded: $ATTEMPT"
echo "  features    : $(ls "$ATTEMPT/knowledge/contracts/acceptance" | wc -l) (acceptance contracts)"
echo "  product repo: $ATTEMPT/product (main)"
echo "  kanban      : empty — roadmap phase creates tickets"
echo ""
echo "Next:"
echo "  KANBAN_PROJECT_ROOT=$ATTEMPT $ATTEMPT/bin/handoff-to-planner"
echo "  KANBAN_PROJECT_ROOT=$ATTEMPT $ATTEMPT/bin/factory-watch"
