# Cheatsheet — Clean Code decision rules

## Thresholds & defaults
| Thing | Number |
|---|---|
| Function length | < 20 lines; strive for 2–4 |
| Function arguments | 0–2; 3 needs justification; 4+ forbidden without special cause |
| Indent depth per function | 1–2 levels |
| Line width | ≤ 120 chars |
| File length | ~200 lines typical, ~500 upper bound |
| Class size | measured in responsibilities: exactly 1 reason to change |
| Asserts per test | minimize per concept; 1 concept per test |
| TDD cycle | ~30 seconds |
| Reading:writing ratio | 10:1 — optimize for the reader |

## Decision rules
- Name needs a comment to be understood → the name failed; rename, don't comment.
- Tempted to write a comment → first try extracting a function or variable that says it.
- Boolean parameter in a signature → split into two functions (F3).
- Same code (or same shape) twice → extract now; second occurrence is the trigger, not the fifth (G5, Ch 14).
- Switch on a type discriminator appears twice → replace with polymorphism; keep at most ONE switch, low, creating objects (G23).
- Expecting NEW TYPES to grow → objects/polymorphism. Expecting NEW OPERATIONS to grow → data structures + procedures (Ch 6 anti-symmetry).
- Would return null → return SPECIAL CASE object or empty collection. Would pass null → don't.
- Third-party type about to cross a module boundary → stop; wrap it (Ch 8).
- New library → learning tests before production wiring.
- Class hard to name without Manager/Processor/And → it has 2+ responsibilities; split (Ch 10).
- Some fields used by only some methods → a class is hiding inside; extract it (cohesion rule).
- Call order matters but is unenforced → bucket-brigade the results through arguments (G31).
- `a.getB().getC().doX()` on objects → Law of Demeter violation; tell, don't ask (G36). Field access on pure data structures is exempt.
- Constructor calls (`new`) inside business logic → move construction to main/DI/factory (Ch 11).
- Error handling obscures the algorithm → extract `try` body to its own function; error handling is one thing (Ch 3, 7).
- Checked exception in application code → make it unchecked; wrap vendor exceptions at the boundary (Ch 7).
- Negative conditional reads awkwardly → invert it (G29); compound boolean → extract intent-named predicate (G28).

## Test decision rules
- Production code before a failing test → stop; Three Laws violation.
- Test slow / needs network / needs order → violates F.I.R.S.T.; fix the test infrastructure before adding tests.
- Test failure looks random → treat as a threading suspect, never a one-off (Ch 13, T7).
- Found a bug → test that function exhaustively; bugs congregate (T6).
- `@Ignore`d test → there is an unresolved requirements question; answer it (T4).
- Coverage tool not run → the suite's holes are unknown (T2); boundaries untested → they are where it breaks (T5, G3).

## Tells & smells (fast recognition)
| You see | You have |
|---|---|
| Comment explaining a block | A function wanting extraction with that comment's name |
| `Info`/`Data`/`Manager` in a name | A meaningless distinction or a god class |
| `flag`, `isAdmin=true` in a call | A function doing two things |
| Parallel if/else chains across files | Missing polymorphic abstraction |
| `f` / `m_` / `sz` prefixes | Encoding rot (N6); delete |
| Commented-out block | C5; delete, git remembers |
| Getter/setter pairs on every field | Fake abstraction; expose behavior instead |
| Test with 15 lines of setup detail | Missing testing DSL |
| "Runs fine on my machine" test | Repeatability violation |
| Warnings suppressed, test skipped | G4 Overridden Safeties: Chernobyl mode |

## Priority order when cleaning (Ch 12)
1. Make/keep all tests passing.
2. Remove duplication.
3. Express intent (names, size, patterns).
4. Only then minimize entity count.
