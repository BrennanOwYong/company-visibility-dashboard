# Feature: company-memory

Parent PRD: `docs/product/PRD.md#teach-the-dashboard-about-the-organization`

## Purpose

Give the organization a durable, revisable explanation of its tools and data so the page-building
agent can focus on the requested page instead of repeating discovery work.

## User outcome

The user can explain organization-specific meaning in natural language, review what the product
understood, correct it later, and have later page work use the current accepted meaning.

## Scope and non-goals

The Memory page contains a persistent natural-language conversation and a separate current summary.
It covers:

- Which tools, accounts, and sources exist.
- What each account or source means to this organization.
- Where useful information comes from and how an authorized user reaches it.
- How concepts correspond across tools, such as subscriber, follower, reaction, or retained audience.
- Which measures, accounts, audiences, reactions, and business meanings matter.

The original conversation remains a record. The current summary can change when the user clarifies
meaning. The page-building agent uses the current accepted summary. Memory does not store passwords,
access tokens, or other credentials in its ordinary conversation or summary. It does not replace
Connected Tools as the place to authorize accounts.

## Positive flow

1. The user selects Memory from the side menu. The user sees the saved conversation and current
   organization summary, or a clear starting state if Memory is new.
2. The user explains a tool or goal in natural language, such as “track Instagram.” The conversation
   acknowledges the request without assuming that the phrase is complete.
3. The conversation asks focused questions about the Instagram metrics, accounts, audiences,
   reactions, business meaning, and authorized access path that matter to the organization.
4. The user answers in their own terms. The conversation shows a proposed update to the durable
   summary while the original messages remain unchanged.
5. The user accepts or corrects the proposed meaning. The current summary shows the accepted tools,
   sources, relationships, meanings, and access guidance.
6. The user starts a later page request. The page-building agent uses the current accepted Memory and
   asks only about meaning that remains unresolved for that page.
7. The user returns to Memory later and updates an account, meaning, source, or relationship. The
   original conversation remains, the summary changes only after review, and later page work uses the
   latest accepted summary.

## Negative and recovery flow

1. The user enters a broad or ambiguous statement. Memory does not silently choose an account,
   audience, measure, or business meaning. It asks focused questions and marks the topic incomplete
   until the important meaning is clear.
2. The user gives two conflicting meanings for the same concept. Memory shows the conflict, preserves
   both original statements, and asks which meaning is current before changing the accepted summary.
3. The user names a source that is not connected or cannot be accessed. Memory can record what the
   source means, but it clearly states that access is unverified and directs authorization to
   Connected Tools.
4. The user pastes a password, access token, or other credential. Memory warns the user, does not add
   the value to its ordinary saved conversation or summary, and gives a recovery path to remove the
   sensitive input and use Connected Tools.
5. The conversation is interrupted before an update is accepted. The original conversation and last
   accepted summary remain available. An unfinished proposal is not presented as accepted company
   meaning.
6. A summary update would remove or reverse existing meaning. Memory shows the proposed change and
   its effect. It does not silently replace the accepted meaning.
7. The user cannot access Memory because of a permission or loading problem. The product does not
   expose Memory content, states the problem, and provides a retry or access-help path.
8. The user returns after a later update. Memory shows the latest accepted summary without deleting
   the original conversation. Generated pages are not silently rewritten because Memory changed.

## User inputs and visible outcomes

- Natural-language descriptions produce focused clarification and a proposed summary update.
- Answers about tools, accounts, sources, metrics, audiences, reactions, business meaning, and access
  paths produce a clearer organization summary.
- Accepting a proposal makes it the current meaning for later page creation.
- Correcting or rejecting a proposal leaves the prior accepted meaning in place until a replacement
  is accepted.
- Returning later restores the original conversation and latest accepted summary.
- Sensitive credential input produces a warning and removal or recovery path, not a saved ordinary
  memory entry.

## Done outcomes

- **DC-01:** Given a new or existing user, when Memory opens, then the original saved conversation and
  latest accepted summary are visible according to the user's access, or a clear starting state is
  shown.
- **DC-02:** Given a broad request such as “track Instagram,” when Memory responds, then it clarifies
  the relevant metrics, accounts, audiences, reactions, business meaning, and access path before it
  treats the meaning as complete.
- **DC-03:** Given the user supplies organization meaning, when Memory prepares an update, then the
  user can review, accept, or correct the proposed summary without changing the original messages.
- **DC-04:** Given an accepted summary, when a later page request begins, then the page-building agent
  uses the current meaning and does not repeat already answered discovery questions.
- **DC-05:** Given conflicting or replacement meaning, when Memory detects it, then the conflict and
  proposed effect are visible and the accepted summary does not change silently.
- **DC-06:** Given an inaccessible or unconnected source, when it is described, then Memory can retain
  its organization meaning but labels access as unverified and directs authorization to Connected
  Tools.
- **DC-07:** Given sensitive credential text, when it enters Memory, then it is not retained in the
  ordinary conversation or summary and the user receives a clear privacy recovery path.
- **DC-08:** Given an interrupted summary proposal, when the user returns, then the last accepted
  summary and original conversation remain intact and the proposal is not shown as accepted.
- **DC-09:** Given the user revisits and accepts a correction, when a later page request starts, then
  it uses the latest accepted summary while existing pages do not silently change purpose.
- **DC-10:** Given a user lacks Memory access, when they try to open it, then Memory content is not
  exposed and a safe access-help or retry state appears.

## Subjective user-test questions

- Do “tool list and groups” and “relationships between meanings” feel understandable without the
  technical terms taxonomy and ontology?
- Does Memory ask enough to remove ambiguity without turning into a long interview?
- Can the user clearly distinguish original conversation, proposed meaning, and accepted summary?
- Does the user trust that sensitive credentials will not be kept in ordinary Memory content?
- Does a later page request feel faster and better focused because it uses Memory?

## Applicable principles

(none confirmed; candidate principles await user confirmation)

## Open questions

- Is Memory shared across the organization, limited to a team, or private to one user?
- Who can accept changes to the current organization summary?
- Does the user need version history, named approvals, or rollback for accepted summaries?
- What exact information makes a topic complete enough to stop clarification?
- How long are original conversations and summaries retained, and how can the user delete them?
- Should each generated page show which Memory statements guided its creation?
- What privacy, redaction, deletion, and audit rules are mandatory?
