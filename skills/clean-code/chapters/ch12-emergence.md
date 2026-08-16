# Chapter 12: Emergence

## Core Idea
Kent Beck's four rules of Simple Design, applied in priority order, cause good design to emerge without a master plan.

## Frameworks Introduced
- **The Four Rules of Simple Design** (in importance order — a design is simple if it):
  1. **Runs all the tests** — a system that cannot be verified should never be deployed. Making a system testable pushes it toward small single-purpose classes (SRP) and loose coupling (DIP, interfaces); "the more tests we write, the more we... push toward" better design. Testability and good design reinforce each other.
  2. **Contains no duplication** — duplication is the primary enemy of a well-designed system: additional work, additional risk, additional complexity. Includes exact code duplication, duplication of implementation (`isEmpty()` reimplementing `size()==0`), and similar-looking methods begging for TEMPLATE METHOD. "Reuse in the small" — extracting tiny commonalities — is where reuse culture starts.
  3. **Expresses the intent of the programmer** — good names, small classes and functions, standard pattern names (COMMAND, VISITOR) as compressed communication, and well-written tests as documentation by example. "The most important way to be expressive is to try": care is a precious resource; spend it on making the next reader's job easy.
  4. **Minimizes the number of classes and methods** — a tie-breaker with the lowest priority; resist dogma (interfaces-for-everything, fields-and-behavior-always-separated) that multiplies entities pointlessly. Keep the overall system small while keeping functions and classes small.

## Key Concepts
- **Refactoring window**: with tests, after every few lines of new code you pause and clean — raise cohesion, cut coupling, separate concerns, shrink functions, improve names — with zero fear of breaking things.
- **TEMPLATE METHOD for structural duplication**: the `VacationPolicy` example — accrual algorithms share every step except the legal-minimum rule; the shared skeleton lives in the base class, the varying step in subclasses.
- **Patterns as vocabulary**: naming a class `VisitorImpl` or `Factory` transmits the design in one word.

## Anti-patterns
- **Duplication of implementation**: two methods computing the same fact separately.
- **Dogmatic entity multiplication**: an interface per class, rule-driven rather than need-driven.
- **Expressiveness deferred**: "code working" treated as done; the next reader (probably you) pays.

## Code Examples
```java
public abstract class VacationPolicy {
  public void accrueVacation() {
    calculateBaseVacationHours();
    alterForLegalMinimums();   // the only varying step
    applyToPayroll();
  }
  private void calculateBaseVacationHours() { /* shared */ }
  protected abstract void alterForLegalMinimums();
  private void applyToPayroll() { /* shared */ }
}
```
- **What it demonstrates**: TEMPLATE METHOD removes higher-level duplication by isolating the variant step.

## Reference Tables
| Rule | Priority | Primary payoff |
|---|---|---|
| Runs all the tests | 1 | Verifiability; forces SRP/DIP |
| No duplication | 2 | One change site per fact |
| Expresses intent | 3 | Cheap maintenance |
| Minimal classes/methods | 4 | Guards against dogma |

## Key Takeaways
1. Apply the four rules in order; testability outranks everything.
2. Hunt duplication in the small; extraction there seeds reuse culture.
3. Expressiveness is an act of care, applied continuously, not at "done".
4. Minimize entity count last; never at the expense of the first three rules.

## Connects To
- **Ch 9 (Unit Tests)**: rule 1 presumes a clean fast suite.
- **Ch 14 (Successive Refinement)**: the rules applied stroke by stroke.
