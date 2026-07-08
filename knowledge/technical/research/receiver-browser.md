# Receiver Browser Implementation — Research

Retrieved: 2026-06-27. All findings from official docs; see Sources section.

---

## 1. Session Injection

### 1a. Cookies — `browserContext.addCookies()`

```typescript
await browserContext.addCookies(cookies: CookieParam[])
```

`CookieParam` shape (all fields):

```typescript
interface CookieParam {
  name: string           // required
  value: string          // required
  url?: string           // required if domain+path not provided
  domain?: string        // required (with path) if url not provided; prefix with "." for subdomains
  path?: string          // required when using domain instead of url
  expires?: number       // Unix time in seconds; -1 = session cookie
  httpOnly?: boolean
  secure?: boolean
  sameSite?: "Strict" | "Lax" | "None"
  partitionKey?: string  // partitioned third-party cookies (CHIPS); experimental
}
```

Either `url` or both `domain` + `path` must be present per cookie.

### 1b. storageState — `browserContext.storageState()`

```typescript
await browserContext.storageState(options?: {
  indexedDB?: boolean    // default false; requires Playwright >= 1.51
  path?: string          // if set, saves JSON to disk
}): Promise<StorageState>
```

Return shape:

```typescript
interface StorageState {
  cookies: Array<{
    name: string
    value: string
    domain: string
    path: string
    expires: number       // Unix seconds
    httpOnly: boolean     // included regardless of flag value
    secure: boolean
    sameSite: "Strict" | "Lax" | "None"
    // partitionKey NOT in return shape
  }>
  origins: Array<{
    origin: string
    localStorage: Array<{ name: string; value: string }>
    // indexedDB entries appear here when indexedDB:true
  }>
}
```

Captures: cookies (including httpOnly), localStorage, optionally IndexedDB.

Does NOT capture: sessionStorage, Service Worker caches, Cache API, WebSocket connections, in-memory JS state.

`browserContext.addCookies()` replaces existing cookies.
`page.context().storageState()` only returns what the context has visited (origin-scoped).

### 1c. localStorage / sessionStorage injection — `addInitScript`

```typescript
await browserContext.addInitScript(
  script: string | Function | { path?: string; content?: string },
  arg?: Serializable
): Promise<Disposable>
```

The script runs after the document is created but before any page scripts execute. This is the correct injection point for localStorage and sessionStorage:

```typescript
await context.addInitScript((state) => {
  for (const [k, v] of Object.entries(state.localStorage)) {
    window.localStorage.setItem(k, v)
  }
  for (const [k, v] of Object.entries(state.sessionStorage)) {
    window.sessionStorage.setItem(k, v)
  }
}, { localStorage: {...}, sessionStorage: {...} })
```

Applies to all pages and frames in the context. Evaluation order across multiple `addInitScript` calls is undefined.

### 1d. IndexedDB

`storageState({ indexedDB: true })` captures IndexedDB since Playwright 1.51. The docs state: "If your application uses IndexedDB to store authentication tokens, like Firebase Authentication, enable this." The JSON structure for IndexedDB entries is not documented in detail — it is bundled inside the `origins` array alongside localStorage.

For Playwright versions before 1.51, or when using raw CDP, inject IndexedDB via `page.evaluate()` after navigation using the IndexedDB API directly:

```typescript
await page.evaluate(async (dbDump) => {
  // open the DB, iterate object stores, put() each record
}, serializedDump)
```

⚠ IndexedDB injection via evaluate() runs after page scripts start; a race condition exists if the page reads IndexedDB before evaluate() completes.

---

## 2. Headful Chromium on Headless Linux

### 2a. `launchPersistentContext` signature

```typescript
browserType.launchPersistentContext(
  userDataDir: string,     // path to Chrome User Data Dir; "" creates a temp dir
  options?: LaunchPersistentContextOptions
): Promise<BrowserContext>
```

Key options:

```typescript
{
  headless?: boolean            // false for headed mode
  args?: string[]               // Chromium command-line flags
  executablePath?: string       // path to Chromium binary if not using bundled
  channel?: string              // "chrome", "chromium", "msedge"
  env?: Record<string, string>
  timeout?: number              // launch timeout ms
  viewport?: { width: number; height: number } | null
  screen?: { width: number; height: number }
  slowMo?: number
  ignoreHTTPSErrors?: boolean
  bypassCSP?: boolean
  userAgent?: string
  locale?: string
  timezoneId?: string
}
```

