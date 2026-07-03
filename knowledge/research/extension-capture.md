# Extension Capture — Chrome MV3 API Research

Retrieval date: 2026-06-27. All APIs confirmed against official developer.chrome.com docs.

---

## 1. Capturing the Full Auth Session

### 1a. Cookies — `chrome.cookies`

**API: `chrome.cookies.getAll(details)`**

```typescript
chrome.cookies.getAll(details: {
  url?: string;              // restrict to cookies accessible at this URL
  domain?: string;           // restrict to domain and subdomains
  name?: string;
  path?: string;
  secure?: boolean;
  session?: boolean;         // true = session cookies only, false = persistent only
  storeId?: string;          // cookie store; omit for default (non-incognito) store
  partitionKey?: CookiePartitionKey; // Chrome 119+ — for CHIPS partitioned cookies
}): Promise<Cookie[]>
```

**`Cookie` object shape (complete):**

```typescript
{
  name: string;
  value: string;
  domain: string;
  path: string;
  secure: boolean;
  httpOnly: boolean;           // extension CAN read httpOnly cookies — unlike JS
  session: boolean;
  expirationDate?: number;     // Unix epoch seconds; absent for session cookies
  hostOnly: boolean;
  sameSite: "no_restriction" | "lax" | "strict" | "unspecified";
  storeId: string;
  partitionKey?: {             // Chrome 119+
    topLevelSite?: string;     // e.g. "https://example.com"
    hasCrossSiteAncestor?: boolean; // Chrome 130+
  };
}
```

**`CookiePartitionKey` shape:**

```typescript
{
  topLevelSite?: string;         // top-level site the cookie is partitioned under
  hasCrossSiteAncestor?: boolean; // Chrome 130+
}
```

**To capture ALL cookies for a domain including httpOnly and partitioned:**

```typescript
// Step 1: unpartitioned cookies (the vast majority)
const unpartitioned = await chrome.cookies.getAll({ url: "https://example.com/" });

// Step 2: partitioned cookies (CHIPS) — Chrome 119+
// Must know topLevelSite; for a first-party site this equals the site itself
const partitioned = await chrome.cookies.getAll({
  url: "https://example.com/",
  partitionKey: { topLevelSite: "https://example.com" }
});
```

To cover incognito cookie stores, first enumerate stores:

```typescript
const stores = await chrome.cookies.getAllCookieStores();
// stores: Array<{ id: string; tabIds: number[] }>
// Call getAll with each storeId to cover all stores
```

**Required manifest entries:**

```json
{
  "permissions": ["cookies"],
  "host_permissions": ["https://*.example.com/*"]
}
```

`host_permissions` must match every domain whose cookies you read. Use `"<all_urls>"` for universal access (triggers a strong permission warning at install time).

**Gotchas:**
- The extension reads `httpOnly` cookies — this is NOT possible from a web page's JS; it is an extension privilege.
- `partitionKey` support requires Chrome 119+. `hasCrossSiteAncestor` requires Chrome 130+. Third-party CHIPS cookies require knowing the correct `topLevelSite`.
- Session cookies (`session: true`) have no `expirationDate`; the Receiver must inject them without `Max-Age`/`Expires` so the remote browser treats them the same way.

---

### 1b. `localStorage` and `sessionStorage`

No dedicated extension API exists for these. Read them via `chrome.scripting.executeScript()` injected into the **MAIN** world.

**API:**

```typescript
chrome.scripting.executeScript({
  target: { tabId: number },
  world: "MAIN",            // MAIN = shares page's JS context, reads real localStorage
  func: () => {
    return {
      localStorage: Object.fromEntries(
        Array.from({ length: localStorage.length }, (_, i) => {
          const k = localStorage.key(i)!;
          return [k, localStorage.getItem(k)];
        })
      ),
      sessionStorage: Object.fromEntries(
        Array.from({ length: sessionStorage.length }, (_, i) => {
          const k = sessionStorage.key(i)!;
          return [k, sessionStorage.getItem(k)];
        })
      ),
    };
  },
}): Promise<InjectionResult[]>
// InjectionResult: { frameId: number, documentId: string, result: any }
```

**Required manifest entries:**

```json
{
  "permissions": ["scripting"],
  "host_permissions": ["https://example.com/*"]
}
```

