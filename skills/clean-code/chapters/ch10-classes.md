# Chapter 10: Classes

## Core Idea
Classes should be small, measured in responsibilities, not lines; one responsibility, one reason to change, high cohesion.

## Frameworks Introduced
- **Class Organization (Java convention)**: public static constants, private static variables, private instance variables, then public functions, with private utilities right after the public function that calls them (Stepdown Rule at class scale). Keep variables and utilities private but do not fight a test that needs package-protected access — tests rule.
- **Classes Should Be Small!**: the measure is responsibilities. `SuperDashboard` with 70 public methods fails obviously; a five-method version can still fail if those methods cover two reasons to change. Naming test: if you cannot name the class concisely without weasel words (`Processor`, `Manager`, `Super`), or cannot describe it in ~25 words without "if", "and", "or", "but", it has too many responsibilities.
- **The Single Responsibility Principle (SRP)**: a class or module should have one, and only one, reason to change. Split `SuperDashboard`'s version-tracking methods into a `Version` class. Many small single-purpose classes beat few multipurpose ones: a system with lots of small drawers with well-labeled contents vs a few drawers you toss everything into.
- **Cohesion**: methods should manipulate the class's instance variables; maximal cohesion = every method uses every variable (`Stack` example). When a subset of variables is used only by a subset of methods, a class is trying to escape — split it.
- **Maintaining Cohesion Results in Many Small Classes**: breaking a big function into small ones often promotes locals to instance variables; falling cohesion then signals the class split (the `PrintPrimes` walk-through: one big function → `PrimePrinter`, `RowColumnPagePrinter`, `PrimeGenerator`).
- **Organizing for Change (OCP)**: structure classes so new features are added by extension, not modification — the `Sql` class becomes an abstract `Sql` with one derivative per statement type; adding `UpdateSql` touches nothing existing.
- **Isolating from Change (DIP)**: depend on abstractions, not concrete details. `Portfolio` depends on the `StockExchange` interface, not on `TokyoStockExchange`; a `FixedStockExchangeStub` makes the portfolio testable and decouples it from the volatile real feed.

## Key Concepts
- **Reason to change**: the unit of responsibility counting.
- **Class-splitting signal**: variables used by only some methods.
- **Test-driven class design**: needing a stub reveals the missing abstraction.

## Anti-patterns
- **God class / universal grab-bag** (`SuperDashboard`): toss-everything drawers.
- **Weasel-word names**: `Manager`, `Processor`, `Super` — the name confesses aggregated responsibilities.
- **Concrete dependencies on volatile details**: untestable and change-fragile.

## Code Examples
```java
// SRP extraction: version concerns leave the dashboard
public class Version {
  public int getMajorVersionNumber();
  public int getMinorVersionNumber();
  public int getBuildNumber();
}
```
- **What it demonstrates**: the extracted class is small, nameable in one word, reusable elsewhere, and changes for exactly one reason.

## Reference Tables
| Signal | Meaning |
|---|---|
| Cannot name class without `And/Or/Manager/Processor` | Multiple responsibilities |
| ~25-word description needs "if/and/or/but" | Multiple responsibilities |
| Some variables used by only some methods | Hidden class wants out |
| New feature requires editing existing class | OCP violation; extract abstraction |
| Cannot test without the real external system | DIP violation; introduce interface |

## Key Takeaways
1. Count responsibilities, not lines; one reason to change per class.
2. High cohesion: methods share the instance variables; falling cohesion means split.
3. Add features by adding classes (OCP), not by editing working ones.
4. Depend on interfaces for anything volatile (DIP); stubs prove the seam exists.
5. Prefer many small labeled drawers to a few junk drawers.

## Connects To
- **Ch 3 (Functions)**: the same size discipline one level up.
- **Ch 11 (Systems)**: separation of concerns at architecture scale.
