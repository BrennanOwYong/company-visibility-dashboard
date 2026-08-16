# Current Decisions

- Store a redacted append-only conversation and separate immutable summary versions.
- Require explicit acceptance before a proposal becomes current.
- Pin the exact accepted summary version into each confirmed page request.
- Use capability-safe account context but never secret values.
- Preserve the prior accepted version through conflict, rejection, interruption, or model failure.

Shared/team scope, approval policy, rollback, retention, and model provider remain open.

