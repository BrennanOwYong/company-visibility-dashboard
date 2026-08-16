# Feature: dashboard-shell

Parent PRD: `docs/product/PRD.md#user-journeys`

## Purpose

Give the user one calm, consistent place to reach company information, connected tools, Memory, and
page creation.

## User outcome

The user can understand where they are, move between saved pages, and start a new page without
searching through the product.

## Scope and non-goals

This feature includes the soft pastel orange product frame, a persistent side menu, destinations for
Connected Tools and Memory, a plus button, and a destination for every successfully created page.
It includes an understandable selected, loading, empty, and unavailable state.

It does not define the contents of a connected tool, Memory conversation, or generated page. It does
not define a company brand beyond the requested soft pastel orange direction.

## Positive flow

1. The user opens the product. The user sees a soft pastel orange dashboard frame and a side menu.
2. The user reviews the side menu. The user sees Connected Tools, Memory, the plus button, and all
   saved dashboard pages that they can access.
3. The user selects a side-menu destination. The selected destination is clear, and its page opens
   without removing the menu.
4. The user selects the plus button. The page-creation chat opens and explains what the user can do.
5. After a page is successfully created, the user sees its icon or tab in the side menu and can open
   it from there.
6. The user leaves and returns later. The same saved page destinations remain available.

## Negative and recovery flow

1. The user opens the product before any dashboard page exists. The user sees a useful empty state,
   Connected Tools, Memory, and the plus button. The product does not show a blank or broken menu.
2. The user selects a saved page that is temporarily unavailable. The menu remains usable, the user
   sees that the page cannot open, and the user can retry or choose another destination.
3. The user opens the product on a narrow display or with enlarged text. Navigation remains readable
   and usable. Important labels and controls do not disappear without an understandable alternative.
4. The product cannot load all saved destinations. It identifies the loading problem, does not
   silently remove known pages, and lets the user retry.

## User inputs and visible outcomes

- Selecting Connected Tools opens connection management.
- Selecting Memory opens the organization Memory conversation and summary.
- Selecting the plus button opens page creation.
- Selecting a saved-page icon or tab opens that page and shows which destination is active.
- Returning to the product restores the saved destinations that the user can access.

## Done outcomes

- **DC-01:** Given the product opens successfully, when the user views its frame, then the visible
  style is soft pastel orange and a persistent side menu is present.
- **DC-02:** Given no generated page exists, when the user opens the product, then Connected Tools,
  Memory, and the plus button remain visible with a useful empty state.
- **DC-03:** Given a saved page exists, when the user opens or returns to the product, then the page
  appears as a side-menu destination with an icon or tab.
- **DC-04:** Given the user selects any available destination, when navigation finishes, then that
  page opens and the selected destination is visibly clear.
- **DC-05:** Given one destination fails to load, when the failure occurs, then the side menu remains
  usable and the user can retry or go elsewhere.
- **DC-06:** Given the user uses enlarged text or a narrow display, when they navigate the product,
  then all primary destinations and the plus action remain understandable and usable.

## Subjective user-test questions

- Does the soft pastel orange style feel calm, clear, and suitable for a company dashboard?
- Can the user understand the side menu without instruction?
- Is the plus button easy to find and does its purpose feel clear?
- Does the menu still feel manageable after generated pages are added?

## Applicable principles

(none confirmed; candidate principles await user confirmation)

## Open questions

- What exact palette, logo, and accessibility preferences should govern the visual style?
- How should the product choose a generated page icon, and can the user change it?
- Which company roles can see or reorder each side-menu destination?