**Gotchas:**
- `world: "ISOLATED"` (default) gives the content script its **own** isolated `localStorage` that is NOT the page's storage — you get an empty object. You MUST use `world: "MAIN"` to read the page's actual storage.
- `sessionStorage` is per tab and per page load. Capturing it is only meaningful while the tab is open.
- The return value from the injected function must be JSON-serializable. Non-serializable values (functions, undefined) are dropped.
- The page's Content Security Policy (CSP) applies when running in `MAIN` world.
- `executeScript` requires the tab to be fully loaded (or pass `injectImmediately: false` to wait for `document_idle`).

---

### 1c. IndexedDB

No dedicated extension API. Use `world: "MAIN"` injection with the standard IndexedDB Web API.

```typescript
chrome.scripting.executeScript({
  target: { tabId: number },
  world: "MAIN",
  func: async () => {
    const result: Record<string, any[]> = {};
    const dbs = await indexedDB.databases(); // Chrome 76+ — lists all DBs
    // dbs: Array<{ name: string; version: number }>

    for (const { name, version } of dbs) {
      const db: IDBDatabase = await new Promise((res, rej) => {
        const req = indexedDB.open(name!, version);
        req.onsuccess = () => res(req.result);
        req.onerror = () => rej(req.error);
      });
      const storeNames = Array.from(db.objectStoreNames);
      for (const storeName of storeNames) {
        const records: any[] = await new Promise((res, rej) => {
          const tx = db.transaction(storeName, "readonly");
          const req = tx.objectStore(storeName).getAll();
          req.onsuccess = () => res(req.result);
          req.onerror = () => rej(req.error);
        });
        result[`${name}/${storeName}`] = records;
      }
      db.close();
    }
    return result;
  },
});
```

**Limits and gotchas:**
- `indexedDB.databases()` requires Chrome 76+.
- The injected function must return a JSON-serializable value. Binary data (Blobs, ArrayBuffers, typed arrays) inside IDB records will NOT serialize through `executeScript`'s return channel. Workaround: convert to base64 inside the injected function.
- Large IDB databases (e.g. WhatsApp Web stores megabytes of message history) may hit the `executeScript` return-value size limit. Chunk it or stream via `runtime.sendMessage` from the injected script back to the service worker.
- `executeScript` with an `async` function works — Chrome awaits the returned Promise.
- No explicit size limit is documented, but the IPC channel between the page and the extension SW has practical limits (~64 MB); test with heavy sites.

---

## 2. Alt+Y Keyboard Shortcut — `chrome.commands`

**Manifest block:**

```json
{
  "commands": {
    "clone-session": {
      "suggested_key": {
        "default": "Alt+Y",
        "mac": "Alt+Y",
        "windows": "Alt+Y",
        "linux": "Alt+Y"
      },
      "description": "Clone this site's session to the cloud browser"
    }
  }
}
```

Note: on macOS "Alt" maps to the Option key. `"mac": "Alt+Y"` is the correct syntax (not `"Option+Y"`).

**Listener (service worker):**

```typescript
chrome.commands.onCommand.addListener((command: string, tab?: chrome.tabs.Tab) => {
  if (command === "clone-session") {
    // tab is the active tab at the time the shortcut was pressed
  }
});
```

**Restrictions:**
- Maximum 4 suggested keyboard shortcuts per extension.
- `Ctrl+Alt` combinations are prohibited (conflicts with AltGr on European keyboards).
- Users can rebind shortcuts at `chrome://extensions/shortcuts`.
- `Alt+Y` has no known system-level conflicts on Windows/Linux; on macOS the Option key is rarely used for system shortcuts at this key.

---

## 3. Injected UI — Toast and Banner

Both are DOM injection via `chrome.scripting.executeScript()` or a declared content script. No new MV3 restriction on DOM manipulation from either world.

**Recommended approach:** `world: "ISOLATED"` is sufficient for DOM injection (content scripts share the page's DOM even in ISOLATED world; isolation only affects the JS execution context/variable scope). Use shadow DOM to prevent the page's CSS from leaking into extension UI elements.

**Bottom-of-screen toast:**

```typescript
chrome.scripting.executeScript({
  target: { tabId },
  world: "ISOLATED",
  func: (message: string) => {
    const host = document.createElement("div");
    host.id = "__sitetether_toast__";
    const shadow = host.attachShadow({ mode: "closed" });
    shadow.innerHTML = `
      <style>
        :host { position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%);
                z-index: 2147483647; font-family: sans-serif; }
        .toast { background: #1a1a2e; color: #fff; padding: 10px 20px;
                 border-radius: 8px; font-size: 14px; }
      </style>
      <div class="toast">${message}</div>
    `;
    document.body.appendChild(host);
    setTimeout(() => host.remove(), 4000);
  },
  args: ["✓ site cloned — your agent can act on it remotely"],
});
```

