# Tailscale Pairing — Research Findings

**Date:** 2026-06-27
**Status:** Verified against official Tailscale docs (retrieval date noted per section)
**Scope:** Answers §4 setup flow and §9 security questions for SiteTether

---

## 1. Joining a tailnet unattended on a headless Linux box

### Command

```bash
sudo tailscale up --auth-key=tskey-auth-XXXXX --hostname=cloud-receiver --advertise-tags=tag:receiver
```

`--auth-key` bypasses the interactive browser login entirely. `--hostname` sets the MagicDNS name. `--advertise-tags` applies ACL tags at join time — the key must be pre-authorized for those tags (see §6).

### Auth key types

| Type | Behavior |
|---|---|
| One-time (default) | Single use; device can join once |
| Reusable | Multiple devices can join with the same key |
| Pre-authorized | Device joins without manual admin approval, even when device approval is enabled |
| Ephemeral | Tailscale auto-removes the device 30–60 min after it goes offline |
| Tagged | Automatically applies one or more ACL tags to the joining device |

**For the Receiver:** use a one-time, pre-authorized, tagged key (NOT ephemeral — the Receiver must persist). Ephemeral is for containers/lambdas that should disappear.

### Minting an auth key via the API

Base URL: `https://api.tailscale.com/api/v2`
Auth: `Authorization: Bearer {api_key}` (API key from tailscale.com/admin/settings/keys) or OAuth access token.

**Endpoint:** `POST https://api.tailscale.com/api/v2/tailnet/-/keys`

Request body:

```json
{
  "capabilities": {
    "devices": {
      "create": {
        "reusable": false,
        "ephemeral": false,
        "preauthorized": true,
        "tags": ["tag:receiver"]
      }
    }
  },
  "expirySeconds": 86400,
  "description": "receiver-join-key"
}
```

Response includes the key value in `tskey-auth-XXXXX` format.

**For programmatic key minting from the Receiver install script (recommended):** create an OAuth client in the admin console with `auth_keys` scope, tag scope set to `tag:receiver`. Exchange credentials at `POST https://api.tailscale.com/api/v2/oauth/token` for a 1-hour access token, then call the keys endpoint above. The installer holds the OAuth client ID and secret; it mints the auth key on demand and discards it after joining.

### Ephemeral node cleanup

Auto-removed 30–60 min after last activity. Can be triggered manually with `tailscale logout`. Do NOT use ephemeral for the Receiver.

---

## 2. Obtaining the node's stable address after join

### IPv4 (100.x)

```bash
tailscale ip -4
# → 100.x.y.z
```

`-4` flag forces IPv4 only. Without flags returns both IPv4 and IPv6.

### MagicDNS name

```bash
tailscale status --json | jq '.Self.DNSName'
# → "cloud-receiver.tailnet-name.ts.net."
# Strip trailing dot for use in URLs.
```

IPv4 from JSON:

```bash
tailscale status --json | jq '.Self.TailscaleIPs[0]'
# → "100.x.y.z"
```

**JSON field paths (confirmed):**
- `Self.TailscaleIPs[0]` — IPv4 (100.x)
- `Self.DNSName` — full MagicDNS FQDN, e.g. `cloud-receiver.tailfa84dd.ts.net.`
- `Self.HostName` — short hostname

MagicDNS name format: `{hostname}.{tailnet-dns-name}.ts.net`

---

## 3. Reachability from a Chrome extension

### Yes — OS routing makes 100.x transparent to all apps

Tailscale installs a WireGuard network interface (e.g. `tailscale0` on Linux, `utun` on macOS) and adds routing table entries for `100.64.0.0/10` through that interface. Every process on the machine — including Chrome and extensions running inside Chrome — transparently reaches 100.x addresses via the OS routing layer. The extension needs no special knowledge of Tailscale.

A Chrome extension service worker can:

```js
// Direct 100.x — plain WebSocket over WireGuard (no TLS cert needed)
const ws = new WebSocket("ws://100.x.y.z:PORT/control");

// MagicDNS — only if HTTPS is enabled in the tailnet (see below)
const ws = new WebSocket("wss://cloud-receiver.tailfa84dd.ts.net/control");
```

### TLS options and cert implications

**Option A (recommended for v1): plain `ws://100.x.y.z:PORT`**
- WireGuard provides encryption at the transport layer. The WebSocket content is not exposed in cleartext.
- No TLS cert required; no cert errors in Chrome.
- Chrome extension background/service workers can open `ws://` connections without mixed-content restrictions.
- Host permission needed in manifest: `"ws://100.*/*"`.

