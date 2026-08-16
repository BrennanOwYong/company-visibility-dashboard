# Current Decisions

- The page-building agent outputs a declarative page definition, not executable production code.
- Confirmed requests pin Memory and capability versions.
- Deterministic validation and fixture rendering decide publication.
- Publication and navigation creation are one transaction.
- Published definitions are immutable and the prior version survives failure.
- Runtime reads normalized observations through bounded typed queries.

Model provider, cost and time limits, revision approval, icon selection, and page retention remain open.

