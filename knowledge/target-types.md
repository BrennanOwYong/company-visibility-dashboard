# Target types — the factory builds any software shape, not just web pages

The planning layer is already shape-agnostic: the architecture-derivation skill identifies the
system shape as it emerges (layered service, data/ML pipeline, browser extension, CLI, library,
event-driven) and forbids assuming a server-and-database stack. What varies per shape is the
TESTING SURFACE: what `test_command` means, what the builder's own tests drive, and what the
validator drives. This file is the standing convention for all three consumers (builder,
validator, user-test card SETUP). KIV item 1 raised this gap; the site cloner (extension +
receiver server + deploy scripts) is the first multi-shape exercise of it.

`test_command` contract, universal: ONE command (or URL) that brings the feature to a testable
state for a stranger with only the ticket. kanban-update refuses NEEDS_TESTING while it is
blank. A `port:` is assigned at NEEDS_TESTING for every shape but only network-serving shapes
use it; others ignore it.

| Shape | test_command shape | Builder/validator drive it via | Assertions look like |
|---|---|---|---|
| Web page / web app | serve command + URL (`scripts/serve.sh $PORT` → `http://localhost:$PORT`) | agent-browser (snapshot → interact → re-snapshot → screenshot) | UI states, flows, UX baseline, no console errors |
| Web server / API | start command; docs the base URL (`scripts/dev-server.sh $PORT`) | curl/httpie per endpoint; agent-browser only if it ships an admin UI | status codes, response shapes (validated against the iface contract schema), auth behavior, idempotency of webhook ingress |
| Chrome extension | build + load-unpacked instructions (`scripts/build-ext.sh`; then chrome://extensions → Load unpacked → dist/) plus the page/popup URL to exercise | agent-browser against a Chrome instance with the extension loaded; popup/options pages are just pages | permissions granted match manifest, popup flows, content-script effects on a fixture page, background worker events |
| Desktop app (Electron etc.) | launch command (`scripts/run-desktop.sh`) + the screen to reach | agent-browser if the shell exposes a debug port; otherwise the app's own driver + screenshots | window flows, menu actions, persistence across relaunch |
| CLI / script / internal tool | the invocation itself (`scripts/tool.sh --fixture tests/fixture.json`) | direct execution; assert on stdout/stderr, exit codes, produced files | exit 0/non-0 per case, output matches contract, idempotent re-run, `--help` accurate |
| Library / module | its test-runner command (`npm test -- --filter <module>`) plus one example-usage script | run the examples as a consumer would, not just the unit suite | public API behaves per iface contract; example compiles/runs cold |
| Pipeline / batch job | run command on a pinned fixture dataset (`scripts/run-pipeline.sh tests/fixture/`) | execute, then assert on outputs | output schema, determinism/reproducibility on the fixture, checkpoint/resume, versioned artifacts |

Cross-shape rules:
- The UX baseline applies to every USER-FACING surface of any shape (an extension popup and a
  CLI's progress output both count: no dead time without feedback, designed empty/error states);
  it does not apply to headless seams.
- External-system seams in any shape are validated against the iface contract with the real
  system when infra exists, otherwise against the contract's recorded shapes with mocks — and
  the ticket carries `--needs-infra` so the gap surfaces as NEEDS_SETUP, never as a silent mock
  in a "passing" validation.
- The gold-standard rubric applies per shape by dropping non-applicable criteria and
  re-weighting (a CLI has no criterion D auth unless it talks to accounts; criterion A visual
  craft reads as output/UX craft for terminal tools). The sanity agent states which criteria it
  dropped and why.
- Non-web shapes with un-drivable surfaces (mobile simulators, OS-level dialogs) are still open
  (KIV item 1); the first extension build must record what was done as a lesson rather than
  silently improvising.

## References
- knowledge/technical/research/extension-capture.md and receiver-browser.md — the site cloner's
  extension + server shapes, researched with official-doc links
- KIV item 1 (test state loading for non-web targets) — kept on main:knowledge/KIV.md
