# Clean Code → Factory Stage Map

Mapping index: each factory pipeline stage cites the Clean Code principles that govern it. Exact book names; one-line application per item. Codes in parentheses reference [ch17](chapters/ch17-smells-and-heuristics.md).

## 1. BUILD (builder writes code)

### Naming (ch02, N1–N7)
- **Use Intention-Revealing Names** — reject any name that needs a comment to explain why/what/how.
- **Avoid Disinformation** — check the name promises nothing the code does not do (`accountList` must be a List).
- **Make Meaningful Distinctions** — reject noise-word pairs (`ProductInfo` vs `ProductData`) and number series (`a1`, `a2`).
- **Use Pronounceable Names / Use Searchable Names** — name must survive a design conversation and a grep.
- **Avoid Encodings (N6)** — no Hungarian, no `m_`, no `I`-prefix interfaces.
- **Pick One Word per Concept** — one of `fetch`/`get`/`retrieve` codebase-wide; flag mixes.
- **Choose Names at the Appropriate Level of Abstraction (N2)** — name the abstraction (`Modem.dial`), not the mechanism (`connectViaPhoneLine`).
- **Use Long Names for Long Scopes (N5)** — `i` in a 3-line loop only; module-scope names spell it out.
- **Names Should Describe Side-Effects (N7)** — `createOrReturnX`, not `getX`, when creation can happen.

### Functions (ch03)
- **Small!** — hold functions under 20 lines; extract when a block needs a comment or a blank-line section.
- **Do One Thing** — if a sub-function can be extracted with a non-restating name, the function does two things; split.
- **One Level of Abstraction per Function / The Stepdown Rule (G34)** — no `.append("\n")` beside `getHtml()`; callers above callees.
- **Function Arguments (F1)** — 0–2 args; wrap arg clusters into objects; 3+ needs written justification.
- **Flag Arguments (F3) / Selector Arguments (G15)** — a boolean/enum selector in a signature means two functions pretending to be one.
- **Output Arguments (F2)** — mutate `this`, never an argument.
- **Command Query Separation** — a function does or answers; a `set` that returns success status gets split.
- **Prefer Polymorphism to If/Else or Switch/Case (G23)** — second switch on the same discriminator triggers the ONE SWITCH rule.

### Comments (ch04, C1–C5)
- **Comments Do Not Make Up for Bad Code** — before writing a comment, try the rename/extraction that deletes the need.
- **Explain Yourself in Code** — turn condition comments into intent-named predicates.
- **Commented-Out Code (C5)** — delete on sight; version control remembers.
- **Redundant Comment (C3) / Obsolete Comment (C2)** — restating or stale comments get deleted, not maintained.
- **TODO Comments** — allowed only when tracked; never as license for bad code.

### Formatting (ch05)
- **The Newspaper Metaphor / Vertical Ordering** — file reads high-level → detail; a reader can stop early.
- **Vertical Distance** — declare variables at first use; instance variables at class top; caller above callee.
- **Vertical Openness / Density** — blank line per new concept; no noise between tightly related lines.
- **Horizontal Formatting** — lines ≤ 120 chars; no aligned declaration columns.
- **Team Rules** — the project style wins over personal style, everywhere.

### Objects vs data structures (ch06)
- **Data/Object Anti-Symmetry** — choose objects when types will grow, procedures+data when operations will grow.
- **Data Abstraction** — no reflex getters/setters; expose behavior, hide representation.
- **The Law of Demeter (G36 Avoid Transitive Navigation)** — no `a.getB().getC().doX()` on objects; tell, don't ask.
- **Hybrids** — half-object half-struct classes are rejected at review.
- **Data Transfer Objects** — DTOs stay behavior-free; business rules never enter Active Records.

### Error handling (ch07)
- **Use Exceptions Rather Than Return Codes** — no error-flag returns; happy path reads unbroken.
- **Use Unchecked Exceptions** — application code throws unchecked; context in every exception.
- **Write Your Try-Catch-Finally Statement First** — error skeleton first, test-driven; `try` is nearly the first word of its function.
- **Define Exception Classes by Caller's Needs** — one wrapped exception type per boundary, classified by how it is caught.
- **Define the Normal Flow (SPECIAL CASE)** — business alternatives become objects, not catch blocks.
- **Don't Return Null / Don't Pass Null** — empty collections and SPECIAL CASE objects instead; null params forbidden.

### Boundaries (ch08)
- **Encapsulate the boundary** — vendor types (`Map`, SDK clients) never cross module lines; tailored wrapper class instead.
- **Learning Tests** — probe a new library in tests before production wiring; keep them as upgrade tripwires.
- **Using Code That Does Not Yet Exist** — code to the interface you wish existed; ADAPTER bridges when the real API lands.
- **Clean Boundaries** — depend on what you control, not on what controls you.

## 2. TEST (builder self-test + audit)

### The Three Laws of TDD (ch09)
- **First Law** — no production code without a failing unit test; audit: does every feature commit carry its tests?
- **Second Law** — write only enough test to fail (not compiling counts as failing).
- **Third Law** — write only enough production code to pass; cycle stays ~30 seconds.

### F.I.R.S.T. (ch09)
- **Fast** — a suite too slow to run on every change is a defect; fix infrastructure first.
- **Independent** — any test runs alone and in any order; setup chains between tests are rejected.
- **Repeatable** — must pass with no network, any environment; environment-excused failures are failures.
- **Self-Validating** — boolean outcome only; log-reading or file-diffing verdicts are rejected.
- **Timely** — tests written just before the code; test-after signals untestable design forming.

