# Chapter 17: Smells and Heuristics

## Core Idea
The complete catalogue of code smells and heuristics — the reference list of "wrongnesses" and the rules that fix them, drawn from Martin's own refactorings plus Beck and Fowler.

## Comments (C)
- **C1: Inappropriate Information** — comments hold only technical notes about code and design; change histories and metadata belong in other systems (source control, issue tracking).
- **C2: Obsolete Comment** — an old comment that no longer describes the code; delete or update fast, they float away from the code they described.
- **C3: Redundant Comment** — describes something that adequately describes itself (`i++; // increment i`); comments say what code cannot.
- **C4: Poorly Written Comment** — worth writing means worth writing well: brief, correct grammar, no rambling.
- **C5: Commented-Out Code** — an abomination; delete it, source control remembers.

## Environment (E)
- **E1: Build Requires More Than One Step** — one command checks out, one command builds.
- **E2: Tests Require More Than One Step** — run all tests with one command (ideally one IDE button); fast, easy, obvious.

## Functions (F)
- **F1: Too Many Arguments** — zero best, then one, two, three; more than three needs very special justification.
- **F2: Output Arguments** — counterintuitive; change the state of `this` instead.
- **F3: Flag Arguments** — a boolean argument proclaims the function does more than one thing.
- **F4: Dead Function** — never-called methods get deleted; source control remembers.

