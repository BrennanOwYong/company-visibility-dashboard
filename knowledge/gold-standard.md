# Gold standard — what a factory build is graded against

Source: [Vibecode Gold-Standard Benchmark (Riley Brown)](https://app.notion.com/p/37b4111839a8812dafdcc015a5e4138c) (Notion, fetched 2026-07-04). Vibecode is the reference for enterprise-grade one-shot app generation; this file is the factory's standing copy of its 100-point rubric plus the levers behind it. Grade a single prompt-to-app run; the sanity agent scores every finished milestone against this, and the validator's per-ticket work maps to criterion F.

## The rubric (score /100)

| # | Criterion | Pts | Full marks looks like |
|---|---|---|---|
| A | Visual fidelity and craft | 20 | Deliberate layout, typography, spacing, color harmony, originality; no default purple-gradient template feel |
| B | UX completeness | 10 | Navigation, empty, loading, and error states plus interaction detail (transitions, haptics) — never happy-path-only |
| C | Backend and data persistence | 15 | Server + database provisioned, data persists and is shared across users, schema fits the domain |
| D | Authentication and accounts | 10 | Working sign-in, sessions, protected routes; multiple providers without manual wiring |
| E | Secure integrations | 10 | External API calls proxied server-side, keys never in the frontend; catalog attaches by instruction |
| F | Functional correctness end to end | 15 | Core features work when exercised like a user would (the validator's standard); deduct for looks-right-fails-on-interaction |
| G | Deployability | 5 | A real shippable artifact, not a preview |
| H | One-shot ratio | 10 | Fraction of the described app working from the first prompt with no follow-ups |
| I | Iterate-ability | 5 | A plain-language refinement changes the right thing without breaking the rest |

**Bands:** 85-100 enterprise-grade one-shot (the target) · 65-84 strong but needs follow-ups · 40-64 good demo, not a product · <40 static mockup.

## The levers behind full marks (copy these, they are why Vibecode scores)

1. **One constrained target stack** — the model works in a well-trodden space; persistent style context so taste carries without re-explaining.
2. **Backend, database, and auth provisioned by default** — "functional" is the baseline, not an add-on; the single biggest gap between mockup and product.
3. **All third-party APIs proxied server-side** with a pre-curated catalog — removes the key-management/auth/payment glue where one-shots usually break.
4. **Right model per seat** — route sub-tasks to the model that fits them.
5. **Intent-over-implementation cloning** — a one-pager capturing experience, functionality, and required APIs; the builder owns the how. (This is the PM's product.md by another name.)
6. **A separate adversarial evaluator scores originality and craft** — models default to bland UI; the maker never grades it.

## How the factory applies it

- **Architecture (architecture-derivation skill):** levers 1-3 are architecture decisions — record them as ADRs when they apply.
- **Validator-agent:** owns criterion F per ticket; criteria B's objective half (states present) is in every ticket's success criteria via the UX baseline.
- **Sanity agent (post-all-features):** scores the assembled product against the full rubric and writes the score with per-criterion notes; anything under the 85 band opens tickets, not excuses.
- **User-test cards:** the user's taste judgment maps to A and the feel half of B — the card asks, never asserts.

## References

- https://app.notion.com/p/37b4111839a8812dafdcc015a5e4138c (fetched 2026-07-04)
- Vibecode docs cited therein: backend-auth.md, integrations/index.md, web-to-mobile.md, claude-code.md
- Anthropic front-end grading rubric: https://www.youtube.com/watch?v=nBH07G-zayk