Note: "Browsers do not allow launching multiple instances with the same User Data Directory." One Receiver = one userDataDir.

Note: "Automating the default Chrome user profile is not supported." Use a dedicated automation profile.

`launchPersistentContext` returns a `BrowserContext` directly, not a `Browser`. There is no separate `browser.newContext()` call.

### 2b. Headed mode on Linux — Xvfb

Headed Chromium on Linux requires a display server. Playwright docs state: "On Linux agents, headed execution requires Xvfb to be installed."

Option A — `xvfb-run` prefix:
```bash
xvfb-run node receiver.js
```

Option B — start Xvfb separately and set `DISPLAY`:
```bash
Xvfb :99 -screen 0 1280x1024x24 &
DISPLAY=:99 node receiver.js
```

Pass `DISPLAY` into the process env and include it in `launchPersistentContext` `env` option if Playwright doesn't inherit it automatically.

### 2c. Required Chromium flags on Linux

```typescript
args: [
  '--no-sandbox',              // required when running as root; also common in cloud VMs
  '--disable-setuid-sandbox',  // companion to --no-sandbox
  '--disable-dev-shm-usage',   // prevents /dev/shm exhaustion in constrained containers
  '--disable-gpu',             // GPU unavailable on most headless Linux; prevents crashes
  `--remote-debugging-port=9222`,  // exposes CDP
  '--remote-debugging-address=127.0.0.1',  // bind only to loopback; Tailscale handles external
]
```

For Docker: add `--ipc=host` to the `docker run` command (not a Chromium flag) to prevent Chromium OOM crashes.

### 2d. `--headless=new` vs `headless: false` + Xvfb

`headless: false` + Xvfb: runs real headed Chromium with a virtual display. Sites that detect headless via `navigator.webdriver` or UA strings see a genuine headed browser.

`--headless=new` (set via `args`: `['--headless=new']` with `headless: false`): runs the newer Chromium headless mode which is closer to headed than the old headless shell, but still technically headless. Some fingerprinting checks can detect it. For WhatsApp Web and Telegram Web, use real headed + Xvfb.

### 2e. Headless detection by sites

Sites fingerprint headless via: `navigator.webdriver`, WebGL renderer, missing plugins, missing fonts, canvas noise, `chrome.runtime` absence. Headed + Xvfb bypasses most of these. If additional fingerprint hardening is needed, use a stealth wrapper (e.g. `playwright-extra` + `puppeteer-extra-plugin-stealth`), but this is outside official Playwright docs.

---

## 3. CDP Port Exposure and Remote Connection

### 3a. `--remote-debugging-port` behavior

`--remote-debugging-port=9222` makes Chromium listen on `localhost:9222` (loopback only by default).

`--remote-debugging-address=0.0.0.0` opens it to all interfaces — do NOT use this; bind to loopback and route through Tailscale instead.

`--remote-debugging-port=0`: Chromium picks a free port, writes it to stderr and to a file named `DevToolsActivePort` in the user data directory.

### 3b. `/json/version` endpoint

```
GET http://localhost:9222/json/version
```

Response shape:

```json
{
  "Browser": "Chrome/72.0.3601.0",
  "Protocol-Version": "1.3",
  "User-Agent": "...",
  "V8-Version": "...",
  "WebKit-Version": "...",
  "webSocketDebuggerUrl": "ws://localhost:9222/devtools/browser/{guid}"
}
```

Two WebSocket target types:
- Browser target: `ws://localhost:PORT/devtools/browser/{guid}` — controls the whole browser
- Page target: `ws://localhost:PORT/devtools/page/{guid}` — controls one tab

### 3c. `browserType.connectOverCDP()` signature

```typescript
chromium.connectOverCDP(
  endpointURL: string,   // "http://localhost:9222/" or ws://... URL
  options?: {
    headers?: Record<string, string>  // additional HTTP headers for handshake
    slowMo?: number
    timeout?: number      // default 30000 ms
    isLocal?: boolean     // enables optimizations when Playwright and browser are on same host
    noDefaults?: boolean  // skips Playwright's default overrides
    artifactsDir?: string
  }
): Promise<Browser>
```

