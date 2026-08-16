# Feature implementation: dashboard-shell

Product truth: `docs/product/features/dashboard-shell.md`

## Architecture elements used

- `web-experience`: application shell, theme tokens, responsive side menu, route states, and fixed
  destinations.
- `application-core`: authenticated workspace, navigation query, published-page projection, and
  durable event replay.
- `page-system`: authoritative published-page and navigation-entry state.
- `observability`: browser action, request, route, and render correlation.
- Contracts: `http-api.md`, `page-definition.md`, `events.md`, and `security-boundaries.md`.

## Feature-specific implementation

The shell owns fixed entries for Connected Tools, Memory, and page creation. `GET /api/v1/navigation`
adds only current published `navigation_entry` records. A failed or unpublished build cannot appear.
Navigation data loads separately from page data, so a provider outage cannot block the side menu.

Central theme tokens define the soft pastel orange surfaces, text, focus, selection, warning, and
error colors. Selection and status also use text, icons, and accessible attributes. The narrow layout
uses an accessible menu disclosure while retaining every primary destination and the plus action.

## Inputs, outputs, and contracts

- Input: authenticated browser route and meaningful navigation action with `interaction_id`.
- Input: navigation response with fixed entries plus published page title and approved `icon_key`.
- Output: selected route, durable shell, loading/empty/unavailable state, or retry action.
- A generated page entry points only to a page owned by the same workspace and a validated current
  definition.
- The browser cannot set workspace ownership or add a destination locally.

## Data and control flow

1. Server-rendered or initial browser state establishes trusted actor and workspace context.
2. The shell renders fixed destinations immediately and requests saved navigation.
3. `application-core` selects authorized published entries in stable order.
4. The browser merges the result into the shell and emits `ui.shell.loaded`.
5. A user selection emits `ui.user_action`, navigates, and emits success or failure state.
6. `page.published` on the event stream causes a navigation refresh; reconnect replay prevents a
   missed publication from hiding the entry.

## Failure and recovery behavior

- Navigation-query failure keeps fixed destinations and known saved entries, marks saved data
  unavailable, and offers retry.
- Page-route failure does not replace the shell. It renders a route error with retry and other
  navigation still active.
- An unknown or unauthorized page returns a safe not-found state without confirming its existence.
- Event-stream failure changes no authoritative state; the client reconnects with the last event ID
  and also refreshes navigation.
- Long labels, enlarged text, narrow width, and many saved entries use wrapping, scrolling, and
  accessible disclosure, not hidden primary controls.

## Required observability

Successful selection chain:

`ui.user_action -> ui.navigation.selected -> api.request.completed -> ui.page_state.rendered`

Failure and recovery chain:

`ui.user_action -> ui.navigation.selected -> api.request.failed -> ui.navigation.failed -> ui.recovery.selected`

Publication update chain:

`page.published -> ui.navigation.refreshed -> ui.page_state.rendered`

Events share `interaction_id` for direct actions and `page_id`/`build_id` for later publication. Safe
attributes include route template, entry kind, state, count, duration, and error class.

## Objective verification

| Done criterion | Objective evidence |
|---|---|
| DC-01 | Browser visual tokens, shell landmark, side-menu landmark, and screenshot at supported size |
| DC-02 | Empty-workspace journey proves all fixed entries and useful empty state |
| DC-03 | Publish fixture, reload browser, and verify saved icon/tab comes from server navigation |
| DC-04 | Browser journeys for every fixed entry and one generated entry; selected state and event chain |
| DC-05 | Forced page and navigation failures prove shell continuity, safe error, and retry |
| DC-06 | Automated accessibility scan plus keyboard, 200% text, and narrow-viewport journeys |

The web-control tester uses the exact positive and negative flows in the product feature and records
screenshots plus correlated browser/API evidence.

## Release and runtime considerations

- Theme tokens and navigation response need visual regression fixtures.
- Page-definition icon keys must remain compatible with the deployed browser component registry.
- Navigation and page routes must remain backward compatible during rolling deployment.
- Exact palette, icon choice behavior, role visibility, and supported device matrix remain open.
