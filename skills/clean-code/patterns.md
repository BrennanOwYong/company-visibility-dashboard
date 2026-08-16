# Patterns & Techniques — Clean Code

## Extract Till You Drop (function decomposition)
**When to use**: any function over ~20 lines, mixing abstraction levels, or with named sections.
**How**: extract each block/section into a function named for its intent; repeat until every function does one thing at one level; order caller-above-callee (Stepdown Rule).
**Trade-offs**: many small functions to navigate; names carry the design, so bad names make it worse.

## Draft-Then-Refine (Successive Refinement)
**When to use**: all new code; refactor trigger is the second variant that forces parallel edits.
**How**: write it working and dirty under tests; then rename, split, and restructure in single-step moves, running tests between each.
**Trade-offs**: requires an existing fast test suite; without one, this method is unavailable.

## BUILD-OPERATE-CHECK + Testing DSL
**When to use**: every unit test.
**How**: three visible parts (arrange data, act, assert); wrap raw APIs in intent-named helpers (`makePages`, `submitRequest`, `assertResponseContains`); evolve the helpers by refactoring detail-swamped tests.
**Trade-offs**: helper layer is code to maintain; worth it once two tests share mechanism.

## SPECIAL CASE object
**When to use**: a "failure" that is really a normal business alternative (missing meal expenses → per diem).
**How**: return an object implementing the same interface that encodes the special behavior; client code loses its try/catch or null check.
**Trade-offs**: hides variability inside the type; document which factory returns it.

## Boundary Wrapper + ADAPTER
**When to use**: any third-party API, and any API that does not exist yet.
**How**: define the interface your application wishes existed; implement it with a wrapper (or ADAPTER over the vendor type); never pass vendor types (Map, framework classes) through the system; translate vendor exceptions to one caller-meaningful type.
**Trade-offs**: one more layer; pays off at the first vendor change or test double.

## Learning Tests
**When to use**: adopting a new library; before wiring it into production code.
**How**: write tests asserting your expectations of the API; fix expectations until green; keep the tests as an upgrade tripwire.
**Trade-offs**: none — the learning had to happen anyway; the tests are a free byproduct.

## TEMPLATE METHOD / STRATEGY for duplication
**When to use**: similar algorithms with a varying step (G5 higher forms).
**How**: shared skeleton in a base class with abstract varying steps (TEMPLATE METHOD), or inject the varying part (STRATEGY).
**Trade-offs**: inheritance coupling (TEMPLATE METHOD) vs extra objects (STRATEGY).

## ONE SWITCH + ABSTRACT FACTORY (polymorphism over conditionals)
**When to use**: switch/if-else chains repeating on the same type discriminator (G23).
**How**: keep at most one switch, buried low, creating polymorphic objects; all other decisions dispatch through the interface.
**Trade-offs**: adding a new operation now touches every class (the anti-symmetry, Ch 6); confirm types are the growth axis.

## Separation of Main + Dependency Injection
**When to use**: system construction; any class that calls `new` on a collaborator.
**How**: all wiring moves to main or a DI container; classes receive dependencies via constructor/setter; use ABSTRACT FACTORY when the app controls creation timing.
**Trade-offs**: wiring becomes configuration; indirection cost is real but buys testability and deferred decisions.

## Bucket Brigade (exposing temporal coupling)
**When to use**: functions that must run in order but nothing enforces it (G31).
**How**: each stage returns a product the next stage requires as an argument; wrong order stops compiling.
**Trade-offs**: threading a token through signatures; the visibility is the point.

## Concurrency Defense (SRP + isolation)
**When to use**: any threaded code.
**How**: separate thread-aware code from domain code; restrict data sharing (copies, thread-local, independent threads); use `java.util.concurrent` primitives and named models (Producer-Consumer, Readers-Writers); keep synchronized sections minimal; jiggle (instrumented sleeps/yields) to force rare interleavings in tests.
**Trade-offs**: copies cost memory/CPU — usually cheaper than the debugging avoided.

## Test-First Archaeology (legacy rescue, Ch 16 method)
**When to use**: refactoring code you did not write.
**How**: write exhaustive tests until coverage is meaningful; fix the bugs the tests expose ("first make it work"); only then rename, restructure, delete dead code in committed increments ("then make it right").
**Trade-offs**: test writing dominates the effort; skipping it converts refactoring to gambling.
