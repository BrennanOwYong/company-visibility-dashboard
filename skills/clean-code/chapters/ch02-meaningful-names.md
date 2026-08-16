# Chapter 2: Meaningful Names

## Core Idea
A name must answer why the thing exists, what it does, and how it is used; if a name needs a comment, the name failed.

## Frameworks Introduced
- **Use Intention-Revealing Names**: the name carries the concept, the unit, and the purpose.
  - How: replace `int d; // elapsed time in days` with `int elapsedTimeInDays`.
- **Avoid Disinformation**: never leave false clues. Do not call something `accountList` unless it is a `List`; avoid names that vary in small ways (`XYZControllerForEfficientHandlingOfStrings` vs `...ForEfficientStorageOfStrings`); never use lower-case `l` or upper-case `O` as names.
- **Make Meaningful Distinctions**: number-series names (`a1`, `a2`) and noise words (`Info`, `Data`, `theObject`, `variable`) distinguish nothing. `ProductInfo` vs `ProductData` is a distinction without a difference.
- **Use Pronounceable Names**: `genymdhms` fails the conversation test; `generationTimestamp` passes.
- **Use Searchable Names**: single-letter names and raw numeric constants cannot be grepped. Name length should correspond to scope size: `i` is fine inside a 3-line loop; `MAX_CLASSES_PER_STUDENT` is required at module scope.
- **Avoid Encodings**: no Hungarian Notation, no member prefixes (`m_`), no `I` prefix on interfaces. Encode the implementation if you must (`ShapeFactoryImp`), never the interface.
- **Avoid Mental Mapping**: readers should not have to translate your name into a concept they know. Clarity is king; smart programmers show off with clarity, not with `r` meaning "the lower-cased url with host removed".
- **One Word per Concept**: pick one of `fetch`/`retrieve`/`get` and use it everywhere; do not mix `Manager`/`Controller`/`Driver` for the same role.
- **Don't Pun**: the inverse rule; never use one word for two different ideas (an `add` that concatenates and an `add` that inserts into a collection are different concepts — call the second `insert` or `append`).
- **Solution vs Problem Domain Names**: use CS terms (`AccountVisitor`, `JobQueue`) when a technical concept is at work; use the problem domain's language when no technical term fits, so a domain expert can be asked what it means.
- **Add Meaningful Context**: `state` alone is ambiguous; `addrState` or, better, an `Address` class gives it context. Do not add gratuitous context: prefixing every class in the Gas Station Deluxe app with `GSD` poisons autocomplete.

## Key Concepts
- **Class names**: noun or noun phrase (`Customer`, `WikiPage`); never a verb; avoid `Manager`, `Processor`, `Data`, `Info`.
- **Method names**: verb or verb phrase (`postPayment`, `deletePage`); accessors `get`, mutators `set`, predicates `is` per JavaBean convention.
- **Static factory methods**: when constructors are overloaded, use named factories that describe the arguments: `Complex.FromRealNumber(23.0)` beats `new Complex(23.0)`.

## Anti-patterns
- **Hungarian Notation and member prefixes**: modern editors make them noise; readers learn to ignore the prefix and the name.
- **Cute or humorous names** (`HolyHandGrenade`, `whack()`): choose clarity over entertainment; say what you mean.
- **Noise-word suffixes** (`Info`, `Data`): meaningless distinctions.

## Code Examples
```java
// Before: implicity — nothing tells you what this does
public List<int[]> getThem() {
  List<int[]> list1 = new ArrayList<int[]>();
  for (int[] x : theList)
    if (x[0] == 4)
      list1.add(x);
  return list1;
}

// After: same statements, renamed for the minesweeper domain
public List<int[]> getFlaggedCells() {
  List<int[]> flaggedCells = new ArrayList<int[]>();
  for (int[] cell : gameBoard)
    if (cell[STATUS_VALUE] == FLAGGED)
      flaggedCells.add(cell);
  return flaggedCells;
}
```
- **What it demonstrates**: renaming alone, with zero structural change, turns opaque code into obvious code.

## Reference Tables
| Rule | Test |
|---|---|
| Intention-revealing | Does the name state why/what/how without a comment? |
| No disinformation | Does the name promise anything the code does not do? |
| Meaningful distinction | Could a reader tell the two names apart by behavior? |
| Pronounceable | Can you say it in a design discussion? |
| Searchable | Can you grep it and get only relevant hits? |
| Scope-length rule | Short names for short scopes; long names for long scopes |

## Key Takeaways
1. If a name requires a comment, the name does not reveal its intent; rename instead of commenting.
2. Name length should grow with scope size.
3. One word per concept across the codebase; one concept per word.
4. Classes are nouns, methods are verbs.
5. Change names when you find better ones; the cost is small, the payoff is compounding.

## Connects To
- **Ch 17 (N1–N7)**: the heuristics catalogue restates and codifies these naming rules.
- **Ch 3 (Functions)**: descriptive function names substitute for comments and shrink function bodies.
