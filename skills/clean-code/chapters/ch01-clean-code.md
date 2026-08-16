# Chapter 1: Clean Code

## Core Idea
Bad code slows every future change until productivity approaches zero; the only way to go fast is to keep the code clean at all times.

## Frameworks Introduced
- **The Total Cost of Owning a Mess**: messy code compounds. Each change tangles the code further, team productivity falls toward zero, and the "grand redesign" that follows takes years and repeats the cycle.
  - When to use: when tempted to ship a mess "to go fast".
  - How: treat cleanliness as the precondition of speed, never its trade-off.
- **The Boy Scout Rule**: "Leave the campground cleaner than you found it." Check in each module a little cleaner than you checked it out.
  - When to use: on every commit that touches existing code.
  - How: one renamed variable, one split function, one removed duplication per visit; no big-bang cleanups required.
- **Code-sense**: the learned instinct that sees a mess and knows the sequence of transformations that improves it. Reading this book gives the definitions; deliberate practice builds the sense.

## Key Concepts
- **Wading**: slogging through obscure code where every change breaks two other places.
- **LeBlanc's law**: "Later equals never." Deferred cleanup does not happen.
- **The Grand Redesign in the Sky**: the doomed rewrite a team demands after the mess wins; the rewrite team races the maintainers for years.
- **Attitude**: programmers who bow to schedule pressure by shipping messes are unprofessional; defending the code is the programmer's job, as defending patient safety is the doctor's.
- **We are authors**: the ratio of time spent reading code to writing it is well over 10:1, so making code easy to read makes it easier to write.

## Mental Models
- Think of clean code as **cared-for** code (Michael Feathers): it looks like the author sweated the details and left nothing obvious to improve.
- Use Bjarne Stroustrup's test: clean code is "elegant and efficient", does one thing well, and makes bugs hard to hide.
- Use Grady Booch's test: clean code "reads like well-written prose" and never obscures the designer's intent.
- Use Ward Cunningham's test: clean code makes each routine "pretty much what you expected" — the language looks made for the problem.

## Anti-patterns
- **"We'll clean it later"**: LeBlanc's law; later never comes.
- **Blaming managers for the mess**: managers defend the schedule; programmers must defend the code with equal passion.
- **Making a mess to meet a deadline**: the mess slows you down immediately, not eventually; you will miss the deadline anyway.

## Code Examples
None in this chapter; it argues from experience reports and expert definitions.

## Reference Tables
| Expert | Definition of clean code |
|---|---|
| Bjarne Stroustrup | Elegant, efficient, does one thing well; bugs cannot hide |
| Grady Booch | Simple, direct; reads like well-written prose |
| Dave Thomas | Readable by others; has tests; minimal; literate |
| Michael Feathers | Looks like it was written by someone who cares |
| Ron Jeffries | No duplication, expresses all design ideas, minimizes entities |
| Ward Cunningham | Each routine is what you expected; language fits the problem |

## Key Takeaways
1. Messy code has a compounding cost; productivity trends to zero as a mess grows.
2. The only way to go fast is to keep the code clean; there is no clean-vs-fast trade.
3. Apply the Boy Scout Rule: every check-in leaves the module a little cleaner.
4. Reading dominates writing 10:1; optimize code for the reader.
5. Defend the code against schedule pressure; that defense is professionalism, not obstruction.

## Connects To
- **Ch 12 (Emergence)**: the four rules of simple design operationalize "clean".
- **Ch 17 (Smells and Heuristics)**: the concrete catalogue of what "dirty" looks like.
