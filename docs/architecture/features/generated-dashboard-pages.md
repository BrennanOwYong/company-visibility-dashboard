# Feature implementation: generated-dashboard-pages

Product truth: `docs/product/features/generated-dashboard-pages.md`

## Architecture elements used

- `page-system`: validated immutable page definition, atomic publication, current version, normalized
  page query, widget availability, context, and retry.
- `web-experience`: approved component renderer, source/freshness status, context view, partial states,
  return navigation, and recovery actions.
- `provider-integrations`: normalized observations, capability and connection state, refresh jobs.
- `organization-memory`: pinned accepted summary version and later conflict comparison.
- `application-core` and `observability`: persistence, events, idempotency, access, and evidence.
- Contracts: `page-definition.md`, `data-model.md`, `http-api.md`, `provider-adapter.md`, `events.md`,
  and `security-boundaries.md`.

## Feature-specific implementation

A successful build creates an immutable `page_definition_version`. Publication transactionally sets
the current version, creates or updates its `navigation_entry`, marks the build published, and writes
`page.published`. Before that transaction, the page does not appear as successful.

The runtime uses only approved components and normalized metric requests. It reads observations from
PostgreSQL and can enqueue refresh work without blocking shell or page load. Each widget receives an
independent data state with source and freshness context.

The context view loads the redacted original conversation and the immutable purpose/how-it-works
summary associated with the published definition. It also records the accepted Memory version that
guided creation. A newer Memory version can produce a review notice; it never silently changes the
published purpose.

## Inputs, outputs, and contracts

- Input: authorized page ID, current definition version, optional bounded time range/filter, and
  `interaction_id`.
- Definition input: approved component keys, metric requests, transformations, empty/unavailable
  behavior, and pinned source versions.
- Data output per widget: typed values only when allowed, unit, source/fetch times, availability, and
  recovery code.
- Context output: redacted creation messages, purpose summary, how-it-works summary, creation Memory
  version, and current-meaning conflict state.
- No browser input can add a provider query, network target, SQL expression, or secret reference.

## Data and control flow

1. A completed validation report authorizes atomic publication.
2. `page.published` updates event-stream clients; navigation refresh exposes the new destination.
3. Page open loads the current definition and authorized context independently from metric data.
4. The query planner validates current workspace ownership and capability, then reads normalized
   observations for bounded requests.
5. The renderer displays each widget's value and availability state through the fixed registry.
6. A needed refresh enqueues work; later `page.data_state.changed` updates the open page.
7. Return visits resolve the same stable page ID to the current published version and stored context.
8. Current accepted Memory is compared to the pinned version only to produce review state, not an
   automatic revision.

## Failure and recovery behavior

- Expired or revoked connection keeps the page/context and marks affected widgets unavailable with
  reconnect action. It never presents old values as current.
- A true no-result response is `empty`, distinct from zero and transport failure.
- One failed source sets only dependent widgets partial/unavailable when others are valid.
- Page query failure keeps navigation and context available and offers retry.
- A page-definition render error is isolated to the affected component, records a validation escape,
  and never executes fallback generated code.
- Memory conflict shows a review notice. The page stays on its prior definition until an explicit
  revision flow is defined and approved.
- Failed construction or publication keeps the last current definition and creates no false new
  navigation entry.

## Required observability

Publication and first view chain:

`page.validation.completed -> page.published -> ui.navigation.refreshed -> ui.user_action -> page.view.loaded -> page.widget.rendered -> ui.page_state.rendered`

Partial failure chain:

`provider.request.failed -> provider.refresh.completed -> page.data_state.changed -> page.widget.rendered -> ui.page_state.rendered`

Return visit chain:

`ui.user_action -> page.view.loaded -> page.widget.rendered -> ui.page_state.rendered`

Memory conflict chain:

`memory.summary.accepted -> page.memory_context.compared -> page.data_state.changed -> ui.page_state.rendered`

Events include definition/schema version, approved component/metric keys, availability, freshness
class, source count, duration, build ID, and rule IDs. They exclude metric values, conversation text,
summary text, definition content, and credentials.

## Objective verification

| Done criterion | Objective evidence |
|---|---|
| DC-01 | Atomic publish test plus browser event-stream journey proves one saved destination after success only |
| DC-02 | Provider fixtures and page query prove actual normalized information, source, and visible state |
| DC-03 | Context browser/API test proves original redacted conversation and immutable purpose/how summary |
| DC-04 | Process restart and browser return prove durable page, navigation, conversation, and summaries |
| DC-05 | Empty, delayed, expired, and unavailable fixtures prove distinct visible states and no false current value |
| DC-06 | Multi-source fault proves valid widgets stay usable and failed widgets show recovery |
| DC-07 | Accept changed Memory, revisit page, and prove review notice with unchanged definition/purpose |
| DC-08 | Agent, validator, and publication failures prove no false destination and preserved retry request |

Browser evidence records screenshots for current, delayed, empty, partial, unavailable, context, and
return states plus the correlated event chains.

## Release and runtime considerations

- A release must keep readers and components for every active published page schema.
- Provider observations need retention and freshness policy before production capacity planning.
- Page revision, share, archive, delete, icon control, context access, and retention remain open
  product decisions; the architecture reserves version and policy seams but does not expose them.
- Production alarms cover render escapes, unavailable/partial rate, refresh delay, failed publication,
  and definitions that reference a removed capability.
