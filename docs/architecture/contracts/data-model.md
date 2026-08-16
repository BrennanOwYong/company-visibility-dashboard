# Data Model Contract

## Common record fields

Workspace records have opaque `id`, trusted `workspace_id`, `version`, `created_at`, and `updated_at`.
Immutable records have no update operation. Time values use UTC ISO 8601 at interfaces and
time-zone-aware database types. User-facing names are never authorization keys.

## Records and invariants

### Identity and tenancy

- `workspace(id, display_name)` is the isolation boundary.
- `actor_membership(actor_id, workspace_id, policy_key, state)` is evaluated into `ActorContext`.
- Every query for a workspace record includes the trusted workspace boundary.

### Provider integration

- `provider_connection(id, workspace_id, provider_key, safe_account_id, safe_display_name,
  secret_ref, state, grants, capability_version, last_verified_at)`.
- `secret_ref` is opaque. It never leaves `provider-integrations`.
- One active connection is unique by workspace, provider, and safe provider account ID.
- `capability_manifest(id, connection_id, version, discovered_at, expires_at, capabilities,
  unavailable_reasons)` is immutable.
- `metric_observation(id, workspace_id, connection_id, canonical_metric, provider_metric,
  dimensions, period_start, period_end, value, unit, source_at, fetched_at, availability)`.
- `availability` is `current`, `delayed`, `empty`, `partial`, or `unavailable`. Only `current` and
  `delayed` can contain a value. `empty` is a valid observed result, not zero.

### Memory

- `memory_conversation(id, workspace_id)` has one active conversation for the first product version.
- `memory_message(id, conversation_id, sequence, actor_kind, redacted_text, redaction_classes,
  created_at)` is immutable and ordered by unique sequence.
- `memory_summary_version(id, conversation_id, parent_id, state, typed_summary, conflict_set,
  created_at, decided_at, decided_by)` is immutable.
- `state` is `proposed`, `needs_clarification`, `accepted`, or `rejected`.
- At most one accepted summary is current. Acceptance changes a current pointer; it does not mutate
  the prior accepted version.

### Page creation and publication

- `page_conversation(id, workspace_id, state)` owns immutable `page_message` records with the same
  redaction and sequence rules as Memory.
- `page_request_snapshot(id, conversation_id, request, memory_summary_version_id,
  capability_manifest_versions, confirmed_by, confirmed_at)` is immutable.
- `page_build(id, request_snapshot_id, attempt, state, progress_code, failure_class,
  recovery_action, candidate_hash, created_at, completed_at)`.
- `page_definition_version(id, workspace_id, page_id, schema_version, definition, request_snapshot_id,
  validation_report, created_at)` is immutable.
- `page(id, workspace_id, current_definition_version_id, state)` points only to a published,
  validated definition.
- `navigation_entry(id, workspace_id, page_id, title, icon_key, position, state)` is created in the
  same transaction that publishes the first page version.
- A failed build cannot change `page.current_definition_version_id`.

### Jobs and events

- `durable_job(id, workspace_id, kind, aggregate_id, state, available_at, lease_owner,
  lease_expires_at, attempt, max_attempts, idempotency_key, payload_ref)`.
- Only one job with the same workspace, kind, and idempotency key can exist.
- `domain_event(id, workspace_id, aggregate_type, aggregate_id, aggregate_version, name, schema_version,
  occurred_at, correlation, safe_attributes)` is immutable.
- Aggregate state and its event record are written in one transaction.

## Retention and deletion

Retention durations are open product decisions. Until set, no automated destructive retention job is
permitted. A future deletion workflow must handle secret revocation, conversations, summaries,
pages, observations, event evidence, legal holds, backups, and generated derivatives as one reviewed
policy. A user-facing delete must never be implemented as an uncoordinated table delete.

