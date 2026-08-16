# Chapter 6: Objects and Data Structures

## Core Idea
Objects hide data behind behavior; data structures expose data and have no behavior. The two are opposites, and choosing the wrong one for the job creates hybrids that get the worst of both.

## Frameworks Introduced
- **Data Abstraction**: hiding implementation is about abstractions, not about getters and setters. Express data in abstract terms (a fuel level as a percentage) rather than pushing variables out through accessors. "The worst option is to blithely add getters and setters."
- **Data/Object Anti-Symmetry**:
  - Procedural code (data structures) makes it easy to add new functions without changing existing data structures; hard to add new data structures because all functions change.
  - OO code makes it easy to add new classes without changing existing functions; hard to add new functions because all classes change.
  - Choose per axis of change: new types expected → objects; new operations expected → data structures and procedures. "Everything is an object" is a myth.
- **The Law of Demeter**: a method `f` of class `C` should only call methods of `C`, of objects `f` created, of `f`'s arguments, or of `C`'s instance variables. Talk to friends, not to strangers.
- **Data Transfer Objects (DTO)**: a class with public variables and no functions; the first stage of translation from raw communication data. The **Active Record** variant adds `save`/`find` — treat it as a data structure and keep business rules in separate objects, never inside it.

## Key Concepts
- **Train wreck**: `ctxt.getOptions().getScratchDir().getAbsolutePath()` — chained calls that expose the whole navigation structure. Demeter applies only if these are objects; pure data structures accessed by fields are exempt.
- **Hybrid**: half object, half data structure — functions that do things plus public-ish accessors that tempt external functions to use internals procedurally. Hard to add functions AND hard to add data structures; a sign of muddled design.
- **Hiding structure**: instead of asking an object for its internals to act on them, tell the object to do the thing: `ctxt.createScratchFileStream(classFileName)` instead of walking to the scratch directory yourself.

## Anti-patterns
- **Getter/setter reflex**: auto-generating accessors for every field exposes implementation as thoroughly as public fields.
- **Hybrids**: the worst of both worlds (see above).
- **Feature envy across boundaries**: navigating through objects to manipulate a distant stranger's data.

## Code Examples
```java
// Concrete Point — exposes implementation (rectangular, manipulated independently)
public class Point {
  public double x;
  public double y;
}

// Abstract Point — enforces an access policy; could be rectangular or polar
public interface Point {
  double getX();
  double getY();
  void setCartesian(double x, double y);
  double getR();
  double getTheta();
  void setPolar(double r, double theta);
}
```
- **What it demonstrates**: the abstract interface hides representation and forces atomic coordinate setting; accessors alone would not.

## Reference Tables
| | Add new type | Add new function |
|---|---|---|
| Objects (OO) | easy — new class, no existing code changes | hard — every class changes |
| Data structures (procedural) | hard — every function changes | easy — new function, no structure changes |

## Key Takeaways
1. Objects expose behavior and hide data; data structures expose data and have no meaningful behavior.
2. Pick the form by the expected axis of change (new types vs new operations).
3. Obey the Law of Demeter for objects; field access on data structures is exempt.
4. Tell objects to do things; do not ask for internals and act on them.
5. Never build hybrids; keep DTOs behavior-free.

## Connects To
- **Ch 17 (G14 Feature Envy, G36 Avoid Transitive Navigation)**: heuristic codes for Demeter violations.
- **Ch 8 (Boundaries)**: hiding third-party data structures behind your own interfaces.
