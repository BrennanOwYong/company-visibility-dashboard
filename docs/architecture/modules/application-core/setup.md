# Setup

Local setup needs PostgreSQL, an identity fixture, a local vault adapter that never uses committed
secrets, and worker lease configuration. Setup must expose database, migration, worker, and event
replay health checks. Production identity and vault products remain open.