## General (G)
- **G1: Multiple Languages in One Source File** — minimize the number and extent of extra languages (XML, HTML, JavaDoc, JavaScript) per file.
- **G2: Obvious Behavior Is Unimplemented** — follow the Principle of Least Surprise; a function should do what its name implies (`DayDate.StringToDay("Monday")` should work, and ignore case).
- **G3: Incorrect Behavior at the Boundaries** — do not rely on intuition; write a test for every boundary condition and every corner case.
- **G4: Overridden Safeties** — turning off warnings, failing tests marked "get to later", swallowed exceptions: Chernobyl risk management.
- **G5: Duplication** — the DRY principle, "the root of all evil in software"; every duplication is a missed abstraction. Forms: identical code (→ extract), switch/case chains repeating the same condition (→ polymorphism), similar algorithms (→ TEMPLATE METHOD / STRATEGY).
- **G6: Code at Wrong Level of Abstraction** — higher-level concepts in base classes, lower-level in derivatives; constants, variables, functions all placed at the level they belong to (`percentFull` does not belong on a generic `Stack` interface).
- **G7: Base Classes Depending on Their Derivatives** — base classes should know nothing of their derivatives; exceptions are rare and deliberate (e.g. hard-baked FSM hierarchies).
- **G8: Too Much Information** — well-defined modules expose small, potent interfaces; hide data, utility functions, constants, temporaries. Fewer methods, fewer variables, fewer public members per class.
- **G9: Dead Code** — unreachable branches, catch blocks for exceptions never thrown, unused conditions; it rots, uncoupled from the design around it. Bury it.
- **G10: Vertical Separation** — variables and functions defined close to where they are used; local variables just above first use, private functions just below first caller.
- **G11: Inconsistency** — do it the same way everywhere (same variable name for the same concept, same naming pattern for similar methods); consistency, applied, makes code easier to read and modify.
- **G12: Clutter** — default constructors with no body, unused variables, meaningless comments: keep the source clean and clutter-free.
- **G13: Artificial Coupling** — things that do not depend on each other must not be coupled (general enums living inside specific classes; general-purpose statics in specific classes). Put things where they belong, not where it was convenient to type them.
- **G14: Feature Envy** — a method that uses another object's accessors and mutators wants to live in that class; keep methods interested in their own class's variables and functions (exception: keep business rules out of DTO-like report classes even at the cost of some envy).
- **G15: Selector Arguments** — boolean/enum/int selectors dangling at the end of a call to pick behavior; split into one function per behavior.
- **G16: Obscured Intent** — Hungarian run-ons, magic numbers, dense expressions hide intent; expressive code is worth the extra lines.
- **G17: Misplaced Responsibility** — put code where a reader would naturally expect it (PI belongs on the trig functions' home), not where it was convenient for you.
- **G18: Inappropriate Static** — prefer instance methods; make a function static only when it uses no instance data AND there is no chance you will ever want polymorphic behavior (`HourlyPayCalculator.calculatePay` should be an instance method — pay calculation is a likely polymorphism seam).
- **G19: Use Explanatory Variables** — break calculations into intermediate values with meaningful names (Beck: one of the most powerful ways to make a program readable).
- **G20: Function Names Should Say What They Do** — if you must read the implementation (or docs) to know what the call does, rename it (`date.add(5)` — days? weeks? mutation or new date? → `addDaysTo` / `increaseByDays`).
- **G21: Understand the Algorithm** — before you are done, understand HOW your function works; passing tests is not enough. Often that requires refactoring until the correctness is obvious.
- **G22: Make Logical Dependencies Physical** — a module that logically assumes something about another should ask it explicitly (query `HOURLY_REPORT_FORMATTER.getMaxPageSize()` instead of hard-coding the assumed constant).
- **G23: Prefer Polymorphism to If/Else or Switch/Case** — "ONE SWITCH" rule: at most one switch per selection type, creating polymorphic objects that stand in for other such switches.
- **G24: Follow Standard Conventions** — the team's coding standard, based on industry norms, followed by everyone; the code itself is the standard's documentation.
- **G25: Replace Magic Numbers with Named Constants** — includes non-numeric magic values (magic strings, inline formulas); a constant is exempt when self-explanatory in context (`feetPerMile = 5280`).
- **G26: Be Precise** — expecting the first match to be the only match, using floats for currency, avoiding locks "because you don't think you need them" — ambiguities and imprecisions are results of laziness and must be eliminated.
- **G27: Structure over Convention** — enforce design decisions with structure (base class forcing abstract methods) rather than naming conventions alone.
- **G28: Encapsulate Conditionals** — extract boolean logic into an intent-named function: `if (shouldBeDeleted(timer))` beats `if (timer.hasExpired() && !timer.isRecurrent())`.
- **G29: Avoid Negative Conditionals** — `if (buffer.shouldCompact())` beats `if (!buffer.shouldNotCompact())`.
- **G30: Functions Should Do One Thing** — decompose multi-section functions into smaller ones that each do one thing.
- **G31: Hidden Temporal Couplings** — when call order matters, expose it structurally: pass each stage's product into the next (a "bucket brigade") so the sequence cannot be silently reordered.
- **G32: Don't Be Arbitrary** — have a reason for how you structure code, and make the code reflect the reason; arbitrary structure invites arbitrary change.
- **G33: Encapsulate Boundary Conditions** — put `+1`/`-1` handling in one place (`nextLevel = level + 1` variable, or wrap the concept) instead of scattering `level + 1` everywhere.
- **G34: Functions Should Descend Only One Level of Abstraction** — statements within a function all sit one level below its name; separating levels is one of the hardest and most valuable refactorings.
- **G35: Keep Configurable Data at High Levels** — default constants and configuration values live at the highest level and are passed down; low-level functions never bury the default.
- **G36: Avoid Transitive Navigation** — a module talks to its immediate collaborators only (Law of Demeter, "shy code"): no `a.getB().getC().doSomething()`; architectures that allow it resist inserting new intermediaries.

## Java (J)
- **J1: Avoid Long Import Lists by Using Wildcards** — two or more classes from a package → import the package; wildcard imports also avoid hard dependencies.
- **J2: Don't Inherit Constants** — constants via interface inheritance hide their origin; use static import instead.
- **J3: Constants versus Enums** — use `enum`s; they carry methods and fields and are far more expressive than `public static final int`s.

## Names (N)
- **N1: Choose Descriptive Names** — names carry ~90% of readability; choose them carefully and re-choose as the system evolves.
- **N2: Choose Names at the Appropriate Level of Abstraction** — name for the abstraction, not the implementation (`Modem.dial()` not `connectViaPhoneLine()`).
- **N3: Use Standard Nomenclature Where Possible** — pattern names (DECORATOR, VISITOR), convention names (`toString`), and project-local ubiquitous language.
- **N4: Unambiguous Names** — pick names that cannot be misread (`doRename` vs `renamePage`: make the function's job unambiguous).
- **N5: Use Long Names for Long Scopes** — `i` in a five-line loop; full sentences for variables and functions visible across long distances.
- **N6: Avoid Encodings** — no Hungarian, no `m_`, no scope/type prefixes.
- **N7: Names Should Describe Side-Effects** — `createOrReturnOos` not `getOos` when the function may create; the name states everything the function does.

## Tests (T)
- **T1: Insufficient Tests** — a suite is done when it tests everything that could possibly break; untested conditions and uninspected calculations mean the suite is insufficient.
- **T2: Use a Coverage Tool!** — coverage reports find gaps that manual inspection misses; IDE green/red line markers make holes obvious.
- **T3: Don't Skip Trivial Tests** — cheap to write, documentary value exceeds cost.
- **T4: An Ignored Test Is a Question about an Ambiguity** — `@Ignore` or a commented-out test documents an unresolved requirement question.
- **T5: Test Boundary Conditions** — the middle often survives while the boundaries fail; test them explicitly.
- **T6: Exhaustively Test Near Bugs** — bugs congregate; when you find one, test that function exhaustively.
- **T7: Patterns of Failure Are Revealing** — diagnose by the shape of which tests fail and which pass (the negative-monitor-value case: all tests longer than five characters failed).
- **T8: Test Coverage Patterns Can Be Revealing** — code executed by passing tests vs not-executed code localizes the failure.
- **T9: Tests Should Be Fast** — a slow test will not get run; keep them fast under schedule pressure especially.

## Key Takeaways
1. Grep this catalogue during review: C=comments, E=environment, F=functions, G=general, J=java, N=names, T=tests.
2. G5 (Duplication), G6 (Wrong Abstraction Level), and N1 (Descriptive Names) carry the most weight in practice.
3. These are heuristics backed by discipline, not laws; "the code is the standard" once the team internalizes them.

## Connects To
- **Ch 15, Ch 16**: worked applications of these exact codes.
- **Appendix C**: cross-reference of each heuristic to the pages that apply it.