**Top overlay banner (persistent, multi-login sites):**

Same pattern but `position: fixed; top: 0; width: 100%;` and no auto-remove timeout. Include a dismiss button that removes the element.

**Declared content script alternative (for persistent banner on matched sites):**

```json
{
  "content_scripts": [{
    "matches": ["https://web.whatsapp.com/*"],
    "js": ["content/banner.js"],
    "run_at": "document_idle"
  }]
}
```

Declared content scripts run automatically on matching pages without needing the user to trigger anything; programmatic injection via `executeScript` runs on demand.

**`chrome.scripting` vs declared content scripts:**
- Declared: always-on for matched URLs, registered at install time, simpler.
- `chrome.scripting.executeScript`: on-demand, can target any tab with host permission, more flexible for dynamic decisions.
- Both can inject into ISOLATED or MAIN world.

---

## 4. Detecting Tab Foreground / Background / Closed

**Service worker side:**

```typescript
// Is a specific tab currently the active (foreground) tab?
const tabs = await chrome.tabs.query({ active: true, windowId: targetWindowId });
// tab.active === true  →  foreground
// tab exists but active === false  →  background
// tab not found  →  closed

// Is any Chrome window focused?
const focusedWindows = await chrome.windows.getAll();
const anyFocused = focusedWindows.some(w => w.focused);

// Watch for tab activation changes:
chrome.tabs.onActivated.addListener(({ tabId, windowId }) => { /* ... */ });
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => { /* ... */ });

// Watch for window focus changes:
chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    // all Chrome windows lost focus (user switched to another app or desktop)
  }
});
```

`chrome.windows.WINDOW_ID_NONE` equals `-1`. `onFocusChanged` fires with `-1` when Chrome loses OS-level focus entirely.

**Tab type shapes:**

```typescript
// Tab (relevant fields)
{ id: number; windowId: number; active: boolean; status: "unloaded"|"loading"|"complete"; url?: string }

// Window (relevant fields)
{ id: number; focused: boolean; state: "normal"|"minimized"|"maximized"|"fullscreen" }
```

**Required permissions:** `"tabs"` (to read `tab.url`), `"windows"`.

**Content-script side (Page Visibility API):**

```typescript
// Inside an injected content script (world: ISOLATED or MAIN)
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") { /* tab came to foreground */ }
  if (document.visibilityState === "hidden")  { /* tab went to background or minimized */ }
});
// Current state:
document.visibilityState; // "visible" | "hidden"
```

Page Visibility API is available in both worlds and requires no special permission.

---

## 5. Heartbeat and Idle/Sleep Detection — `chrome.idle`

### `chrome.idle` API

```typescript
// Set detection threshold (call once, persists for extension lifetime)
chrome.idle.setDetectionInterval(intervalInSeconds: number): void
// Default: 60 seconds. Minimum: 15 seconds (enforced by Chrome, not documented).

// One-shot query
chrome.idle.queryState(detectionIntervalInSeconds: number): Promise<IdleState>
// IdleState: "active" | "idle" | "locked"

// Ongoing listener
chrome.idle.onStateChanged.addListener((state: IdleState) => {
  // fires when system transitions between active / idle / locked
});
```

**Required manifest entry:** `"permissions": ["idle"]`

**Idle vs sleep distinction:**
- `"idle"` means no user input for N seconds. The system is still running; the screen may be on.
- `"locked"` means the screen is locked.
- **There is no API that detects OS-level sleep/suspend/hibernate.** Chrome does not expose this event to extensions.

**Heartbeat approach for sleep detection (recommended):**

The extension service worker cannot detect laptop sleep. The Receiver detects absence of heartbeat:

