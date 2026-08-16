# Chapter 11: Systems

## Core Idea
Separate constructing a system from using it; keep the architecture decoupled with plain objects plus injected dependencies so it can grow and decisions can be deferred.

## Frameworks Introduced
- **Separate Construction from Use**: the startup process (building objects, wiring dependencies) is a concern of its own; mixing it into runtime logic (the LAZY-INITIALIZATION idiom with its hard-coded `new`, testing pain, and scattered setup) breaks modularity and SRP.
- **Separation of Main**: move all construction to `main` (or modules called by `main`); the application runs with no knowledge of how anything was built — the flow of dependencies points one way, from main into the app.
- **Factories**: when the application must control WHEN an object is created (an `Order` needing `LineItem`s), give it an ABSTRACT FACTORY interface; the HOW stays in main with the factory implementation.
- **Dependency Injection (DI) / Inversion of Control (IoC)**: the class stays passive; an authoritative container/mechanism injects dependencies via constructor or setters. True DI is the most powerful separation of construction from use. (JNDI-style lookup is only partial — the class still asks.)
- **Scaling Up**: "software systems are unique compared to physical systems: their architectures can grow incrementally, if we maintain the proper separation of concerns." The EJB2 counterexample: entity beans tangled business logic with container plumbing (mandated interfaces, lifecycle methods), killing testability, reuse, and OO itself.
- **Cross-Cutting Concerns and AOP**: persistence, transactions, security, logging cut across object boundaries. Aspect-oriented programming restores modularity: JDK dynamic proxies (for interface-based wrapping), pure-Java AOP frameworks (Spring/JBoss — POJOs plus declarative config; EJB3 largely follows this model with annotations), full AspectJ for the strongest tooling.
- **Test Drive the System Architecture**: with POJOs and aspect-like decoupling, you can start simple and grow; Big Design Up Front (BDUF) is harmful because early commitment locks the architecture against learning.
- **Optimize Decision Making**: modularity lets decisions be made at the last possible moment, by the person with the most information; premature decisions are made with suboptimal knowledge.
- **Use Standards Wisely, When They Add Demonstrable Value**: standards (the EJB2 lesson) can become hype-driven ceremony detached from the value they were meant to serve.
- **Systems Need Domain-Specific Languages**: a good DSL minimizes the "communication gap" between domain concept and implementing code; all levels of abstraction expressed as POJOs.

## Key Concepts
- **POJO** (Plain Old Java Object): business logic with zero framework coupling; testable in isolation.
- **The city metaphor**: systems, like cities, work because teams manage components at different levels of abstraction; clean architecture keeps those levels separated.
- **Mental note**: "An optimal system architecture consists of modularized domains of concern, each implemented with POJOs, integrated together with minimally invasive Aspects; such an architecture can be test-driven."

## Anti-patterns
- **LAZY-INITIALIZATION with hard-coded construction**: hidden global setup, untestable, SRP violation.
- **EJB2-style framework invasion**: business objects forced to inherit container concerns.
- **BDUF**: architectural commitment before knowledge exists.

## Code Examples
```java
// Construction knowledge stays out of the application
public Service getService() {
  if (service == null)
    service = new MyServiceImpl(...); // LAZY-INIT: coupling + untestable — avoid
  return service;
}
// Remedy: main (or a DI container) constructs MyServiceImpl and injects it.
```
- **What it demonstrates**: the hard-coded `new` couples the class to the implementation and its constructor arguments; DI removes both.

## Reference Tables
| Concern separation tool | Use when |
|---|---|
| Separation of Main | Always — baseline |
| Abstract Factory | App controls creation timing |
| Dependency Injection | App needs the object, not its construction |
| JDK Proxy / CGLIB | Wrapping individual objects/interfaces |
| Spring-style AOP config | System-wide cross-cutting concerns, POJO domain |
| AspectJ | Fine-grained aspect needs beyond method interception |

## Key Takeaways
1. All construction happens in main or a DI container; application code never calls `new` on its collaborators.
2. Keep business logic in POJOs; let aspects/proxies carry cross-cutting concerns.
3. Grow the architecture incrementally; defer decisions to the last responsible moment.
4. Adopt standards only for demonstrable value.
5. Never let a mess (at any scale) seem worthwhile: "the simplest thing that could possibly work" applies to systems too.

## Connects To
- **Ch 8 (Boundaries)**: DI seams are boundary seams.
- **Ch 12 (Emergence)**: simple design rules govern the growing system.
