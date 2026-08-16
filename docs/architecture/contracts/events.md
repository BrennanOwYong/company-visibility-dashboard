# Event and Correlation Contract

## Event envelope

Every event has:

- `event_id`, `name`, `schema_version`, and UTC `occurred_at`.
- `workspace_id`, `actor_id` when known, `aggregate_type`, `aggregate_id`, and `aggregate_version`.
- `interaction_id`, `request_id`, `trace_id`, `span_id`, `job_id`, `build_id`, and
  `provider_request_id` when applicable.
- `source` as `web`, `api`, `worker`, `provider`, `agent`, or `runtime`.
- `outcome` as `started`, `succeeded`, `failed`, `blocked`, `partial`, or `cancelled`.
- `safe_attributes`, restricted by an allowlist for that event name.
- Test-only `ticket_id`, `criterion_id`, and `journey_id` when the event occurs in a test run.

Absent correlation fields are omitted. They are not set to invented values.

## Required event families

### Browser and navigation

`ui.shell.loaded`, `ui.navigation.selected`, `ui.navigation.failed`, `ui.user_action`,
`ui.recovery.selected`, `ui.page_state.rendered`, `ui.navigation.refreshed`, and
`ui.event_stream.reconnected`.

### API and durable work

`api.request.completed`, `api.request.failed`, `job.queued`, `job.claimed`, `job.completed`,
`job.failed`, and `job.lease_reclaimed`.

### Connections and providers

`connection.authorization.started`, `connection.authorization.denied`,
`connection.authorization.completed`, `provider.authorization.completed`,
`connection.capabilities.discovered`,
`connection.state.changed`, `connection.removal.confirmed`, `provider.request.started`,
`provider.request.completed`, `provider.request.failed`, `provider.refresh.completed`, and
`provider.revoke.completed`.

### Memory

`memory.message.received`, `memory.message.redacted`, `memory.clarification.requested`,
`memory.summary.proposed`, `memory.summary.conflict_detected`, `memory.summary.accepted`, and
`memory.summary.rejected`. Page building can also emit `memory.context.selected` with only the
selected accepted version ID.

### Page creation and runtime

`page.conversation.started`, `page.message.received`, `page.request.blocked`,
`page.clarification.requested`, `page.capability_check.completed`, `page.request.confirmed`,
`page.build.queued`, `page.build.started`, `page.agent.completed`,
`page.validation.completed`, `page.build.failed`, `page.published`, `page.view.loaded`,
`page.widget.rendered`, `page.data_state.changed`, and `page.memory_context.compared`.

### Telemetry safety

`telemetry.redaction.failed` and `telemetry.export.failed`.

## Frontend-to-backend chain

A meaningful control click emits `ui.user_action` with a new `interaction_id`. The API receives that
ID, adds a `request_id` and trace, and writes the state event. Jobs copy the original correlation.
Provider and model clients add their returned request IDs. The browser render event continues the
interaction when it is a direct response, or references the build ID for later return visits.

Criterion evidence states the expected ordered event names and validates required shared IDs. A test
must fail when a required precursor event is absent even if the final screen looks correct.

## Safe attribute rules

Allowed attributes include state names, provider key, safe account ID hash, capability key, metric
key, component key, counts, duration, retry number, error class, rule IDs, redaction class, and HTTP
route template. Forbidden attributes include tokens, authorization codes, cookies, headers, raw URLs
with query values, full provider bodies, conversation text, Memory summary text, page-definition text,
and direct personal identifiers.

Logs and traces use the same safe allowlists. Redaction occurs before export. A redaction failure
stops the unsafe export and emits only `telemetry.redaction.failed` to a restricted local sink.

## Metrics

Required measurements include request duration/error by route template, job queue age, job attempts,
build duration/outcome, validation failure by rule, provider duration/outcome/rate limit by provider,
refresh freshness, event-stream reconnects, page data-state counts, redaction counts by class, and
browser journey pass/fail by criterion. Labels must remain bounded and cannot use resource IDs.
