# Chapter 14: Successive Refinement

## Core Idea
Clean code does not start clean: write a working rough draft, then refine it in tiny, test-protected steps; "to write clean code, you must first write dirty code and then clean it."

## Frameworks Introduced
- **Successive Refinement**: the discipline of the case study — a command-line argument parser (`Args`) is built rough, allowed to degrade as `String` and `Integer` types join `Boolean`, and then halted and refactored before the mess sets in.
  - When to use: any time new requirements make the current structure creak.
  - How: stop adding features the moment the design resists; put the code "in intensive care"; refactor stepwise under a full test suite.
- **Stop early**: "the code was fine when it only parsed Booleans; adding types forced changes I didn't like" — the trigger for refactoring is the second variant, not the fifth.
- **One tiny change at a time**: each refactoring step is a single move (move a field, extract a method, change one call site), with tests run between every step. Refactoring is like solving a Rubik's cube — many small steps, each verified.
- **The incrementalism principle**: "It is not enough for code to work." Working-but-messy code is halted progress; teams that plow forward pay compound interest.
- **ARGUMENT MARSHALER pattern (the case study's outcome)**: an `ArgumentMarshaler` interface (`set`, `get`) with one derivative per argument type (`BooleanArgumentMarshaler`, `StringArgumentMarshaler`, `IntegerArgumentMarshaler`); adding a new argument type becomes adding one class plus one map entry — OCP achieved.
- **Push errors to an exception class**: `ArgsException` absorbs all error state and message formatting that had been smeared through `Args`; error code enums plus a message method centralize error presentation.

## Key Concepts
- **First draft is expected to be messy**: no one writes it clean the first time; the shame is in leaving it messy.
- **Test suite as enabler**: the case study's every move depends on the pre-existing unit and acceptance tests staying green.
- **Type-case explosion as smell**: three parallel `if (isBoolean) ... else if (isString) ...` chains signal the missing polymorphic abstraction.

## Anti-patterns
- **Plowing ahead through a degrading design**: each feature added to a creaking structure multiplies the eventual cleanup cost.
- **Big-bang refactoring without tests**: the case study's method is impossible without the suite.

## Code Examples
```java
// End state: adding an argument type = one class + one registration
private void parseSchemaElement(String element) throws ArgsException {
  char elementId = element.charAt(0);
  String elementTail = element.substring(1);
  validateSchemaElementId(elementId);
  if (elementTail.length() == 0)
    marshalers.put(elementId, new BooleanArgumentMarshaler());
  else if (elementTail.equals("*"))
    marshalers.put(elementId, new StringArgumentMarshaler());
  else if (elementTail.equals("#"))
    marshalers.put(elementId, new IntegerArgumentMarshaler());
  else
    throw new ArgsException(INVALID_ARGUMENT_FORMAT, elementId, elementTail);
}
```
- **What it demonstrates**: the only place that knows the type zoo; everything downstream is polymorphic through `ArgumentMarshaler`.

## Reference Tables
| Refactoring trigger | Response |
|---|---|
| Second type variant forces parallel edits | Introduce the polymorphic abstraction now |
| Error handling smeared through logic | Extract an exception class that owns codes + messages |
| Change requires touching N similar places | The abstraction is missing; stop and extract |

## Key Takeaways
1. Write it dirty, then clean it — but clean it the same day, not "later".
2. Refactor at the second variant; do not wait for the fifth.
3. Move in single-step increments with tests between each step.
4. It is not enough for code to work; working messes rot into the most expensive kind of debt.

## Connects To
- **Ch 3 (Functions)**: the draft-then-refine method stated small.
- **Ch 12 (Emergence)**: the four rules applied continuously during refinement.
