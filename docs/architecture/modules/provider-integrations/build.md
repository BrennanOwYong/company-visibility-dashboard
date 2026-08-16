# Build

Build each provider adapter against the shared canonical contract. Provider packages may depend on
their service client and shared transport, vault, normalization, and telemetry interfaces. Other
modules may not import provider client libraries. Pin and review external client versions.

