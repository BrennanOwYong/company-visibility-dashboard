---
name: clean-code
description: Apply context-sensitive, non-obvious design and refactoring heuristics derived from Robert C. Martin's Clean Code when implementing or reviewing project code. Use for boundary design, error models, cohesion, tests, concurrency, and refactoring decisions; let repository tools own ordinary formatting and style.
---

# Apply Clean Code selectively

Codex already knows ordinary naming, formatting, small-function, dead-code, and comment hygiene. Do
not turn those basics into a checklist unless the repository lacks automated enforcement.

Use these decision heuristics when the ticket makes them relevant:

- Choose objects when new kinds of behavior-bearing entities are expected; choose data structures
  when new operations over stable shapes are expected. Avoid hybrids that expose representation and
  also claim behavioral encapsulation. See `chapters/ch06-objects-and-data-structures.md`.
- Wrap external libraries and vendor types at owned boundaries. Write learning tests that capture
  the behavior relied upon so upgrades fail visibly. See `chapters/ch08-boundaries.md`.
- Classify failures according to what callers can do about them, and attach operation context.
  Model expected alternatives explicitly instead of using exceptions as normal flow. See
  `chapters/ch07-error-handling.md`.
- Treat low cohesion—a subset of methods repeatedly using a subset of state—as evidence that a
  hidden class or module boundary exists. See `chapters/ch10-classes.md`.
- Separate system construction and dependency wiring from runtime business behavior. See
  `chapters/ch11-systems.md`.
- Treat repeated branching on the same discriminator as evidence for a strategy or polymorphic
  boundary; do not introduce one before the variation is real. See `chapters/ch03-functions.md` and
  `chapters/ch17-smells-and-heuristics.md`.
- For concurrency, reduce shared mutable data and deliberately vary scheduling/interleavings in
  tests; a flaky failure is evidence, not noise. See `chapters/ch13-concurrency.md`.
- Refactor in small test-protected moves. Optimize first for tests passing, then remove duplication,
  express intent, and only then minimize entities. See `chapters/ch12-emergence.md` and
  `chapters/ch14-successive-refinement.md`.

Load only the linked chapter needed for the decision. Project architecture, language conventions,
formatters, linters, and measured requirements override contextual or dated book advice.

`provenance.json` records the current extraction's verification status. Do not claim page-accurate
book provenance until its missing source/tool metadata is supplied and audited.
