# Chapter 3: Functions

## Core Idea
Functions should be very small, do one thing at one level of abstraction, and read top-down like prose.

## Frameworks Introduced
- **Small!**: functions should hardly ever be 20 lines long; the ideal is 2–4 lines. Blocks inside `if`/`else`/`while` should be one line — usually a function call, which both shrinks the enclosing function and documents the block with a name. Indent level should not exceed one or two.
- **Do One Thing**: "Functions should do one thing. They should do it well. They should do it only." A function does one thing when all its statements sit one level of abstraction below the function's name. Another test: if you can extract a sub-function whose name is not a restatement of the original, the original did more than one thing.
- **The Stepdown Rule**: code reads top-to-bottom as a set of TO paragraphs, each function followed by those at the next level of abstraction, descending one level per function.
- **One Level of Abstraction per Function**: never mix `getHtml()` (high), `PathParser.render(pagePath)` (mid), and `.append("\n")` (low) in one function.
- **Use Descriptive Names**: a long descriptive name beats a short enigmatic one and beats a descriptive comment. Be consistent: `includeSetupAndTeardownPages`, `includeSetupPages`, `includeSuiteSetupPage` tell a story.
- **Function Arguments**: ideal count is zero (niladic), then one (monadic), then two (dyadic). Three (triadic) should be avoided where possible; more than three requires very special justification. Arguments are hard for readers and harder for testing (combinatorial explosion of cases).
- **Command Query Separation**: a function either does something or answers something, never both. `if (set("username", "unclebob"))` reads as ambiguity; split into `if (attributeExists(...)) { setAttribute(...); }`.
- **Prefer Exceptions to Returning Error Codes**: error codes force nested `if` pyramids and violate command-query separation; exceptions let happy-path logic stand alone. Extract try/catch bodies into functions of their own; error handling is one thing, so a function that handles errors does nothing else.
- **Structured Programming (relaxed)**: Dijkstra's single-entry/single-exit rule pays off only in large functions; in small ones, multiple returns or an early break can be more expressive.
- **How to write functions**: first drafts are long and messy; write them, cover them with tests, then massage and refine — split, rename, eliminate duplication — while the tests stay green.

## Key Concepts
- **Monadic forms**: asking a question about the argument (`fileExists("f")`), transforming it (`fileOpen("f")`), or handling an event. Avoid other monadic shapes.
- **Flag arguments**: passing a boolean into a function is ugly — it loudly proclaims the function does two things. Split into two functions.
- **Argument objects**: when a function needs more than two or three arguments, some of them likely wrap into a class of their own (`Circle makeCircle(Point center, double radius)`).
- **Side effects are lies**: a function that promises one thing and also does a hidden other thing (e.g. `checkPassword` also calls `Session.initialize()`) creates temporal couplings.
- **Output arguments**: readers do a double-take on `appendFooter(s)`. In OO, `this` is the intended output argument: write `report.appendFooter()`.

## Anti-patterns
- **Switch statements**: they are N things by nature, they grow, and they multiply. Tolerate them once, buried in a low-level class, used to create polymorphic objects (an ABSTRACT FACTORY) — never repeated through the system.
- **Dead functions, flag arguments, output arguments**: see F1–F4 in ch17.

## Code Examples
```java
// The Stepdown Rule + Do One Thing: three lines, one level of abstraction
public static String renderPageWithSetupsAndTeardowns(
    PageData pageData, boolean isSuite) throws Exception {
  if (isTestPage(pageData))
    includeSetupAndTeardownPages(pageData, isSuite);
  return pageData.getHtml();
}
```
- **What it demonstrates**: the end state of Listing 3-1's 60-line tangle after successive extraction; the name says everything the body does.

## Reference Tables
| Argument count | Name | Verdict |
|---|---|---|
| 0 | niladic | ideal |
| 1 | monadic | good (question / transform / event) |
| 2 | dyadic | acceptable when the args are a natural pair (`new Point(0,0)`) |
| 3 | triadic | avoid where possible |
| 4+ | polyadic | requires very special justification; wrap into objects |

## Key Takeaways
1. Keep functions under ~20 lines; strive for 2–4.
2. One thing per function, one level of abstraction per function.
3. Zero to two arguments; no flags, no output arguments.
4. Separate commands from queries; throw exceptions instead of returning codes.
5. Extract try/catch bodies into their own functions.
6. Write it long and messy first; refine under green tests.

## Connects To
- **Ch 17 (G30, G34, F1–F4, G15)**: heuristic codes for these rules.
- **Ch 14 (Successive Refinement)**: a book-length demonstration of the "draft then refine" method.
