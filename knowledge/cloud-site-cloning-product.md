# Cloud Site Cloning Extension — Product Spec

**Working name:** placeholder ("SiteTether" used below; rename freely)
**Date:** 2026-06-19
**Status:** PRD approved by user 2026-06-22.
**Altitude:** product only. This doc states what the user experiences and why. How it is built lives with the technical planner.

---

## 1. Problem

AI agents that work through a web browser need your laptop powered on and the tab open to act. You cannot hand off automated work to run overnight or while you are away. Many web tools offer no official integration, so a browser is the only way to act on them.

We want: send a logged-in website to a remote browser that stays alive around the clock, so your AI agent keeps acting on the exact same site while your laptop is off.

## 2. What we build (and what we do not)

We build the pipe and the persistent home for automation. The user's existing AI agent does the actual work.

**In scope (v1):**
- A Chrome extension that sends a site you are logged into to your remote browser.
- A remote "Receiver" that keeps that site alive and signed in around the clock, ready for your agent.
- A pairing flow that connects laptop and remote browser with one code.
- Always-on privacy: the connection between your devices is private and encrypted, reachable by your devices only. Never optional, never deferred.
- The Live Location control model (who owns the site right now: laptop or cloud) with sensible defaults and user-configurable behavior (§6).

**Out of scope (v1):**
- Hosting the remote browser for the user. In v1 the user supplies their own cloud machine; setup must still be click-through easy (§8).
- Building the AI agent itself. Any compatible agent can drive the remote site.

## 3. The pieces, as the user sees them

| What | Job |
|---|---|
| Browser extension | One shortcut to clone a site, a list of cloned sites with live status, the take-back button, settings |
| Companion connection app | Installed once on the laptop; makes the private device-to-device connection possible |
| Remote browser ("Receiver") | Lives on the user's cloud machine; holds the cloned sites open and signed in, day and night |
| The user's AI agent | Connects to the remote browser and does the actual work |

What moves when you clone is your signed-in access to the site, so the remote browser opens the real site already logged in as you. The site itself still lives on its own servers.

## 4. Setup flow (two user actions)

1. **Install the extension.**
2. **Point it at your cloud machine** with one pairing code:
   - One time: install the companion connection app on the laptop (guided button and login). The extension detects it if already present.
   - On the cloud machine: run the Receiver setup. It prints one pairing code plus a QR code. The code expires after about ten minutes.
   - In the extension: paste the code or scan the QR. Connected. The Receiver appears by name (e.g. `cloud-1`), like a device list.

No addresses to type. Pairing feels like linking a phone to a desktop app.

## 5. Clone flow

1. User presses **Alt+Y** on the active tab.
2. **Consent gate**, shown before anything moves: `This site and its login move to your cloud browser. Your AI agent can act on it while you're away and can't watch. Clone only if you trust it to act unsupervised.` One-login sites also show the one-login note (§6).
3. The extension sends the site to the Receiver.
4. **Toast** confirms: `✓ {site} cloned — your agent can act on it remotely`.
5. The site appears in the extension's cloned-sites list with a type chip and live status.

If a site cannot be cloned (some sites bind login to the device in a way that cannot move), the extension says so plainly instead of half-working.

## 6. Control model — "Live Location"

Each cloned site is live in exactly one place at any moment: **LAPTOP** or **CLOUD**. The agent never notices the location flip; its work continues against whichever copy is live.

**Hard rule (non-configurable): the laptop always wins.**

| State | Condition | Live Location | Agent |
|---|---|---|---|
| Foreground | Laptop awake, site is the active tab | LAPTOP | dormant |
| Background | Laptop awake, site open but not focused | LAPTOP | dormant |
| Cloud-while-awake | Laptop awake, site not open anywhere | CLOUD | working |
| Handoff | Laptop asleep or off | CLOUD | working |

For **multi-login** sites the agent can stay live in the cloud even while you use your own tab, or you can point the agent at your own tab and watch it work. Every branch has a setting (§6b).

