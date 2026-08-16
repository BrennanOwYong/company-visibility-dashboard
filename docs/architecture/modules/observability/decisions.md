# Current Decisions

- Use durable domain events for product progress/replay and OpenTelemetry-compatible signals for
  operations; they have different duties but share correlation.
- Use allowlisted structured attributes only.
- Carry browser `interaction_id` into API, job, provider/model, and render evidence.
- Treat important precursor events as part of criterion evidence.
- Stop unsafe export when redaction validation fails.

Telemetry vendor, production retention, sampling, and alert thresholds remain open.