**Option B: `wss://` via `tailscale serve`**
- `tailscale serve --https=443 localhost:PORT --bg` automatically provisions a Let's Encrypt certificate for `cloud-receiver.tailnet-name.ts.net`.
- The cert is trusted by Chrome (Let's Encrypt is a public CA), so `wss://` works without errors.
- Requires: HTTPS enabled in the tailnet admin console under DNS settings (one-time opt-in).
- Machine name appears in public Certificate Transparency logs (low severity).
- `tailscale serve` performs HTTP reverse proxying. Go's HTTP server handles WebSocket upgrade; functional but not explicitly documented for WebSocket in Tailscale docs. Test before relying on it.

**Option C: `tailscale cert`**
- `tailscale cert cloud-receiver.tailnet-name.ts.net` writes `cert.pem` and `key.pem` locally.
- App uses these certs to serve `wss://` directly without `tailscale serve` as a proxy.
- Certs expire after 90 days; require manual or scripted renewal.

**Recommendation for v1:** Option A. Avoids cert management entirely. WireGuard already encrypts the wire; TLS over WireGuard is redundant for intra-tailnet traffic. Use Option B only if WSS is required for browser API compatibility reasons.

---

## 4. Pairing code design

### What Tailscale provides natively

Tailscale does not have a built-in pairing code mechanism. Auth keys are for JOINING the tailnet (minimum 1-day expiry via admin console), not for authenticating application-level connections between nodes. OAuth tokens expire after 1 hour but are API credentials, not suitable as per-connection secrets.

**Conclusion: layer an app-level token on top. Tailscale handles transport security; the pairing code handles application-layer identity and discovery.**

### Minimal pairing code contents

The code must carry two things:
1. The Receiver's MagicDNS name (or 100.x IP) — so the extension knows where to connect
2. A short-lived random token — so the first connection is authenticated

```json
{
  "dns": "cloud-receiver.tailfa84dd.ts.net",
  "token": "base64url-random-32-bytes",
  "expires": 1735000200
}
```

Encode as base64url JSON for the QR/paste code. The token is generated by the Receiver at startup, valid for 10 min, stored in memory only.

### Handshake flow

1. Receiver boots, calls `tailscale ip -4` and `tailscale status --json | jq '.Self.DNSName'` to get its address.
2. Receiver generates 32-byte CSPRNG token, stores with 10-min TTL.
3. Pairing code printed as QR and text.
4. User pastes code into extension.
5. Extension connects to `ws://100.x.y.z:PORT` (or `wss://...ts.net`), sends token in first message.
6. Receiver verifies token (must exist, not expired), issues a long-lived session secret (HMAC or UUID), stores it, returns it.
7. Extension stores session secret. All subsequent connections authenticate with it.
8. Receiver deletes the pairing token after first successful use (one-time use).

There is no Tailscale-native mechanism (auth keys, OAuth clients, ACL grants) that provides a 10-min scoped secret suitable for this purpose. The app-level token is the correct design.

---

## 5. Detecting Tailscale on the laptop from the extension

### Important constraint: LocalAPI port 41112 was deprecated in v1.34.1 (December 2022)

Tailscale moved its local daemon API to a Unix socket. Chrome extensions cannot reach Unix sockets and cannot reliably probe the old TCP port.

### Viable detection signals

**Signal 1 — attempt connection after pairing (most reliable)**
Once the extension has the Receiver's address from the pairing code, attempt `fetch()` or WebSocket to `ws://100.x.y.z:PORT`. Success confirms Tailscale is installed and routing. Failure prompts the user to install Tailscale.

**Signal 2 — Native Messaging host (comprehensive but requires extra install step)**
A small Go/Rust binary installed alongside the Receiver client on the laptop can be registered as a Chrome Native Messaging host. The extension calls `chrome.runtime.sendNativeMessage()`, and the binary runs `tailscale status` and returns the result. This is the only way to get OS-level information without the user doing anything.

**Signal 3 — user confirmation in setup UI**
Show a "Is Tailscale installed?" gate with a "Check" button that tries to connect to the Receiver address. Not automatic but zero extra dependencies.

**Recommendation:** Use Signal 1 after pairing. If connection fails, show the "Install Tailscale" step. Do not attempt to probe `127.0.0.1:41112` — it is unreliable post v1.34.1.

---

## 6. Security posture

### No inbound ports

Tailscale is outbound-only. The Receiver connects to Tailscale's DERP relay servers (outbound TCP 443 / UDP 41641). No inbound firewall rules needed. No public IP required on the Receiver. AWS Security Group can block all inbound traffic.

### WireGuard encryption

All traffic between laptop and Receiver is end-to-end encrypted with WireGuard (Curve25519 key exchange, ChaCha20-Poly1305). Tailscale never sees plaintext. Relay servers (DERP) carry only encrypted bytes.

### ACL/tag isolation

Define tags and restrict ACL so only the user's two nodes talk:

**tailnet policy file (tailscale.com/admin/acls):**

```json
{
  "tagOwners": {
    "tag:laptop": ["autogroup:admin"],
    "tag:receiver": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:laptop"],
      "dst": ["tag:receiver:*"]
    },
    {
      "action": "accept",
      "src": ["tag:receiver"],
      "dst": ["tag:laptop:*"]
    }
  ]
}
```

This blocks any other tailnet member (e.g., other devices the user may add later) from reaching the Receiver, unless explicitly tagged.

Apply at join time:

```bash
# Receiver
sudo tailscale up --auth-key=tskey-auth-XXXXX --hostname=cloud-receiver --advertise-tags=tag:receiver

# Laptop (user runs once after install)
sudo tailscale up --advertise-tags=tag:laptop
```

**Note:** The laptop tag assignment requires the user to run `tailscale up --advertise-tags=tag:laptop` once. Without this, the default ACL (allow all tailnet members) still applies, which is acceptable for single-user tailnets but less restrictive. For v1, the default ACL is sufficient since the user's tailnet contains only their own devices.

---

## Design-forcing constraints on §4 and §9

1. **10-min pairing token is app-level, not Tailscale-native.** No Tailscale API produces a sub-day short-lived credential suitable for the pairing code. The Receiver generates its own token. §4 design is valid; implementation must not confuse Tailscale auth keys with pairing tokens.

2. **The Receiver must NOT be ephemeral.** Ephemeral nodes are removed 30–60 min after going offline. The Receiver must persist indefinitely. Use a standard (non-ephemeral) pre-authorized auth key.

3. **HTTPS/WSS over MagicDNS requires admin console opt-in.** "Enable HTTPS" in tailscale.com/admin/dns is a manual step. The Receiver install script cannot do this automatically. If v1 uses Option B (wss://), the setup guide must include this step. Option A (ws://100.x) avoids this.

4. **Laptop tag assignment requires the user to run a CLI command.** `tailscale up --advertise-tags=tag:laptop` on the laptop is not something the extension can trigger. Skip per-tag ACLs in v1 (default allow-all within the user's tailnet is acceptable) or document this as a manual hardening step.

5. **Machine name in Certificate Transparency.** If using `tailscale cert` or `tailscale serve --https`, the machine hostname (e.g., `cloud-receiver`) is logged publicly. Name the instance generically.

6. **Chrome extension LocalAPI probe unreliable.** Cannot detect Tailscale by probing `127.0.0.1:41112` on modern Tailscale versions. Detect via connection attempt to Receiver after pairing.

---

## Sources

All sources are official Tailscale documentation or official Tailscale GitHub. Retrieved 2026-06-27.

- Auth keys: https://tailscale.com/docs/features/access-control/auth-keys
- Auth keys (KB): https://tailscale.com/kb/1085/auth-keys
- Ephemeral nodes: https://tailscale.com/kb/1111/ephemeral-nodes
- Tailscale CLI reference: https://tailscale.com/docs/reference/tailscale-cli
- `tailscale up` flags: https://tailscale.com/docs/reference/tailscale-cli/up
- `tailscale serve` reference: https://tailscale.com/docs/reference/tailscale-cli/serve
- Tailscale Serve feature docs: https://tailscale.com/docs/features/tailscale-serve
- Serve examples: https://tailscale.com/docs/reference/examples/serve
- Enabling HTTPS / `tailscale cert`: https://tailscale.com/docs/how-to/set-up-https-certificates
- ACL tags: https://tailscale.com/kb/1068/acl-tags
- Tailscale API overview: https://tailscale.com/kb/1101/api
- Tailscale API reference: https://tailscale.com/docs/reference/tailscale-api
- OAuth clients: https://tailscale.com/docs/features/oauth-clients
- Tailscale browser extension (experimental): https://github.com/tailscale/ts-browser-ext
- `tailscale status --json` field shapes: https://pkg.go.dev/tailscale.com/ipn/ipnstate
- LocalAPI port deprecation: https://github.com/tailscale/tailscale/issues/6777
- Tailscale IP addresses explainer: https://tailscale.com/docs/concepts/tailscale-ip-addresses
