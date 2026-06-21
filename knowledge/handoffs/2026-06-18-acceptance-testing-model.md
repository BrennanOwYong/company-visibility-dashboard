# Acceptance + testing model (owner decision, 2026-06-18)

Refines the "acceptance contract" gap. There are TWO artifacts, not one.

## 1. Definition of done — non-technical criteria
**Author: the PRD agent** (owner's decision; overrides the Notion line "PRD agent does not author
acceptance contracts"). Per feature, at `knowledge/contracts/acceptance/<feature>.md`: what
"finished" means in plain product terms. Includes the user-facing acceptance steps (see below).
The planner reads this as fixed input and must make every assertion reachable (its rubric, 20 pts).

## 2. Testing instructions on the finished product
A separate, more detailed matter, shaped by the ticket's OUTPUT TYPE. The builder emits one of
three ticket types:

- **user-facing** — a layman's-terms checklist a **web-capable agent** runs against the running
  product, covering the positive flow AND the negative flow.
  e.g. "find the Buy button and click it", "add an item then delete it from the cart",
  "submit the form empty and confirm a clear error". Executed via a browser agent (the repo already
  uses `agent-browser` for this).
- **programmatic** — a spec of: required **inputs**, **outputs**, their **cardinality/optionality**,
  and **positive and negative logic gates**. An **external agent writes the actual test code** from
  this spec, written carefully to avoid **false positives and false negatives**.
- **mix** — both of the above.

## Authorship split
- PRD agent: done criteria + user-facing layman steps (positive/negative). Non-technical only.
- Technical layer (planner / interface contracts): the programmatic test spec (I/O, cardinality,
  optionality, logic gates) — it knows the data shapes. NOT built yet.
- Validator agent (future, the post-build adversarial gate): consumes both — drives the web agent
  for user-facing steps, writes+runs test code from the programmatic spec — and checks the RUNNING
  artifact, not the diff (keeps it implementation-independent; "maker is not the judge").

## Pipeline placement
PRD agent (PRD + done criteria + user-facing steps) → technical planner (maps to acceptance,
adds programmatic test spec, tags each ticket's output type) → builders → validator agent
(executes user-facing + programmatic tests on the finished product) → user.

## Status
- BUILT now: PRD agent authors `knowledge/contracts/acceptance/<feature>.md` (done criteria +
  user-facing layman steps). See the prd-agent.md acceptance addendum.
- NEXT PHASE (not built; touches the planner/tickets = kanban, left alone for now):
  - Planner tags each ticket output type (user-facing / programmatic / mix).
  - Planner (or a test-spec step) produces the programmatic test spec from the interface contracts.
  - The validator agent: writes test code from the programmatic spec (no false pos/neg) and drives
    a web agent (agent-browser) through the user-facing steps, against the running build. This is
    the adversarial validation gate, a separate fresh context, ideally a different model family.
