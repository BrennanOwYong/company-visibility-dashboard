# Build

Build the versioned page-definition schema, validator, component catalog metadata, agent client,
build state machine, and page query planner as separate packages inside one module boundary. The
trusted validator and runtime share the same schema version. Agent output is data, never imported
source code.