**Transitions the user experiences:**
- **Reclaim:** open or focus the site on the laptop and the cloud yields.
- **Release:** close the site or navigate away and the cloud takes over.
- **Sleep:** laptop sleeps or shuts down and the cloud takes over on its own.
- **Wake:** laptop returns and the normal rules re-apply.

The extension and the Receiver stay quietly in touch so the cloud notices, within seconds, that the laptop went away or came back. The user never signals this manually.

### Behavior by site type (auto-detected)

- **One-login sites (WhatsApp Web, Telegram Web):** the site allows one login at a time. Opening it on the laptop makes the cloud copy yield automatically; the cloud copy runs only while the laptop is away. UI: `{site} is in use elsewhere`. Detection is automatic, seeded by a researched catalog of known one-login sites and confirmed live per site.
- **Multi-login sites (most of the web):** both copies can be live at once, no conflict. The agent keeps working in the cloud while the user uses their own tab. A top banner reminds them: `{site} is live on your remote instance · agent may act · [Use this tab]`.

**Only override:** if detection guesses wrong, the user taps the type chip (1-login / multi) on that site to flip it. Explained in plain text.

### 6b. Control settings

Defaults need zero configuration. Every branch is also a setting, global default plus per-site override. Each setting reads as a plain sentence:

| Setting reads as | Options | Default |
|---|---|---|
| "When I open {site}, take it back from the agent…" | ask me first · let the agent finish its step (up to {n} seconds), then take over | **finish then take over, 30s** |
| "While I'm using {site} in my own tab…" | let the agent keep working in the cloud · point the agent at this tab so I can watch | **keep working in the cloud** |
| "Show the cloud banner on {site}…" | always · only while the agent is acting · never | **only while acting** |

**The cloud banner (multi-login sites only).** Your tab and the cloud copy are two separate live sessions, so the agent could act while you read your own tab and you would not see it happen. The banner is a thin strip at the top of your tab that surfaces this, so a change the agent causes (a message sent, a row edited) never looks like it came from nowhere. Clicking **Use this tab** points the agent at the tab you are looking at so you can watch it or take over; in that mode the tab shows an "agent is acting here" indicator instead of the banner.

Scheduled agent tasks run only while the cloud copy is the live one for that site.

## 7. Yank-back (panic stop)

Always available for any site live in the cloud. An emergency brake, not a handover preference. On press:
1. The agent stops immediately.
2. The laptop shows the site's current state as the agent left it, so the user sees what the agent was doing. It never overwrites that with an older local version.
3. Toast: `✋ {site} pulled back to this laptop. Agent action stopped`.

## 8. Setting up the cloud machine (must be dashboard-easy)

The target user works in a web console, not a terminal. The v1 experience: a one-click setup link on their cloud provider's dashboard, paste one key, click Create, and the pairing code appears on that same dashboard. No command line at any point. The cheapest machine the provider offers should be enough to run one Receiver.

## 9. Privacy and consent (user-facing promises)

- The connection between laptop and cloud is private and encrypted; only the user's own devices can reach the Receiver. Nothing about the tool is reachable from the open internet.
- Cloning is always behind an explicit per-site consent gate (§5).
- The signed-in access lives on the Receiver only while the site stays cloned; un-cloning removes it.
- What the user sees stays theirs: no logging of site contents or credentials.

## 10. Open product questions / deferred

- **Taking back a one-login site mid-action:** the default lets the agent finish its current step (up to the grace period) before the laptop takes over; Yank-back remains the instant override. Confirm the default feels right in user testing.
- **Watch-it-work mode** (pointing the agent at your own tab) can ship after the parallel mode if needed; the settings model already covers it.
- **Multiple cloud machines per user:** v1 supports one paired Receiver.
- **Future SaaS:** a hosted version removes the bring-your-own-cloud step and makes pairing fully automatic.

## 11. Success

- A non-technical user gets from install to first clone in minutes, without a terminal.
- The user's agent completes work overnight with the laptop closed.
- Opening the site on the laptop always takes precedence, within seconds, with no data surprises.
- The user is never surprised by an agent action they could not trace (banner, list status, yank-back).
