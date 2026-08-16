# Product memory

`PRD.md`, optional confirmed `principles.md`, and one `features/<id>.md` per active feature are the
only current product truth. The Product Manager owns them. Builders and technical planners only read
them. The technical chronology/dependency source lives separately at `../architecture/roadmap.json`.

When the PRD changes, update its version, supersede removed features in the roadmap, and remove stale
lesson links from the active feature and module indexes. Git history preserves the old state; active
agents read only the current files.
