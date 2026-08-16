# Chapter 4: Comments

## Core Idea
Comments compensate for failure to express intent in code; every comment is a candidate for replacement by a better name or a smaller function, and comments rot because code moves and comments do not.

## Frameworks Introduced
- **Comments Do Not Make Up for Bad Code**: "Don't comment bad code — rewrite it." Clear, expressive code with few comments beats cluttered code with many.
- **Explain Yourself in Code**: `if (employee.isEligibleForFullBenefits())` replaces `// Check to see if the employee is eligible for full benefits` plus the raw condition.
- **Good comments (the short list)**: legal comments (copyright headers), informative comments (e.g. the format a regex matches), explanation of intent (why this choice), clarification of obscure library arguments you cannot rename, warnings of consequences ("Don't run unless you have time to kill"), TODO comments (tracked, not an excuse for bad code), amplification of importance, and Javadocs in public APIs.
- **Bad comments (the long list)**: mumbling, redundant comments that restate the code, misleading comments, mandated comments (Javadoc on every function), journal comments (change logs — use version control), noise comments (`// Default constructor`), position markers/banners, closing-brace comments (shrink the function instead), attributions (`/* Added by Rick */` — version control knows), HTML in comments, nonlocal information, too much information, and inobvious connections.

## Key Concepts
- **Comment rot**: the code moves during maintenance; the comment stays behind and becomes a lie. "Truth can only be found in one place: the code."
- **Commented-out code**: readers assume it is there for a reason and never delete it; it accumulates like dregs. Source control remembers — delete it.
- **Javadoc discipline**: valuable for public APIs; noise for internal code; a mandated-comment rule produces abomination like `/** @param title The title of the CD */` on `addCD(String title, ...)`.

## Anti-patterns
- **Redundant comment**: takes longer to read than the code it "explains" and adds nothing (Tomcat's `ContainerBase` header comments).
- **Journal/attribution comments**: duplicate version control badly.
- **Closing-brace comments** (`} // while`): a signal the function is too long.
- **Commented-out code**: delete on sight (C5 in ch17).

## Code Examples
```java
// Bad — comment restates a check the code should express:
// Check to see if the employee is eligible for full benefits
if ((employee.flags & HOURLY_FLAG) && (employee.age > 65))

// Good — the code speaks:
if (employee.isEligibleForFullBenefits())
```
- **What it demonstrates**: extracting a well-named predicate deletes the comment and its rot risk.

## Reference Tables
| Comment type | Verdict |
|---|---|
| Legal, informative, intent, warning, TODO, amplification, public-API Javadoc | Acceptable |
| Redundant, misleading, mandated, journal, noise, banner, closing-brace, attribution, HTML, nonlocal, commented-out code | Remove or rewrite the code |

## Key Takeaways
1. Prefer expressing intent in a name or function over any comment.
2. A comment that restates the code is noise; delete it.
3. Never leave commented-out code; version control remembers.
4. Keep a comment near the code it describes; nonlocal comments rot fastest.
5. Reserve Javadoc for public APIs.

## Connects To
- **Ch 17 (C1–C5)**: the comment smells codified.
- **Ch 2 (Meaningful Names)**: the primary comment-replacement tool.
