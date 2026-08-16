# Current Decisions

- One adapter is the sole owner of each provider API.
- Capability manifests state actual account support and are immutable versions.
- Credential material lives in `SecretVault`; product state keeps opaque references only.
- Refresh occurs in durable jobs and writes normalized observations with explicit availability.
- Provider failures are converted to stable product recovery classes.

The first provider set, refresh mode, and freshness targets remain open.

