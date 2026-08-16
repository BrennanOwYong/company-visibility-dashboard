# Chapter 7: Error Handling

## Core Idea
Error handling is important, but if it obscures logic, it is wrong; separate the happy path from error processing so each reads clean.

## Frameworks Introduced
- **Use Exceptions Rather Than Return Codes**: return codes clutter the caller with immediate checks that are easy to forget; exceptions keep calling logic unobscured.
- **Write Your Try-Catch-Finally Statement First**: a `try` block is a transaction — the `catch` must leave the program in a consistent state. Start with the try/catch/finally skeleton (test-driven: write a test that expects the exception, then make it pass), then build logic inside it.
- **Use Unchecked Exceptions**: checked exceptions violate the Open/Closed Principle — a new checked throw at a low level forces signature changes up the whole call chain, cascading modification and breaking encapsulation. The benefit does not pay for that price outside critical-library contexts.
- **Provide Context with Exceptions**: each exception carries enough information (operation attempted, failure type) to locate source and intent; stack traces alone do not say what the operation intended.
- **Define Exception Classes by Caller's Needs**: classify exceptions by how they are caught, not by where they arise. Wrap a third-party API whose methods throw many exception types in a class that throws one common type (`LocalPort` wrapping `ACMEPort`); wrapping third-party APIs is best practice regardless.
- **Define the Normal Flow (SPECIAL CASE pattern)**: when a "failure" is really a normal alternative (no meal expenses → per diem), create an object that encodes the special case (`PerDiemMealExpenses implements MealExpenses`) so the client code has no exception path at all.
- **Don't Return Null**: every returned null creates a missing-check landmine one forgotten `if` away from a `NullPointerException`. Return SPECIAL CASE objects or empty collections (`Collections.emptyList()`) instead.
- **Don't Pass Null**: passing null into methods is worse than returning it; no good runtime defense exists, so forbid it by convention.

## Key Concepts
- **Exception wrapping**: catching a third-party exception and rethrowing your own type at the boundary minimizes dependence on the vendor API.
- **Error handling is one thing**: a function that handles errors does nothing else (from ch3); the `try` keyword should be nearly the first word, and nothing follows the catch/finally blocks.

## Anti-patterns
- **Return codes / error flags**: nested `if` pyramids at every call site.
- **Checked exceptions in application code**: cascading signature changes, broken encapsulation.
- **Returning null / passing null**: NPE landmines.
- **Empty catch blocks / catch-and-ignore**: see G4 Overridden Safeties in ch17.

## Code Examples
```java
// Before: logic buried in state checks (return-code style)
public void sendShutDown() {
  DeviceHandle handle = getHandle(DEV1);
  if (handle != DeviceHandle.INVALID) {
    retrieveDeviceRecord(handle);
    if (record.getStatus() != DEVICE_SUSPENDED) { ... }
    else { logger.log("Device suspended. Unable to shut down"); }
  } else { logger.log("Invalid handle for: " + DEV1.toString()); }
}

// After: algorithm and error handling separated
public void sendShutDown() {
  try { tryToShutDown(); }
  catch (DeviceShutDownError e) { logger.log(e); }
}
```
- **What it demonstrates**: exceptions unbury the shutdown algorithm from device-state bookkeeping.

## Reference Tables
| Situation | Technique |
|---|---|
| Low-level failure | Throw unchecked exception with context |
| Third-party API throws many types | Wrap; translate to one caller-meaningful type |
| "Failure" is a normal business alternative | SPECIAL CASE object |
| Would return null | SPECIAL CASE object or empty collection |
| Would accept null | Forbid by convention |

## Key Takeaways
1. Throw unchecked exceptions with context; do not return error codes.
2. Write the try-catch-finally skeleton first, test-driven.
3. Classify exceptions by the caller's needs; wrap third-party APIs.
4. Encode normal alternatives as SPECIAL CASE objects.
5. Never return null; never pass null.

## Connects To
- **Ch 8 (Boundaries)**: wrapping vendor APIs.
- **Ch 3 (Functions)**: error handling is one thing.
