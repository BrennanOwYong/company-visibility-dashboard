#!/bin/bash
# roadmap-site-cloner.sh — drives the roadmap-and-branching skill's decomposition deterministically
# for the cloud-site-cloner fixture: 10 tickets, their dependency edges, needs_user_test tags, and
# explicit References (only files that exist). Fills edge contracts from iface, writes build-plan.md,
# materializes graph.json. Does NOT dispatch (the caller does, to watch it separately).
set -e
A="${KANBAN_PROJECT_ROOT:?set KANBAN_PROJECT_ROOT to the attempt dir}"
export PATH="$A/bin:$PATH"
PROD="$A/product"

# t <issue> <feature> <nut> <deps> <landing> <infra> <links...>
t() {
  local iss="$1" feat="$2" nut="$3" deps="$4" landing="$5" infra="$6"; shift 6
  local links; links="$(printf '%s,' "$@" | sed 's/,$//')"
  kanban-create "$iss" --feature "$feat" --repo "$PROD" --needs-user-test "$nut" \
    --title "$(head -3 "$A/knowledge/spec/$feat.md" 2>/dev/null | grep -m1 -v '^#' | sed 's/^ *//' | cut -c1-80)" \
    --intent "Implements the '$feat' feature; see the spec + acceptance in References." \
    --build "Build per knowledge/spec/$feat.md, reconciled against knowledge/architecture.md. Interfaces in the linked iface/ contracts." \
    --success "The assertions in knowledge/contracts/acceptance/$feat.md hold on the running system." \
    --testing "Bring up the feature per its spec; the validator authors tests from acceptance/$feat.md." \
    ${deps:+--depends-on "$deps"} ${landing:+--landing-url "$landing"} ${infra:+--needs-infra "$infra"} \
    --links "$links" >/dev/null
  echo "  created $iss  (feature $feat, needs_user_test=$nut, deps=[${deps:-none}])"
}

echo "── creating tickets ──"
t wire-mesh private-connection false "" "" "Tailscale mesh account + auth key; a reachable Receiver host" \
  knowledge/spec/private-connection.md knowledge/contracts/acceptance/private-connection.md \
  knowledge/technical/feasibility/private-connection.md knowledge/technical/research/tailscale-pairing.md \
  knowledge/technical/research/aws-deploy.md knowledge/contracts/iface/wire-transport.md knowledge/architecture.md

t control-settings control-settings true "" /popup "" \
  knowledge/spec/control-settings.md knowledge/contracts/acceptance/control-settings.md \
  knowledge/contracts/iface/settings-schema.md knowledge/architecture.md

t receiver-core receiver false wire-mesh "" "AWS EC2 t4g.micro; Xvfb + systemd on the host; Tailscale auth key" \
  knowledge/spec/receiver.md knowledge/contracts/acceptance/receiver.md knowledge/technical/feasibility/receiver.md \
  knowledge/technical/research/receiver-browser.md knowledge/technical/research/aws-deploy.md \
  knowledge/contracts/iface/cdp-control.md knowledge/contracts/iface/heartbeat.md knowledge/contracts/iface/provision.md knowledge/architecture.md

t pairing pairing true wire-mesh,receiver-core /popup "Tailscale mesh + Receiver host" \
  knowledge/spec/pairing.md knowledge/contracts/acceptance/pairing.md knowledge/technical/feasibility/pairing.md \
  knowledge/technical/research/tailscale-pairing.md knowledge/contracts/iface/pairing-handshake.md knowledge/architecture.md

t ownership-engine live-location false receiver-core,control-settings "" "Receiver host + Tailscale mesh (shared)" \
  knowledge/spec/live-location.md knowledge/contracts/acceptance/live-location.md knowledge/technical/feasibility/live-location.md \
  knowledge/contracts/iface/ownership-engine.md knowledge/contracts/iface/retarget.md knowledge/architecture.md

t clone-site clone-site true wire-mesh,receiver-core "chrome://extensions" "" \
  knowledge/spec/clone-site.md knowledge/contracts/acceptance/clone-site.md knowledge/technical/feasibility/clone-site.md \
  knowledge/technical/research/extension-capture.md knowledge/technical/research/dbsc-device-binding.md \
  knowledge/technical/research/whatsapp-web-session.md knowledge/contracts/iface/session-bundle.md \
  knowledge/contracts/iface/unclone.md knowledge/architecture.md

t yank-back yank-back true ownership-engine /popup "" \
  knowledge/spec/yank-back.md knowledge/contracts/acceptance/yank-back.md knowledge/technical/feasibility/yank-back.md \
  knowledge/contracts/iface/yank.md knowledge/architecture.md

t cloud-banner cloud-banner true ownership-engine,control-settings /popup "" \
  knowledge/spec/cloud-banner.md knowledge/contracts/acceptance/cloud-banner.md \
  knowledge/contracts/iface/status-stream.md knowledge/architecture.md

t cloud-setup cloud-setup true receiver-core,pairing /popup "AWS account (us-east-1); an S3 template URL; a Tailscale auth key" \
  knowledge/spec/cloud-setup.md knowledge/contracts/acceptance/cloud-setup.md knowledge/technical/feasibility/cloud-setup.md \
  knowledge/technical/research/aws-deploy.md knowledge/technical/research/tailscale-pairing.md \
  knowledge/contracts/iface/provision.md knowledge/architecture.md

t cloned-sites-list cloned-sites-list true clone-site,control-settings,ownership-engine,yank-back /popup "" \
  knowledge/spec/cloned-sites-list.md knowledge/contracts/acceptance/cloned-sites-list.md \
  knowledge/contracts/iface/status-stream.md knowledge/architecture.md

# Fill each edge contract from the iface it points at (interface spec, not a mock boundary).
echo "── filling edge contracts from iface/ ──"
for c in "$A"/knowledge/contracts/*-*.md; do
  [ -f "$c" ] || continue
  base=$(basename "$c" .md)
  grep -q "Fill in the exact shape" "$c" || continue
  printf '# Contract: %s\n\nThe dependent builds against the REAL (merged) dependency; this records the interface it relies on.\nSee the relevant knowledge/contracts/iface/*.md seam(s) the two share (e.g. wire-transport, session-bundle, status-stream, ownership-engine, settings-schema, provision, pairing-handshake, yank, unclone, retarget, cdp-control, heartbeat).\n' "$base" > "$c"
done
echo "  filled $(ls "$A"/knowledge/contracts/*-*.md 2>/dev/null | wc -l) edge contracts"

# build-plan.md (roadmap skill Step 5)
kanban-graph --emit 2>/dev/null || true
echo "── build-plan.md ──"
{
  echo "# Build plan — cloud-site-cloner"; echo
  echo "Dependency levels, not batches: each ticket starts the moment ALL its prerequisites are DONE (real merged code). Dispatch re-runs on every merge, so tickets start as soon as prerequisites complete — nothing waits for a level to finish."; echo
  echo '```'; kanban-graph 2>/dev/null | sed -n '/DEPENDENCY LEVELS/,/EXTERNAL INFRA/p'; echo '```'
} > "$A/knowledge/build-plan.md"
echo "  wrote knowledge/build-plan.md"