Pass `http://localhost:9222/` — Playwright fetches `/json/version` to resolve the WebSocket URL automatically.

Protocol note from official docs: "This connection is significantly lower fidelity than the Playwright protocol connection via browserType.connect()." CDP does not support all Playwright abstractions (e.g. route interception has limits, some events are not available).

### 3d. Non-Playwright CDP clients

Any CDP-speaking client can attach to `--remote-debugging-port`. Chrome 63+ supports multiple simultaneous clients. CDP clients in Python (`pychrome`), Go (`chromedp`), Java, and JavaScript (`chrome-remote-interface`, Puppeteer) all work. When a client disconnects, Chromium fires `Inspector.detached`.

### 3e. `connectOverCDP` vs `browser.connect()`

| | `connectOverCDP` | `browser.connect(wsEndpoint)` |
|---|---|---|
| Protocol | Raw CDP | Playwright protocol (higher-level) |
| Server-side requirement | `--remote-debugging-port` flag | `browserType.launchServer()` |
| Fidelity | Lower — some features absent | Full Playwright feature set |
| Browser support | Chromium only | All (Chromium, Firefox, WebKit) |
| External CDP clients | Yes — any CDP client works | No — only Playwright |

For SiteTether: use `connectOverCDP`. The AI agent needs raw CDP for programmatic control, and any future non-Playwright agent can attach to the same port.

---

## 4. Keeping Browser Alive (systemd)

### 4a. systemd service unit

```ini
# /etc/systemd/system/sitetether-receiver.service
[Unit]
Description=SiteTether Receiver
After=network.target

[Service]
Type=simple
User=receiver
WorkingDirectory=/opt/sitetether/receiver
Environment=DISPLAY=:99
Environment=NODE_ENV=production
ExecStartPre=/usr/bin/Xvfb :99 -screen 0 1280x1024x24
ExecStart=/usr/bin/node /opt/sitetether/receiver/index.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Or run Xvfb as a separate service and make this unit depend on it.

### 4b. Crash recovery and session re-injection

`launchPersistentContext` with a persistent `userDataDir` means cookies and localStorage survive a Chromium crash — Chromium writes them to disk. On restart, just call `launchPersistentContext` again with the same `userDataDir`; no explicit re-injection needed for cookies and localStorage.

⚠ sessionStorage is in-memory only and is lost on crash. Re-inject it via `addInitScript` on each launch.

⚠ IndexedDB in userDataDir is on disk and survives crashes if the browser wrote it before crashing. Playwright's `storageState({ indexedDB: true })` can snapshot it periodically as a fallback.

### 4c. Process watchdog pattern

```typescript
async function launchWithWatchdog(userDataDir: string): Promise<void> {
  let context: BrowserContext | null = null
  while (true) {
    context = await chromium.launchPersistentContext(userDataDir, {
      headless: false,
      args: CHROMIUM_ARGS,
    })
    const browser = context.browser()
    await new Promise<void>((resolve) => {
      browser?.on('disconnected', () => resolve())
    })
    await new Promise(r => setTimeout(r, 5000)) // back-off before restart
  }
}
```

---

## 5. Singleton Detection

### 5a. WhatsApp Web

WhatsApp Web shows a modal with text "WhatsApp is open in another window. Click here to use WhatsApp in this window." when the session is taken over elsewhere. Detect via:

```typescript
await page.waitForSelector('[data-testid="confirm-popup"]', { timeout: 0 })
// or watch for text:
await page.waitForSelector('text=WhatsApp is open in another window', { timeout: 0 })
```

The page does not navigate away — the overlay blocks interaction. If detected, emit a `SESSION_STOLEN` event and optionally click the "Use here" button to reclaim the session.

### 5b. Telegram Web

Telegram Web shows a "You were logged out" message or navigates to the login screen when the session is invalidated. Detect via:

```typescript
// K version (web.telegram.org/k)
await page.waitForSelector('.auth-wrapper', { timeout: 0 })
// Or watch URL change:
page.on('framenavigated', (frame) => {
  if (frame === page.mainFrame() && frame.url().includes('#login')) {
    emitSessionLost()
  }
})
```

### 5c. General approach for other singleton sites

Use a `MutationObserver` + `page.exposeFunction` pattern to watch DOM for auth-loss signals without polling:

```typescript
await page.exposeFunction('onAuthLost', () => emitSessionLost())
await page.addInitScript(() => {
  const observer = new MutationObserver(() => {
    // check for logout indicators: login forms, session-expired banners
    if (document.querySelector('.session-expired, #login-form')) {
      (window as any).onAuthLost()
    }
  })
  observer.observe(document.body, { childList: true, subtree: true })
})
```

Also watch `page.on('response')` for HTTP 401/403 on API calls as a secondary signal.

---

## 6. Heartbeat Listener Design

The Receiver runs a lightweight HTTP or WebSocket server alongside Chromium. The controlling agent sends a heartbeat every N seconds. If the Receiver misses M consecutive heartbeats, it transitions to PAUSE state (Chromium continues running but the CDP port is closed or the session is suspended).

Minimal design:

```typescript
// Receiver side
import http from 'http'

