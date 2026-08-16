# Chapter 13: Concurrency

## Core Idea
Concurrency is a decoupling strategy (what gets done from when it gets done) that is hard to get right; defend with isolation, small synchronized sections, and relentless multi-configuration testing.

## Frameworks Introduced
- **Myths and Misconceptions**: concurrency does not always improve performance (only when wait time is shareable); it DOES change the design (decoupling what from when); understanding the container's (e.g. web server's) concurrency model is not optional.
- **Balanced truths**: concurrency incurs overhead, is complex, its bugs are usually not repeatable (dismissed as one-offs), and it often demands a fundamental design change.
- **Concurrency Defense Principles**:
  - **SRP applied**: keep concurrency-related code separate from other code; it has its own lifecycle of development, change, and tuning.
  - **Corollary: Limit the Scope of Data**: minimize shared data; every synchronized critical section is a bug surface.
  - **Corollary: Use Copies of Data**: pass copies and collect results, or copy-then-merge; avoiding sharing beats synchronizing sharing.
  - **Corollary: Threads Should Be as Independent as Possible**: each thread lives in its own world (servlet model: request-local data only).
- **Know Your Library**: use `java.util.concurrent` — thread-safe collections (`ConcurrentHashMap` outperforms synchronized `HashMap`), executor framework, nonblocking solutions (`ReentrantLock`, `Semaphore`, `CountDownLatch`); library classes are not automatically thread-safe — check.
- **Know Your Execution Models**: recognize the named problems — **Producer-Consumer** (bound queue coordination), **Readers-Writers** (throughput vs starvation balance), **Dining Philosophers** (deadlock via resource contention). Learn the canonical algorithms before inventing.
- **Beware Dependencies Between Synchronized Methods**: two synchronized methods on one shared class invite state corruption; use one method per shared class, or client-based/server-based/adapted locking when you cannot.
- **Keep Synchronized Sections Small**: locks are expensive and serialize execution; guard critical sections only.
- **Writing Correct Shut-Down Code Is Hard**: graceful termination invites deadlocks (parent waiting on a child that never signals); plan shutdown early and use proven algorithms.
- **Testing Threaded Code**:
  - Treat spurious failures as candidate threading issues; do not dismiss them as cosmic rays.
  - Get your nonthreaded code working first; do not chase both bug classes at once.
  - Make threaded code pluggable and tunable (thread counts, real vs test doubles, speed variations).
  - Run with more threads than processors (forces task swapping), on all target platforms, early and often.
  - Instrument the code to force failures: hand-coded or automated jiggling (`Object.wait/sleep/yield/priority` insertions, e.g. via AOP/CGLIB) flushes out rare orderings.

## Key Concepts
- **The 12,870 paths fact**: two threads over three lines of shared-state increment yield 12,870 possible execution paths; "just this once" reasoning fails at that scale.
- **Client-based vs server-based locking**: who owns the compound-operation lock.
- **Jiggling strategies**: randomized instrumentation to surface rare interleavings.

## Anti-patterns
- **Ignoring one-off failures** (T7 territory): threading bugs present as flakiness.
- **Shared mutable state by convenience**: unsynchronized static fields, shared collections.
- **Big synchronized blocks**: contention and hidden coupling.
- **Freezing the code until tests pass "enough"**: nonrepeatable bugs need forced-failure instrumentation, not hope.

## Code Examples
```java
// Compound operations on thread-safe collections still need care:
// ConcurrentHashMap supplies atomic compound ops — use them, don't lock around get/put
map.putIfAbsent(key, value);
```
- **What it demonstrates**: thread safety of individual methods does not compose; use the library's atomic compound operations.

## Reference Tables
| Execution model | Problem shape |
|---|---|
| Producer-Consumer | Bound queue; producers signal consumers, consumers signal producers |
| Readers-Writers | Read throughput vs writer starvation |
| Dining Philosophers | Many threads competing for finite resources → deadlock risk |

## Key Takeaways
1. Isolate concurrency code (SRP); minimize and partition shared data; prefer copies and independent threads.
2. Use `java.util.concurrent` primitives and named execution models before inventing.
3. Keep synchronized sections few and small; avoid dependencies between synchronized methods.
4. Treat every flaky test as a threading suspect.
5. Instrument to force failures; run early, often, on every platform, with more threads than cores.

## Connects To
- **Appendix A (Concurrency II)**: deeper treatment with worked examples.
- **Ch 9 (Unit Tests)**: F.I.R.S.T.'s Repeatable rule collides with nondeterminism — hence jiggling.
