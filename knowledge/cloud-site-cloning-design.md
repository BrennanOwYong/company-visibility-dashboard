# Cloud Site Cloning Extension — Design Spec

**Working name:** placeholder ("SiteTether" used below; rename freely)
**Date:** 2026-06-19
**Status:** PRD approved by user 2026-06-22. Build phase: research → tickets → contracts → builders.

---

## 1. Problem

Browser AI agents (Claude in Chrome, Codex browser) need your laptop powered on and the tab open to act. You cannot hand off automated work to run overnight or unattended. Many web tools have no Application Programming Interface (API) or official integration, so a browser is the only way to act on them.

We want: send a logged-in website's *session* to a remote browser that stays alive 24/7, so an AI agent acts on the exact same site while the laptop is off.

## 2. What we build (and what we do not)

We build the **pipe and the persistent home** for automation, not the automation itself. The user's existing AI agent does the actual work.

**In scope (v1):**
- A Chrome extension that captures a site's session and sends it to a remote browser.
- A small cloud-side "Receiver" that holds the session in a real browser 24/7 and exposes a control port.
- A secure pairing flow between laptop and cloud, extension as the bridge.
- **Always-on security:** encrypted, authenticated, no-open-ports transport via Tailscale. Never deferred, never optional.
- The Live Location control model (laptop vs cloud ownership) with singleton handling and user-configurable SOPs (§7b).