1. SW sends a heartbeat ping to the Receiver every 20 seconds over the persistent WebSocket.
2. WebSocket activity resets the SW's 30-second idle timer, keeping the SW alive.
3. If the Receiver receives no ping for >45 seconds, it treats the laptop as offline/asleep and switches Live Location to CLOUD.
4. Use `chrome.idle.onStateChanged` to detect `"idle"` or `"locked"` and immediately notify the Receiver rather than waiting for heartbeat timeout — this makes the handoff faster when the user just stepped away.

**`chrome.runtime.onSuspend`** — fires when Chrome terminates the extension's service worker after 30 seconds of inactivity (NOT on laptop sleep). It fires regularly during normal extension idle, not just on shutdown. Useful for cleanup but not for sleep signaling.

**`chrome.alarms`** — alarms fire after device wakes from sleep (once, regardless of how many were missed). Useful for triggering a post-wake re-evaluation of `resolve()`.

```typescript
// Required manifest entry:
// "permissions": ["alarms"]
chrome.alarms.onAlarm.addListener((alarm) => { /* re-run resolve() */ });
chrome.alarms.create("heartbeat", { periodInMinutes: 0.5 }); // fires every 30s
```

---

## 6. Outbound Network from Service Worker

### `fetch()` from MV3 service worker

```typescript
// Inside service worker (background.js / service_worker)
const response = await fetch("https://receiver.tailnet.ts.net:8080/session", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(sessionBundle),
});
```

`fetch()` is native to service workers. No polyfill needed. `XMLHttpRequest` is NOT available in service workers — use `fetch` only.

### WebSocket from MV3 service worker

```typescript
// Requires Chrome 116+ for stable SW lifetime extension
const ws = new WebSocket("wss://receiver.tailnet.ts.net:8080/ws");
ws.onmessage = (event) => { /* resets SW 30s idle timer */ };
// Must send a keepalive message every <30 seconds to keep the SW alive
setInterval(() => ws.send("ping"), 20_000);
```

Add to manifest: `"minimum_chrome_version": "116"`

### `host_permissions` for Tailscale MagicDNS hostnames

Tailscale MagicDNS hostnames follow the pattern `<device>.<tailnet>.ts.net`. Match patterns require specifying individual TLDs — wildcard over a TLD (`"https://*.ts.net/*"`) is NOT supported.

**Correct approach — specific host:**

```json
{
  "host_permissions": [
    "https://receiver.tailnet.ts.net/*"
  ]
}
```

At pair time, the user pastes the pairing code which embeds the Receiver's Tailscale hostname. Request the permission dynamically at pair time using `chrome.permissions.request()`:

