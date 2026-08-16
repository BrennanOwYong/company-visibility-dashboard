# Chapter 9: Unit Tests

## Core Idea
Test code is as important as production code; dirty tests are equivalent to or worse than no tests, because tests are what make production code safe to change.

## Frameworks Introduced
- **The Three Laws of TDD**:
  1. **First Law** — You may not write production code until you have written a failing unit test.
  2. **Second Law** — You may not write more of a unit test than is sufficient to fail, and not compiling is failing.
  3. **Third Law** — You may not write more production code than is sufficient to pass the currently failing test.
  - The cycle is ~30 seconds long; tests and production code are written together, tests a few seconds ahead. Result: tests cover virtually all production code.
- **Tests Enable the -ilities**: unit tests keep code flexible, maintainable, and reusable, because tests remove the fear of change. Lose the tests → fear change → stop cleaning → code rots.
- **Clean Tests = Readability**: "Readability, readability, and readability" — clarity, simplicity, density of expression. Say a lot with few expressions.
- **BUILD-OPERATE-CHECK**: each test splits into three parts — build the test data, operate on it, check the result.
- **Domain-Specific Testing Language**: build functions/utilities over the raw APIs (`makePages`, `submitRequest`, `assertResponseContains`) so tests read as intent; the testing API evolves by refactoring tests that got too detailed.
- **A Dual Standard**: test code may sacrifice efficiency (the `getState()` string-concat example) but never cleanliness; the test environment has different resource constraints than embedded production.
- **One Assert per Test / Single Concept per Test**: single-assert is a good guideline (given-when-then names make it readable), but the better rule: minimize asserts per concept and test one concept per test function. The `addMonths` test fails because it tests three independent concepts, hiding the general rule (incrementing a month caps the day at the target month's last day) and hiding a missing test (Feb 28 + 1 month).
- **F.I.R.S.T.** — clean tests follow five rules:
  - **Fast**: slow tests do not get run; unfound problems compound; code rots.
  - **Independent**: no test sets up the next; run in any order; dependent tests cascade failures and hide defects.
  - **Repeatable**: in any environment — production, QA, laptop on a train without a network; otherwise failures always have an excuse.
  - **Self-Validating**: boolean output, pass or fail; no log reading, no manual file comparison.
  - **Timely**: written just before the production code that makes them pass; test-after finds the code hard to test.

## Key Concepts
- **Dirty tests are a liability**: "quick and dirty" test suites cost more to change than the production code, get discarded, and take the safety net with them (the coached-team story).
- **Given-when-then naming**: `givenPages / whenRequestIsIssued / thenResponseShouldBeXML`.

## Anti-patterns
- **Tests exempted from quality standards**: the seed of losing the whole suite.
- **Detail-swamped tests** (Listing 9-1): PathParser calls, response casting, URL assembly — noise that obscures intent.
- **Multiple concepts per test**: the reader must deduce why each section exists.

## Code Examples
```java
// Domain-specific testing language + BUILD-OPERATE-CHECK
public void testGetPageHierarchyAsXml() throws Exception {
  makePages("PageOne", "PageOne.ChildOne", "PageTwo");      // build
  submitRequest("root", "type:pages");                      // operate
  assertResponseIsXML();                                    // check
  assertResponseContains(
    "<name>PageOne</name>", "<name>PageTwo</name>", "<name>ChildOne</name>"
  );
}
```
- **What it demonstrates**: the refactored FitNesse test — all mechanism hidden, pure intent visible.

## Reference Tables
| F.I.R.S.T. | Test question |
|---|---|
| Fast | Do you run the suite on every small change? |
| Independent | Can tests run in any order, alone? |
| Repeatable | Does it pass on a laptop with no network? |
| Self-Validating | Is the outcome a boolean, no log reading? |
| Timely | Was the test written just before the code? |

## Key Takeaways
1. Follow the Three Laws; the TDD cycle is seconds, not hours.
2. Keep tests as clean as production code; readability above all.
3. Structure every test as BUILD-OPERATE-CHECK; grow a domain-specific testing language.
4. Minimize asserts per concept; one concept per test.
5. Enforce F.I.R.S.T.; a slow or flaky suite dies, and the code rots after it.

## Connects To
- **Ch 17 (T1–T9)**: test heuristics catalogue.
- **Ch 12 (Emergence)**: "Runs all the tests" is simple design rule #1.