**Security is not deferred.** The encrypted, authenticated, no-inbound-ports connection ships in v1 through Tailscale (WireGuard encryption + device auth + Tailscale's own relay servers). There is no mode in which the tool runs without it.

**Out of scope (deferred to the founder's future SaaS):**
- Hosting cloud browser instances for users (v1 user brings their own AWS box).
- A *self-hosted relay of our own*. v1 does not need one: Tailscale already provides the secured, relayed, authenticated wire. We would build our own relay only later, inside the SaaS, to drop the Tailscale dependency. It would replace Tailscale, not add missing security.
- Building the AI agent (any agent that speaks the standard control port works).

## 3. Architecture

Three pieces plus the user's agent.

| Where | Component | Job |
|---|---|---|
| Laptop (Chrome) | **Extension** | Alt+Y to clone, captures session, cloned-sites list, Yank-back, sends heartbeat |
| Laptop (OS) | **Tailscale app** | Puts laptop on the user's private network (install once) |
| Cloud (AWS) | **Receiver** | Catches session, runs real Chromium logged in as the user, keeps it alive, answers heartbeats, exposes control port |
| Cloud (OS) | **Tailscale** | Joins the same private network |
| Anywhere | **User's AI agent** | Connects to the Receiver's Chrome DevTools Protocol (CDP) port over the Tailscale wire and drives the live site |

**Why a session, not a "clone":** a website lives on its own servers. What transfers is the authenticated session: cookies, `localStorage`, `sessionStorage`, `IndexedDB`, and tokens for that domain. The Receiver loads the real site with that session and comes up logged in.

**Why Tailscale:** it is the encrypted wire. Outbound-only, no public Internet Protocol (IP) address, no open inbound ports. Only the user's two devices can reach each other. This avoids the catastrophic footgun of exposing a CDP port (which has no auth) on a public IP.

## 4. Setup flow (two user actions)

1. **Install the extension.**
2. **Point it at the cloud instance** via one pairing code:
   - One-time: install Tailscale on the laptop (guided button + login). Extension detects if already present.
   - On the cloud box: run the Receiver install (see §10). It joins Tailscale and prints **one pairing code + QR**. The code carries the Receiver's Tailscale address plus a short-lived key (expires ~10 min).
   - In the extension: paste the code or scan the QR. Connected. The Receiver appears by name (e.g. `cloud-1`), like Claude Desktop's device list.

No IP typing. Modeled on Claude Desktop Remote Control: outbound-only, relay/identity-style pairing, short-lived scoped credentials (see References).

## 5. Clone flow

1. User presses **Alt+Y** on the active tab.
2. **Consent gate:** the site and its login move to your cloud browser, where your agent can act on it while you are away and cannot see it. Clone only if you already trust that agent to act unsupervised. Copy: `This site and its login move to your cloud browser. Your AI agent can act on it while you're away and can't watch. Clone only if you trust it to act unsupervised.` Singleton sites also show the one-login note.
3. Extension captures the session bundle and sends it to the Receiver over Tailscale.
4. **Toast** at the bottom of the screen confirms: `✓ {site} cloned — your agent can act on it remotely`.
5. Site appears in the extension's cloned-sites list with a type chip and live status.

## 6. Control model — "Live Location"

Each cloned site has exactly **one Live Location** at any moment: **LAPTOP** or **CLOUD**. The agent connects to one stable address; the Receiver points that address at the current Live Location. The agent never knows the source flipped.

**Hard rule (non-configurable): the laptop always wins.**

| State | Condition | Live Location | Agent |
|---|---|---|---|
| Foreground | Laptop awake, site is the active tab | LAPTOP | dormant |
| Background | Laptop awake, site open but not focused | LAPTOP (owns session) | dormant |
| Cloud-while-awake | Laptop awake, site not open anywhere | CLOUD | working |
| Handoff | Laptop asleep/off (heartbeat stopped) | CLOUD | working |

> Note: this table is the default singleton-style flow. For **multi-login** sites the agent stays live in the CLOUD even while you use your own tab (`run_parallel`), or you can set `do_here` to point the agent at your tab so you watch it act. Every branch and its governing setting is mapped in §7b.

**Transitions:**
- **Reclaim** (CLOUD→LAPTOP): user opens/focuses the site. Cloud yields.
- **Release** (LAPTOP→CLOUD): user closes/navigates away. Cloud takes over.
- **Sleep** (→CLOUD): heartbeat stops, cloud activates automatically.
- **Wake**: heartbeat resumes; re-evaluate against the rules above.

**Heartbeat:** the extension sends a quiet pulse over Tailscale every few seconds. The cloud cannot be told "I'm asleep now" by a powered-off laptop, so absence of the pulse is the signal that the laptop is down and the cloud should take over. Pulse returns → cloud yields.

## 7. Behavior by site type (auto-detected; sensible defaults, fully configurable)

The site type drives the default behavior so a non-technical user never has to open settings. Power users get a setting (an SOP) for every branch. Defaults are chosen so the tool is intuitive out of the box; §7b is the full matrix.

- **Singleton sites (WhatsApp Web, Telegram Web):** the app physically allows one login. Opening on the laptop makes the cloud session yield automatically. The cloud copy runs only while the laptop is off/asleep. The "in use elsewhere" signal from the app confirms a clean swap. UI: `{site} is in use elsewhere`. But this should be detected by the extension. Whatsapp and Telegram Web are not the only sites that behave this way. Popular websites known to have such singleton can be researched and catalogued, the detection phase should still apply to the rest.
- **Multi-login sites (most of the web):** both can be live at once, so no conflict. The agent keeps working in the cloud while the user uses their own tab. A top banner reminds them: `{site} is live on your remote instance · agent may act · [Use this tab]`.

**Only override:** if detection guesses the type wrong, the user taps the type chip (1-login / multi) on that site to flip it. Explained in plain text.

## 7b. Control settings (SOPs) and the full decision logic

Default behavior needs zero configuration. Every branch is also a setting (an SOP) for users who want fine control. A global default plus a per-site override.

**Five facts decide everything, per site, every moment:**
- `site.type` — singleton or multi (auto-detected, user can flip)
- `heartbeat` — is the laptop awake and reachable
- `tab_state` — foreground / background / closed on the laptop
- `agent_state` — idle or mid_action in the cloud
- a manual **Yank** — the panic override, always wins

**The settings (defaults in bold):**

| Setting | Applies to | Options | Default |
|---|---|---|---|
| `singleton_reclaim` | singleton sites | `ask` · `grace_then_yield` | **`grace_then_yield`** |
| `grace_seconds` | singleton (grace) | number | **30** |
| `multi_when_present` | multi sites | `run_parallel` · `do_here` | **`run_parallel`** |
| `multi_banner` | multi sites | `always` · `when_agent_active` · `never` | **`when_agent_active`** |

**Template strings (what each setting reads as on screen):**

```text
singleton_reclaim = ask              -> "When I open {site}, ask before taking it back from the agent."
singleton_reclaim = grace_then_yield -> "When I open {site}, let the agent finish its step (up to {grace_seconds}s), then take over."
multi_when_present = run_parallel    -> "Let the agent keep working on {site} in the cloud while I use my own tab."
multi_when_present = do_here         -> "When I open {site}, point the agent at this tab so I can watch it work here."
multi_banner = always                -> "Always show the cloud banner on {site}."
multi_banner = when_agent_active     -> "Show the cloud banner on {site} only while the agent is acting."
multi_banner = never                 -> "   show the cloud banner on {site}."
```

**The cloud banner (multi-login sites only).** On a multi-login site, your laptop tab and the cloud copy are two separate live sessions. So you can be reading your own tab while the agent independently acts on the cloud copy, and you would not see it happen. The cloud banner is a thin strip at the top of your laptop tab that surfaces this: `{site} is live on your remote instance · agent may act · [Use this tab]`. Its job is to make sure a change the agent causes (a message sent, a row edited) never looks like it came from nowhere. The `multi_banner` setting controls when it shows (`always` / only `when_agent_active` / `never`). Clicking **Use this tab** switches that site to `do_here`, pointing the agent at the tab you are looking at so you can watch it or take over. The banner is a `run_parallel` concept; under `do_here` the tab instead shows an "agent is acting here" indicator.

**The decision logic — runs whenever any of the five facts changes:**

```python
RUN      = "agent drives the cloud copy"
RUN_HERE = "agent drives THIS laptop's tab, so you watch it act live"
PAUSE    = "agent halted for this site"

def resolve(site, settings, world):
    # world.heartbeat:   laptop awake & reachable
    # world.tab_state:   "foreground" | "background" | "closed"
    # world.agent_state: "idle" | "mid_action"

    # 1. Laptop away -> cloud owns it. The whole point of the product.
    if not world.heartbeat:
        return RUN

    laptop_using_site = world.tab_state in ("foreground", "background")

    # 2. Laptop awake but not on this site -> agent works.
    if not laptop_using_site:
        return RUN

    # 3. Laptop awake AND on this site -> laptop precedence kicks in.
    if site.type == "multi":
        # Both copies can be live; no physical conflict.
        if settings.multi_when_present == "do_here":
            return RUN_HERE              # point the agent at THIS tab; you watch it act live
        show_banner(settings.multi_banner, world.agent_state)
        return RUN                       # run_parallel: your tab + cloud copy run independently

    # site.type == "singleton": only one live login is possible -> laptop wins.
    if world.agent_state == "idle":
        return PAUSE                      # instant, nothing to interrupt

    # agent is mid_action -> the configurable SOP decides HOW to yield:
    if settings.singleton_reclaim == "ask":
        if user_confirms("Take it back from the agent now?"):
            return PAUSE
        return RUN                        # you chose to let it keep going
    if settings.singleton_reclaim == "grace_then_yield":
        wait_for_idle(timeout=settings.grace_seconds)
        return PAUSE


def on_yank(site):                        # panic button — overrides everything above
    stop_agent(site)
    surface_cloud_state_to_laptop(site)   # show what it did; do NOT overwrite with local
    toast("✋ {site} pulled back to this laptop. Agent action stopped")
    return PAUSE


def on_wake():                            # heartbeat returns
    for site in cloned_sites:
        resolve(site, settings, observe(site))   # same rules, re-applied
```

Scheduled tasks run only while `resolve()` returns `RUN` for that site.

## 8. Yank-back (panic stop)

Always available for any site live in the cloud. It is an emergency brake, not a handover preference. On press:
1. The agent's connection to that cloud instance is cut; the agent stops.
2. The cloud tab's **current** state is surfaced on the laptop so the user sees what the agent was doing. It does **not** overwrite that with the local cached version.
3. Toast: `✋ {site} pulled back to this laptop. Agent action stopped`.

## 9. Security model

- **Transport:** Tailscale WireGuard wire, outbound-only, no public IP, no inbound ports. v1 uses `ws://` to the Receiver's `100.x` Tailscale IP (WireGuard encrypts it; no TLS cert step). `wss://` via MagicDNS is deferred (needs a manual tailnet admin step).
- **Pairing (app-level, not Tailscale-native):** the Receiver mints a 32-byte CSPRNG token at boot, 10-min TTL, memory-only, one-time use. Pairing code = base64url(`{ip, token, expires}`). On connect the extension sends the token; the Receiver validates, issues a long-lived session secret, then deletes the token. Tailscale auth keys are separate (they only join the tailnet; min 1-day expiry).
- **Tailnet:** the Receiver joins as a non-ephemeral node (it must persist). Per-tag ACLs (`tag:laptop` ↔ `tag:receiver`) are a documented hardening step, not required for v1.
- **Session data:** the bundle (cookies/storage/tokens) is full account access. Encrypted in transit by Tailscale. Stored on the Receiver only as long as the site is cloned; removed on un-clone. Never logged.
- **Consent:** explicit per-site warning before any clone.
- **Secrets:** never written literally; environment variables only; values in `.env.test`.

## 10. AWS deployment for end users (must be dashboard-easy)

The end user likely uses the AWS console, not a terminal. SSH-and-run-a-script is too technical. Target experience:

- **Primary path: one-click CloudFormation quick-create link.** The user clicks, pastes their Tailscale auth key (a `NoEcho` parameter), clicks Create Stack. The boot script installs Tailscale + Chromium + the Receiver and posts the pairing code to a CloudFormation `WaitCondition`, so it appears in the stack's **Outputs** tab. The user never leaves the console (no SSH).
- **Cheapest viable instance:** `t4g.micro` (ARM, 1 GB RAM, ~$6/mo, free-tier eligible). `t4g.nano` (0.5 GB) is too small — headful Chromium runs out of memory. `t2.micro` (x86, free-tier) is the swap for users avoiding ARM packages. Region default `us-east-1`.
- **Validation during build:** use the founder's AWS CLI (reauth: `aws login`; root access) to provision the cheapest test instance, capture metadata, tear down after.

## 11. Open items / deferred

- **Wake-during-singleton-action:** handled by the `singleton_reclaim` SOP (§7b). Default `grace_then_yield` lets the agent finish its current step (up to `grace_seconds`) before the laptop takes over; Yank-back is the instant override. Confirm the default feels right in user testing.
- **`do_here` capability:** routing the agent to the laptop's own tab (the `RUN_HERE` outcome) requires the extension to expose local tab control to the agent, e.g. via `chrome.debugger`/CDP. This is heavier than cloud-only control. It can ship after `run_parallel` if needed, without changing the settings model.
- **Un-clonable sessions (hard edge):** sites whose auth is bound to a non-extractable WebCrypto key cannot be moved — the key physically cannot leave the laptop. The clone flow detects the failure and tells the user rather than half-working. Also: `sessionStorage` is re-captured/re-injected each launch, service-worker caches re-establish on first load, and CHIPS partitioned cookies round-trip unreliably.
- **Receiver crash/restart:** session persistence across Receiver restarts (re-inject stored bundle) — design during build.
- **Multiple cloud instances per user:** v1 supports one paired Receiver; multi-instance is a later concern.
- **SaaS future:** cloud auto-provisioning + managed relay replace the BYO-AWS + Tailscale steps, making pairing fully automatic. Architecture leaves this seam open.

## 12. Components to build (preview of tickets)

1. **Extension — capture & clone:** Alt+Y, session capture (cookies/storage/IndexedDB), consent gate, send-to-Receiver, toast.
2. **Extension — cloned-sites UI:** list, type chips + flip override, live-status, Yank-back, settings.
3. **Extension — pairing:** Tailscale detection, paste/scan pairing code, connection status.
4. **Receiver — core:** receive bundle, launch Chromium with session, expose CDP port, hold alive.
5. **Receiver — heartbeat, Live Location & SOP engine:** heartbeat listener, singleton detection (runtime + a researched catalog of known singleton sites), and the `resolve()` SOP engine from §7b (reclaim/release/sleep/wake, settings + per-site overrides).
6. **AWS deploy:** CloudFormation/AMI one-click, Receiver install script, pairing-code surfacing.
7. **Security/pairing layer:** code generation, short-lived keys, Tailscale join.

Each becomes an atomic ticket with a HANDOFF and contracts between extension↔Receiver (session bundle shape, control/heartbeat protocol, pairing code format).

## References

- Claude Code Remote Control (pairing, outbound-only, short-lived credentials): https://code.claude.com/docs/en/remote-control
- Claude Desktop Dispatch mobile pairing (QR): https://support.claude.com/en/articles/13947068
- Integration research (verified 2026-06-22), each with official-doc deep links: `knowledge/research/extension-capture.md`, `knowledge/research/tailscale-pairing.md`, `knowledge/research/receiver-browser.md`, `knowledge/research/aws-deploy.md`.
- Verified 2026-06-19.
