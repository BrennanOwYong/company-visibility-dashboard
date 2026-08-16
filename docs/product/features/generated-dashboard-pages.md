# Feature: generated-dashboard-pages

Parent PRD: `docs/product/PRD.md#use-and-revisit-a-created-page`

## Purpose

Turn an agreed page request into a persistent company view that uses actual connected information.

## User outcome

The user can monitor the requested company question, understand the page and its data state, and
return to the same page and context later.

## Scope and non-goals

This feature includes the working page, its side-menu icon or tab, connected information, visible
source and availability state, original creation conversation, purpose summary, how-it-works summary,
and persistence across return visits.

It does not show invented information when live information is unavailable. It does not silently
replace the page's original purpose. Rules for editing, replacing, sharing, and deleting pages need
confirmation.

## Positive flow

1. A page build finishes successfully. The user sees the named page and its icon or tab in the side
   menu.
2. The user opens the page. It visualizes the agreed company question with information from the
   authorized connected tools.
3. The user reviews the page. The user can tell the page's purpose, how it works in plain language,
   which source context it uses, and whether its information is current.
4. The user opens the page history or context. The original page-creation conversation remains
   available with the purpose and how-it-works summary.
5. The user leaves and returns later. The same page, conversation, and summary remain available. The
   page shows refreshed connected information or a clear current availability state.

## Negative and recovery flow

1. A required connection expires after page creation. The page remains available, states which
   information cannot update, and directs the user to reconnect. It does not show stale information
   as if it were current.
2. A source has no results for the selected period. The page shows a true empty state and explains
   the selection. It does not treat an empty result as a build failure.
3. One of several sources is unavailable. The page identifies the affected part, keeps valid
   unaffected information usable, and gives the user a retry or connection action.
4. The saved page cannot load. Its side-menu destination remains known, the user sees an error and a
   retry action, and the original conversation is not lost.
5. Current Memory conflicts with the meaning used when the page was built. The page does not silently
   change its purpose. It tells the user that the organization meaning changed and offers a review
   path before revision.
6. Page construction does not complete. No broken destination is presented as a successful page. The
   request and conversation remain available for retry.

## User inputs and visible outcomes

- Selecting the generated destination opens the saved page.
- Changing an available time range or page choice updates the visible information and its state.
- Opening page context shows the preserved original conversation, purpose, and how-it-works summary.
- Reconnecting a required tool restores information when the service permits it.
- Returning later restores the page and states whether its connected information is current,
  delayed, empty, or unavailable.

## Done outcomes

- **DC-01:** Given page creation succeeds, when completion is reported, then a named destination with
  an icon or tab appears in the side menu.
- **DC-02:** Given all required connections are available, when the page opens, then it answers the
  agreed question with actual connected information and a visible data state.
- **DC-03:** Given a generated page, when the user opens its context, then the original creation
  conversation, purpose summary, and how-it-works summary are available.
- **DC-04:** Given the user leaves and returns, when they open the product again, then the generated
  destination, page, conversation, and summaries persist.
- **DC-05:** Given a source is empty, delayed, expired, or unavailable, when the page opens, then the
  condition is clear and unavailable information is not presented as current.
- **DC-06:** Given one source fails in a multi-source page, when other information remains valid,
  then the valid part remains usable and the failed part has a recovery action.
- **DC-07:** Given current Memory conflicts with the page's original meaning, when the conflict is
  detected, then the page does not silently change and the user receives a review path.
- **DC-08:** Given construction fails before completion, when the user reviews the result, then no
  broken page is presented as successful and the request can be retried.

## Subjective user-test questions

- Does the generated page answer the question the user intended?
- Can the user understand the page without reading its original conversation?
- Does the purpose and how-it-works summary increase trust without adding too much text?
- Can the user distinguish current, delayed, empty, and unavailable information quickly?
- Does a return visit feel continuous rather than like starting again?

## Applicable principles

(none confirmed; candidate principles await user confirmation)

## Open questions

- What information freshness is required for each type of page?
- How can a user edit, replace, share, archive, or delete a generated page?
- How long must page conversations and summaries remain available?
- Should the page show the exact Memory statements that influenced its creation?
- Who can view a page and its original conversation?

