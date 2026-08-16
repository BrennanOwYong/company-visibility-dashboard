---
name: roadmap-and-branching
description: Create or revise the technical implementation roadmap after product requirements and the whole-project architecture are settled. Use when sequencing feature work, declaring dependencies, or regenerating the project kanban DAG.
---

# Roadmap and branching

Read `docs/product/PRD.md`, `docs/product/principles.md`, every active
`docs/product/features/<id>.md`, and the current architecture before writing the roadmap.

1. Write the smallest coherent whole-project architecture first.
2. Write `docs/architecture/features/<id>.md` for each feature. Map product outcomes to named
   modules, contracts, flows, failure behavior, observability, and objective verification.
3. Write `docs/architecture/roadmap.json` using this shape:

```json
{
  "schema_version": 1,
  "prd_version": 1,
  "features": [
    {
      "id": "stable-slug",
      "title": "Human title",
      "doc": "docs/product/features/stable-slug.md",
      "architecture": "docs/architecture/features/stable-slug.md",
      "depends_on": [],
      "subjective_ux": false,
      "needs_infra": [],
      "test": {
        "driver": "browser|api|code",
        "launcher": "bin/project-test",
        "landing_path": "/",
        "health_path": "/health",
        "timeout_seconds": 60
      }
    }
  ]
}
```

Array order is the intended presentation chronology. `depends_on` is the only build gate. Add an
edge only when the dependent feature requires code or a contract that must already be merged. Do
not encode computed waves, status, agent identity, ports, or branch names.

Run `bin/roadmap-sync --sync-kanban`. Fix every missing document, dangling edge, duplicate, or cycle
it reports. The program computes levels and readiness; never hand-author them.

Do not edit product requirements. A changed product outcome returns to the Product Manager.
