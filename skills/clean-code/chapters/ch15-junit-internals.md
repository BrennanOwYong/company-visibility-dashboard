# Chapter 15: JUnit Internals

## Core Idea
Even excellent code by master programmers (JUnit's `ComparisonCompactor`, by Kent Beck and Erich Gamma) yields to the Boy Scout Rule; a module can always be checked in a little cleaner than it was checked out.

## Frameworks Introduced
- **The Boy Scout Rule applied to good code**: the original `ComparisonCompactor` already works, is tested (100% line coverage by its own suite), and is well structured — and still improves under review.
- **The refactoring sequence performed** (each step test-verified, several later reversed when they proved worse):
  1. Remove member-variable encodings: `fExpected` → `expected`, `fActual` → `actual` (N6).
  2. Encapsulate the unencapsulated conditional: `shouldNotCompact()` extracted from `expected == null || actual == null || areStringsEqual()` (G28).
  3. Rename ambiguous locals to distinguish member vs local (`expected` local → `compactExpected`).
  4. Invert the negative conditional: `canBeCompacted()` beats `shouldNotCompact()` (G29).
  5. Rename functions whose names lie: `compact` does more than compact when it can also decline — `formatCompactedComparison` says what it does (G20, N7).
  6. Separate the two concerns `compact` mixed: formatting vs compacting → extract `compactExpectedAndActual` (G30).
  7. Make function signatures consistent: the extracted function sets fields while its callees return values — convert `findCommonPrefix`/`findCommonSuffix` to return values, keeping one convention (G11).
  8. Fix the hidden temporal coupling: `findCommonSuffix` silently depends on `prefixIndex` computed by `findCommonPrefix`; make the ordering physical by passing `prefixIndex` as an argument, or merge into `findCommonPrefixAndSuffix` (G31, G22).
  9. Remove leftovers: dead `compactString` complexity, unneeded guards (G9).
- **Refactoring is iterative, not linear**: "refactoring often produces changes that get reversed later — it is full of trial and error"; several renames and restructurings in this chapter undo earlier ones as understanding deepens.

## Key Concepts
- **`ComparisonCompactor`'s job**: given two differing strings, produce a compacted failure message (`expected:<...b[x]d...> but was:<...b[y]d...>`) by trimming common prefix and suffix.
- **Module ends cleaner AND smaller**: the final version separates `formatCompactedComparison` from the analysis function and reads top-down by the Stepdown Rule.

## Anti-patterns
- **Scope encodings (`f` prefixes)**: today's environments make them redundant.
- **Hidden temporal coupling between private methods**: the worst kind — invisible until reordered.
- **Function names that under- or over-state**: `compact` that sometimes does not compact.

## Code Examples
```java
// Hidden temporal coupling made physical:
private void compactExpectedAndActual() {
  findCommonPrefixAndSuffix();   // merged: suffix needs prefixIndex, now enforced
  compactExpected = compactString(expected);
  compactActual = compactString(actual);
}
```
- **What it demonstrates**: G31's fix — the dependency between prefix and suffix computation becomes structurally unavoidable.

## Reference Tables
| Step | Heuristic applied |
|---|---|
| `fExpected` → `expected` | N6 Avoid Encodings |
| Extract `canBeCompacted()` | G28 Encapsulate Conditionals, G29 Avoid Negative Conditionals |
| `compact` → `formatCompactedComparison` | G20 Function Names Should Say What They Do |
| Split format vs compact | G30 Functions Should Do One Thing |
| Return values over side-effect fields | G11 Consistency |
| Merge prefix/suffix finding | G31 Hidden Temporal Couplings |

## Key Takeaways
1. No code is beneath review; master-written code still improves.
2. Refactor under total test coverage; JUnit's own suite made every step safe.
3. Expect to reverse some refactorings; understanding grows during the work.
4. Leave every module cleaner than you found it.

## Connects To
- **Ch 17**: nearly every step cites a heuristic code from the catalogue.
- **Ch 1**: the Boy Scout Rule in action.
