# Chapter 16: Refactoring SerialDate

## Core Idea
A full professional-grade class (JFreeChart's `SerialDate`, ~700 lines by an experienced author) refactored end to end: first make it work, then make it right — in small reviewed steps.

## Frameworks Introduced
- **First, Make It Work**: before touching structure, build the safety net. The shipped test suite exercised only ~50% of the class; Martin wrote his own exhaustive tests, found real bugs (boundary errors in `getFollowingDayOfWeek`, broken `LAST/NEAREST` week-in-month handling), and fixed them until every meaningful test passed.
- **Then Make It Right**: the improvement pass, each change committed incrementally:
  - **Rename for truth**: `SerialDate` describes an implementation (a serial-number date), not an abstraction; renamed to `DayDate` (N1, N2).
  - **Delete misleading/redundant comments**: Javadoc restating `IllegalArgumentException` behavior, journal headers (C2, C3).
  - **Move constants into enums**: `MonthConstants` inheritance replaced by a `Month` enum; `J2: Don't Inherit Constants`, `J3: Constants versus Enums`.
  - **Push implementation choices down**: the base class depended on its derivatives (`SpreadsheetDate` mentioned in `createInstance`); replaced with an ABSTRACT FACTORY (`DayDateFactory` / `SpreadsheetDateFactory`) so the hierarchy points one way (G7).
  - **Kill dead code and unused arguments**: functions never called, arguments never used (G9, F4).
  - **Make physical what is logical**: methods that logically depend on `SpreadsheetDate`'s ordinal-zero convention got `getDayOfWeekForOrdinalZero` as an abstract method — the dependency is now explicit (G22).
  - **Localize configuration and statics**: moved misplaced static state and responsibility to where it belongs (G17, G18).
- **The result**: better test coverage, a few bugs fixed, clearer names, smaller size, cleaner structure — "we left it better than we found it."

## Key Concepts
- **Review-as-refactoring**: the chapter is a written code review where every criticism becomes an executed change, not a comment.
- **Respect alongside critique**: the original author is "experienced and competent"; professional review targets code, never people.
- **Test-first archaeology**: writing exhaustive tests against legacy code is how you learn what it really does — and where it lies.

## Anti-patterns
- **Class named for its implementation** (`SerialDate`): renames must follow abstraction level.
- **Inheriting an interface full of constants**: a compile-time trick that pollutes the hierarchy.
- **Base class knowing its derivatives**: locks the hierarchy and blocks extension.
- **~50% test coverage treated as tested**: half the behavior was unverified, and bugs lived there.

## Code Examples
```java
// Base class freed from its derivatives via ABSTRACT FACTORY
DayDate date = DayDateFactory.makeDate(1, Month.JANUARY, 2008);
// instead of: SerialDate.createInstance(...) returning a hard-coded SpreadsheetDate
```
- **What it demonstrates**: G7's fix — creation knowledge moves to a factory; `DayDate` no longer names `SpreadsheetDate`.

## Reference Tables
| Change | Heuristic |
|---|---|
| `SerialDate` → `DayDate` | N1, N2 (names at right abstraction level) |
| Delete restating Javadoc | C3 Redundant Comment |
| `MonthConstants` → `Month` enum | J2, J3 |
| Factory extraction | G7 Base Classes Depending on Derivatives |
| Remove never-called methods | G9 Dead Code, F4 Dead Function |
| Abstract `getDayOfWeekForOrdinalZero` | G22 Make Logical Dependencies Physical |

## Key Takeaways
1. Sequence is fixed: exhaustive tests first, behavior fixed second, structure third.
2. Coverage tools reveal what "tested" claims hide (T2).
3. Name classes for their abstraction, not their implementation trick.
4. Point hierarchies one way; factories carry creation knowledge.
5. Every professional codebase, however competent, improves under this process.

## Connects To
- **Ch 17**: the heuristic codes cited throughout are catalogued there; Appendix C cross-references each.
- **Ch 9 (Unit Tests)**: T2 Use a Coverage Tool; T5 Test Boundary Conditions drove the bug finds.
