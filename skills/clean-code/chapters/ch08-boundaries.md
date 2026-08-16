# Chapter 8: Boundaries

## Core Idea
Keep third-party code at arm's length: wrap it, learn it through tests, and depend on your own interfaces so change on either side of the boundary stays cheap.

## Frameworks Introduced
- **Using Third-Party Code (the interface tension)**: providers aim for broad applicability; users want a focused interface. `java.util.Map` offers `clear()`, generics churn, and unbounded capability to every holder of the reference. Encapsulate the boundary: a `Sensors` class holds the `Map` inside, casts/generics stay hidden, and the interface is tailored and constrained to what the application needs. Rule: do not pass `Map` (or any boundary interface) around your system; keep it inside a class where it is used, and avoid returning it from or accepting it into public APIs.
- **Learning Tests**: instead of experimenting with a new library inside production code, write tests that probe the third-party API — controlled experiments that verify your understanding (the log4j session: each failed expectation taught how the package really works, ending in a small set of encoding tests).
- **Learning Tests Are Better Than Free**: the learning had to happen anyway; the tests remain and run against every new library version, flagging behavioral breaks. Without them, upgrade fear keeps teams on stale versions.
- **Using Code That Does Not Yet Exist**: when the API on the other side is undefined (the Transmitter radio case), define the interface you wish you had (`Transmitter.transmit(frequency, dataStream)`), work against it, and bridge later with an ADAPTER when the real API arrives. Your code stays readable and focused on what it is trying to do, and the seam gives you a testing point (FakeTransmitter, boundary tests through the adapter).
- **Clean Boundaries**: good software designs accommodate change without huge investment; code at boundaries needs clear separation plus tests that define expectations. Depend on something you control, not on something that controls you.

## Key Concepts
- **Boundary interface**: any API surface owned by someone else (framework, vendor, another team).
- **ADAPTER pattern at the seam**: converts your ideal interface to the real one; concentrates the change when the vendor moves.
- **Seam for testing**: the wrapped boundary is where fakes plug in.

## Anti-patterns
- **Passing raw boundary types through the system**: every user inherits the full uncontrolled interface and every vendor change ripples everywhere.
- **Learning a library inside production code**: debugging your code and the library at once.
- **Upgrade paralysis**: no boundary tests → staying on old versions "longer than we should".

## Code Examples
```java
// Boundary hidden inside a class; interface tailored to the application
public class Sensors {
  private Map sensors = new HashMap();
  public Sensor getById(String id) {
    return (Sensor) sensors.get(id);
  }
}
```
- **What it demonstrates**: the `Map` (and its casts, generics, and `clear()`) stops at the boundary; callers see only what the domain needs.

## Reference Tables
| Boundary situation | Technique |
|---|---|
| Broad vendor interface | Encapsulating wrapper class |
| New unfamiliar library | Learning tests |
| API not yet defined | Define ideal interface + ADAPTER later |
| Vendor upgrades | Re-run learning/boundary tests |

## Key Takeaways
1. Wrap third-party types; never let them travel through your system.
2. Write learning tests before wiring a new library into production code.
3. When the other side is undefined, code to the interface you wish existed.
4. Boundary tests make library upgrades a test run instead of a leap of faith.

## Connects To
- **Ch 7 (Error Handling)**: exception wrapping is boundary wrapping.
- **Ch 11 (Systems)**: dependency injection and factories manage the same seams at system scale.