### Test structure (ch09)
- **Test code is as important as production code** — same cleanliness standard; dirty tests are worse than no tests.
- **BUILD-OPERATE-CHECK** — every test shows its three parts; detail noise means the testing DSL is missing.
- **Domain-Specific Testing Language** — wrap raw APIs in intent-named helpers when two tests share mechanism.
- **One Assert per Test (guideline) / Single Concept per Test (rule)** — minimize asserts per concept; split multi-concept tests.
- **A Dual Standard** — tests may trade efficiency, never cleanliness.

### Test smells (ch17, T1–T9 + G-codes)
- **T1: Insufficient Tests** — test everything that could possibly break, not what was convenient.
- **T2: Use a Coverage Tool!** — run coverage on every audit; unknown holes fail the audit.
- **T3: Don't Skip Trivial Tests** — their documentary value exceeds their cost.
- **T4: An Ignored Test Is a Question about an Ambiguity** — every `@Ignore` maps to an open requirements question or gets deleted.
- **T5: Test Boundary Conditions** — boundaries tested explicitly (pairs with G3: Incorrect Behavior at the Boundaries).
- **T6: Exhaustively Test Near Bugs** — a found bug triggers exhaustive tests on its function.
- **T7: Patterns of Failure Are Revealing** — diagnose from the shape of which tests fail; flaky = threading suspect (ch13).
- **T8: Test Coverage Patterns Can Be Revealing** — compare executed vs unexecuted code to localize failures.
- **T9: Tests Should Be Fast** — slow tests stop getting run under pressure, then the code rots.
- **E2: Tests Require More Than One Step** — one command runs the whole suite, or the environment is a defect.

## 3. REFACTOR (change existing code safely)

### Ground rules
- **The Boy Scout Rule (ch01, ch15)** — every touched module is committed cleaner than it was checked out.
- **First, Make It Work; Then Make It Right (ch16)** — exhaustive tests + bug fixes precede any structural change.
- **Successive Refinement (ch14)** — single-step moves, tests green between each; refactor at the SECOND variant, not the fifth.
- **It is not enough for code to work (ch14)** — working-but-degrading structure halts feature work until cleaned.
- **Four Rules of Simple Design (ch12)** — clean in priority order: tests pass → no duplication → expresses intent → minimal entities.

### When to extract
- **G30: Functions Should Do One Thing** — multi-section function → one function per section.
- **G34: Functions Should Descend Only One Level of Abstraction** — mixed-level function → extract the lower level.
- **G28: Encapsulate Conditionals** — compound boolean → intent-named predicate.
- **G29: Avoid Negative Conditionals** — inverted logic → positive form.
- **G19: Use Explanatory Variables** — dense expression → named intermediate values.
- **G33: Encapsulate Boundary Conditions** — scattered `+1`/`-1` → one named place.
- **Cohesion split (ch10)** — variables used by only some methods → extract the hidden class.

### Smell catalogue for review sweeps (ch17)
- **G5: Duplication** — every duplication is a missed abstraction; extract, or TEMPLATE METHOD/STRATEGY for similar algorithms.
- **G6: Code at Wrong Level of Abstraction** — relocate constants/functions to the level they belong to.
- **G7: Base Classes Depending on Their Derivatives** — introduce a factory; hierarchy points one way.
- **G8: Too Much Information** — shrink interfaces; hide data, utilities, temporaries.
- **G9: Dead Code / F4: Dead Function** — unreachable or uncalled → delete; git remembers.
- **G10: Vertical Separation** — move definitions next to first use.
- **G11: Inconsistency** — same thing done two ways → converge on one.
- **G12: Clutter** — empty constructors, unused variables → delete.
- **G13: Artificial Coupling** — general-purpose code inside specific classes → move to neutral ground.
- **G14: Feature Envy** — method obsessed with another class's members → move it there (DTO exception applies).
- **G16: Obscured Intent** — magic values, run-ons → rewrite expressively.
- **G17: Misplaced Responsibility** — code where it was convenient, not where a reader expects → relocate.
- **G18: Inappropriate Static** — potential polymorphism seam declared static → make it an instance method.
- **G20: Function Names Should Say What They Do** — implementation-reading required → rename.
- **G21: Understand the Algorithm** — passing tests without understood correctness → refactor until obvious.
- **G22: Make Logical Dependencies Physical** — assumed constants/order → explicit query or argument.
- **G25: Replace Magic Numbers with Named Constants** — includes magic strings and inline formulas.
- **G26: Be Precise** — floats for money, unlocked shared state, first-match assumptions → eliminate.
- **G27: Structure over Convention** — naming-convention enforcement → structural enforcement (abstract methods).
- **G31: Hidden Temporal Couplings** — enforced-by-luck ordering → bucket brigade through arguments.
- **G32: Don't Be Arbitrary** — structure without a reason → restructure to reflect one.
- **G35: Keep Configurable Data at High Levels** — buried defaults → hoist to the top and pass down.
- **C-codes during sweeps** — C2/C3 stale and redundant comments deleted alongside the code change that orphaned them.
- **N-codes during sweeps** — N1/N4 renames ride along with every refactor; renaming is the cheapest high-yield refactor.
