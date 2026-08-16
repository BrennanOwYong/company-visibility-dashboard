# Build

Use the shared TypeScript workspace. Generate database and interface types from versioned contracts.
The server and worker come from the same release and may not carry different contract versions.
Database migrations are ordered, reviewed artifacts and must support the prior release during rollout.

