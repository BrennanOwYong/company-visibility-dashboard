# Chapter 5: Formatting

## Core Idea
Code formatting is communication; vertical and horizontal layout should mirror the conceptual structure so a reader's eye finds related things together.

## Frameworks Introduced
- **The Newspaper Metaphor**: a source file reads like an article — the name is the headline, the top gives the high-level concepts, detail increases as you go down.
- **Vertical Openness Between Concepts**: blank lines separate concepts (package, imports, each function); their absence merges unrelated thoughts.
- **Vertical Density**: lines that are tightly related stand vertically adjacent; do not break variable/comment noise between them.
- **Vertical Distance**: things that belong together stay vertically close.
  - Variable declarations: as close to their usage as possible; loop controls inside the loop statement.
  - Instance variables: at the top of the class, one well-known place.
  - Dependent functions: the caller above the callee, close together (this powers the Stepdown Rule).
  - Conceptual affinity: functions that do similar things (e.g. the `assertTrue` overloads) group together.
- **Vertical Ordering**: highest-level concepts first, details last; the reader can leave early and still know the story.
- **Horizontal Formatting**: keep lines short — Martin's limit is 120 characters; the historical data shows most lines under 60. Use horizontal whitespace to associate (around binary operators by precedence: `b*b - 4*a*c`) and disassociate; do not horizontally align declaration columns (alignment invites reading columns instead of intent, and long aligned lists signal a class that is too big).
- **Indentation**: the file is a hierarchy; indentation makes scope visible. Do not collapse short `if` statements or empty `while` bodies onto one line; keep the indented structure.
- **Team Rules**: a team picks one style and every member uses it; the code base reads as one voice. Personal preference ends where the team begins.

## Key Concepts
- **File size**: small files are easier to understand; FitNesse averages ~65 lines per file, and significant systems are built from files mostly under 200 lines with an upper limit near 500.
- **Openness vs density as signal**: each blank line is a visual cue that a new concept starts.

## Anti-patterns
- **Declaring variables far from use**; **instance variables scattered mid-class** (the JUnit 4.3.1 `TestSuite` hidden-variable case).
- **Breaking the caller-above-callee flow**: forces the reader to hunt downward then re-find context.
- **Horizontal alignment of declarations**: pretty columns, wrong emphasis.

## Code Examples
```java
// Conceptual affinity: these belong adjacent even without calling each other
public void assertTrue(boolean condition) { assertTrue(null, condition); }
public void assertFalse(String message, boolean condition) {
  assertTrue(message, !condition);
}
```
- **What it demonstrates**: vertical grouping by affinity — shared naming and shared task pull functions together.

## Reference Tables
| Rule | Number |
|---|---|
| File length (typical healthy) | ~200 lines, upper bound ~500 |
| Line width | ≤ 120 characters, prefer shorter |
| Variable declaration | nearest use |
| Instance variables | top of class |
| Caller/callee | caller above, close |

## Key Takeaways
1. Format vertically by concept: blank line = new thought; adjacency = tight relation.
2. Callers sit above callees; the file reads downward like a newspaper.
3. Keep files small (~200 lines) and lines short (≤120 chars).
4. Team style beats personal style; one voice per codebase.

## Connects To
- **Ch 3 (Functions)**: the Stepdown Rule is vertical ordering applied to abstraction levels.
- **Ch 17 (G10 Vertical Separation, G11 Inconsistency)**: heuristic codes.
