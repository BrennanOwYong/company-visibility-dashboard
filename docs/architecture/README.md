# Technical memory

`overview.md` describes the current architecture derived from all current product features together.
`features/<id>.md` zooms into how each feature uses that architecture. `roadmap.json` contains only
presentation chronology and real merged-code/contract dependencies. Each active module
owns a directory under `modules/` with build, test, setup, iterate, logs-feedback, decisions, and
current-PRD lessons. Contracts are deterministic seams between modules and features.

These documents describe the current system. Remove active links to superseded features and obsolete
lessons when the PRD changes. Preserve history in Git and delivery AARs, not in active guidance.