```typescript
await chrome.permissions.request({
  origins: [`https://${receiverHostname}/*`]
});
```

Declare this in manifest as `optional_host_permissions`:

```json
{
  "optional_host_permissions": ["https://*/*"]
}
```

This avoids requiring the user to grant broad permissions at install time and requests only the specific Receiver hostname when they pair.

**IP address fallback:** IP addresses work directly — `"https://100.64.0.1/*"` (Tailscale IPs are in the `100.x.x.x` range). Users can also pair via Tailscale IP if they prefer.

**Tailscale + fetch:** Tailscale runs at the OS network level. From Chrome's perspective, `receiver.tailnet.ts.net` is just a DNS name that resolves to a Tailscale IP. `fetch()` and WebSocket work normally; Chrome does not know or care about the transport being Tailscale. No special extension handling required.

---

## Full Manifest Permissions Block

```json
{
  "manifest_version": 3,
  "minimum_chrome_version": "130",
  "permissions": [
    "cookies",
    "scripting",
    "tabs",
    "windows",
    "idle",
    "alarms",
    "storage"
  ],
  "host_permissions": [
    "<all_urls>"
  ],
  "optional_host_permissions": [
    "https://*/*"
  ],
  "background": {
    "service_worker": "background.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content/overlay.js"],
      "run_at": "document_idle"
    }
  ],
  "commands": {
    "clone-session": {
      "suggested_key": {
        "default": "Alt+Y",
        "mac": "Alt+Y",
        "windows": "Alt+Y",
        "linux": "Alt+Y"
      },
      "description": "Clone this site's session to the cloud browser"
    }
  }
}
```

**Note on `<all_urls>` in `host_permissions`:** required to read cookies from any site the user is on. Chrome will show a "Read and change all your data on all websites" permission warning at install. This is unavoidable for a tool that captures sessions from arbitrary sites. For a production release, scope to specific domains if possible, or explain the warning in the onboarding flow.

`minimum_chrome_version: "130"` ensures `partitionKey.hasCrossSiteAncestor` is available (Chrome 130). Drop to `"119"` if `hasCrossSiteAncestor` is not needed.

---

## Recommended Session Bundle JSON Shape

```json
{
  "version": 1,
  "captured_at": "2026-06-27T12:00:00.000Z",
  "origin": "https://example.com",
  "tab_url": "https://example.com/dashboard",
  "user_agent": "Mozilla/5.0 ...",
  "cookies": [
    {
      "name": "session_id",
      "value": "abc123",
      "domain": ".example.com",
      "path": "/",
      "secure": true,
      "httpOnly": true,
      "session": false,
      "expirationDate": 1780000000,
      "hostOnly": false,
      "sameSite": "lax",
      "storeId": "0",
      "partitionKey": null
    }
  ],
  "localStorage": {
    "user_prefs": "{\"theme\":\"dark\"}",
    "token": "eyJ..."
  },
  "sessionStorage": {
    "cart": "[{\"id\":1}]"
  },
  "indexedDB": [
    {
      "dbName": "app-db",
      "version": 3,
      "stores": {
        "messages": [
          { "id": 1, "body": "hello", "ts": 1700000000 }
        ]
      }
    }
  ]
}
```

Binary values in IndexedDB records: base64-encode them inside the injected function and add a `"__b64__": true` marker so the Receiver knows to decode before injecting.

---

## Capability Gaps and Workarounds

| Capability | MV3 Status | Workaround |
|---|---|---|
| Detect OS sleep/hibernate | NOT POSSIBLE — no Chrome API exposes this | Receiver detects heartbeat timeout (>45s silence = laptop offline) |
| `chrome.runtime.onSuspend` as sleep signal | Fires on SW idle termination (every 30s inactivity), NOT on OS sleep | Use only for cleanup, not sleep signaling |
| Wildcard host_permissions over `.ts.net` TLD | NOT SUPPORTED — Chrome blocks TLD wildcards | Use specific hostname or Tailscale IP; request via `optional_host_permissions` at pair time |
| Read localStorage from ISOLATED world | NOT POSSIBLE — ISOLATED world has its own separate storage object | Use `world: "MAIN"` in `executeScript` |
| `XMLHttpRequest` in service worker | NOT AVAILABLE | Use `fetch()` |
| IDB binary data (ArrayBuffer/Blob) over executeScript return | Does not serialize | Convert to base64 inside injected function |
| WebSocket SW lifetime pre-Chrome 116 | SW terminates after 30s, kills WebSocket | Set `minimum_chrome_version: "116"`; send keepalive every 20s |
| CHIPS / partitioned cookies pre-Chrome 119 | `partitionKey` param ignored | Set `minimum_chrome_version: "119"` or handle gracefully |

---

## Sources

- [chrome.cookies API reference](https://developer.chrome.com/docs/extensions/reference/api/cookies) — retrieved 2026-06-27
- [chrome.scripting API reference](https://developer.chrome.com/docs/extensions/reference/api/scripting) — retrieved 2026-06-27
- [Content scripts — concepts](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts) — retrieved 2026-06-27
- [chrome.commands API reference](https://developer.chrome.com/docs/extensions/reference/api/commands) — retrieved 2026-06-27
- [chrome.tabs API reference](https://developer.chrome.com/docs/extensions/reference/api/tabs) — retrieved 2026-06-27
- [chrome.windows API reference](https://developer.chrome.com/docs/extensions/reference/api/windows) — retrieved 2026-06-27
- [chrome.idle API reference](https://developer.chrome.com/docs/extensions/reference/api/idle) — retrieved 2026-06-27
- [chrome.runtime API reference](https://developer.chrome.com/docs/extensions/reference/api/runtime) — retrieved 2026-06-27
- [Extension service worker lifecycle](https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle) — retrieved 2026-06-27
- [Cross-origin network requests](https://developer.chrome.com/docs/extensions/develop/concepts/network-requests) — retrieved 2026-06-27
- [WebSockets in service workers (tutorial)](https://developer.chrome.com/docs/extensions/mv3/tut_websockets/) — retrieved 2026-06-27
- [Match patterns](https://developer.chrome.com/docs/extensions/develop/concepts/match-patterns) — retrieved 2026-06-27