let lastHeartbeat = Date.now()
const HEARTBEAT_TIMEOUT_MS = 30_000

const server = http.createServer((req, res) => {
  if (req.url === '/heartbeat' && req.method === 'POST') {
    lastHeartbeat = Date.now()
    res.writeHead(200).end('ok')
  }
})
server.listen(8765, '127.0.0.1') // Tailscale-routable

setInterval(() => {
  if (Date.now() - lastHeartbeat > HEARTBEAT_TIMEOUT_MS) {
    pauseSession()
  }
}, 5000)
```

RUN/RUN_HERE/PAUSE state machine:
- `RUN`: Chromium running, CDP port open, heartbeat expected from remote agent.
- `RUN_HERE`: Chromium running, CDP port closed, human is using the browser locally via VNC/noVNC.
- `PAUSE`: Chromium running (session preserved), CDP port closed, no agent activity. Transitions to RUN on next agent connect.

Expose state transitions via the same HTTP server:
```
POST /control  body: { "state": "RUN" | "RUN_HERE" | "PAUSE" }
GET  /status   returns: { "state": "...", "cdpPort": 9222 | null }
```

---

## 7. What Cannot Be Reliably Injected

| Data | Status | Implication for SiteTether |
|---|---|---|
| Cookies (non-partitioned) | Injected via `addCookies()` | Works reliably |
| localStorage | Injected via `addInitScript()` before nav | Works reliably |
| sessionStorage | ⚠ NOT captured by `storageState()` | Must inject via `addInitScript()` from a separately-captured dump; values lost on tab/process restart |
| IndexedDB | Injected via `storageState({ indexedDB: true })` (Playwright >= 1.51) | Works if using Playwright >= 1.51; older versions need `page.evaluate()` injection with race-condition risk |
| CHIPS / partitioned cookies | ⚠ `partitionKey` field is experimental | Browser support is partial; do not rely on round-tripping partitionKey |
| Service Worker registrations | ⚠ Not in `storageState()` | Service Workers re-register on first page load; usually fine, but cached API responses will not be restored |
| Cache API (CacheStorage) | ⚠ Not capturable | First load after restore will hit network, not cache |
| In-memory JS state | ⚠ Not capturable | Cannot resume an in-memory auth flow mid-session |
| WebSocket connections | ⚠ Not capturable | All WS connections (including WhatsApp/Telegram's persistent socket) drop on restart; the page must re-establish them on load |
| WebCrypto keys (non-extractable) | ⚠ Impossible | Keys marked `extractable: false` cannot leave the browser; any auth that depends on them cannot be migrated |

---

## Sources

All URLs fetched 2026-06-27.

1. `browserContext.addCookies()` — https://playwright.dev/docs/api/class-browsercontext#browser-context-add-cookies
2. `browserContext.storageState()` — https://playwright.dev/docs/api/class-browsercontext#browser-context-storage-state
3. `browserType.launchPersistentContext()` — https://playwright.dev/docs/api/class-browsertype#browser-type-launch-persistent-context
4. `browserType.connectOverCDP()` — https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp
5. Playwright browsers / headless modes — https://playwright.dev/docs/browsers
6. Playwright CI / Xvfb — https://playwright.dev/docs/ci
7. `browserContext.addInitScript()` — https://playwright.dev/docs/api/class-browsercontext#browser-context-add-init-script
8. Chrome DevTools Protocol overview — https://chromedevtools.github.io/devtools-protocol/
9. Puppeteer BrowserContext API — https://pptr.dev/api/puppeteer.browsercontext
