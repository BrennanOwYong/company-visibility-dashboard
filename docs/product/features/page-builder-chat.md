# Feature: page-builder-chat

Parent PRD: `docs/product/PRD.md#ask-for-a-dashboard-page`

## Purpose

Let the user describe what they need to monitor and have a page-building agent make the requested
dashboard page.

## User outcome

The user can move from a company question to a working page without first learning how to design,
code, or connect the page.

## Scope and non-goals

This feature includes the plus-button destination, an opening message about company-wide visibility,
suggested dashboard pages, natural-language conversation, use of current Memory, clarification of
unresolved meaning, visible build progress, interruption recovery, and a clear success or failure
result.

The required suggestions include user retention across posting platforms in real time and subscriber
count over time. Their exact product meanings remain open. This feature does not pretend that an
unsupported source or unavailable measure can be connected. It does not store credentials in chat.

## Positive flow

1. The user selects the plus button. A chat opens with a helpful message that explains that
   visualizing company data can give visibility across the whole company.
2. The user sees suggested pages, including cross-platform retention in real time and subscriber
   count over time. Each suggestion is an action that can begin a page request.
3. The user chooses a suggestion or describes another company question. The conversation confirms
   the intended outcome in plain language.
4. The page-building agent reviews current Memory and connected tools. It uses known organization
   meaning without asking the user to repeat it.
5. If an important meaning remains unclear, the agent asks a focused question about the outcome,
   account, audience, measure, time range, or comparison that matters.
6. The user confirms the page request. The user sees understandable progress while the agent builds
   the real connected page.
7. Creation succeeds. The user sees the new page name, its purpose, and a direct route to the saved
   page in the side menu.

## Negative and recovery flow

1. The user gives a broad request such as “show Instagram.” The agent does not guess silently. It
   uses Memory and then asks only for the missing account, audience, reaction, business meaning, or
   time view.
2. The user chooses a suggestion whose meaning is not defined, such as “retention.” The agent asks
   what continued audience behavior should count before it builds the page.
3. A required account is not connected. The agent states what connection is needed, preserves the
   request, and gives the user a route to Connected Tools.
4. A connected service does not provide the requested information. The agent states the limitation
   and offers only clearly labeled alternatives that use available information.
5. The user attempts to include a password or secret. The chat warns the user, excludes the secret
   from its ordinary saved conversation and summary, and directs connection work to Connected Tools.
6. The user leaves or the build is interrupted. The conversation and confirmed request persist. The
   user can return and resume without starting again.
7. Page creation fails. The product does not add a broken page as if it succeeded. It explains what
   stopped, preserves the conversation, and lets the user retry after recovery.

## User inputs and visible outcomes

- Selecting a suggestion adds that idea to the conversation for clarification or confirmation.
- Describing a company question produces a plain-language statement of the intended page.
- Answering a clarification updates the request without changing the user's original conversation.
- Confirming a request starts visible page-building progress.
- Successful completion provides a named side-menu destination and direct link.
- Interrupted or failed work retains the conversation and offers an appropriate resume or recovery
  action.

## Done outcomes

- **DC-01:** Given the user selects the plus button, when chat opens, then it explains the value of
  company-wide visibility and shows actionable page suggestions.
- **DC-02:** Given the required example suggestions, when the opening view appears, then it includes
  cross-platform retention and subscriber count over time.
- **DC-03:** Given a request with meaning already present in Memory, when the agent prepares the page,
  then it uses that meaning and does not ask the user to repeat it.
- **DC-04:** Given an important unresolved meaning, when the agent responds, then it asks a focused
  product question instead of silently guessing.
- **DC-05:** Given a required connection is absent or a requested measure is unavailable, when the
  agent checks the request, then it states the limitation, preserves the request, and offers a safe
  recovery path.
- **DC-06:** Given a confirmed feasible request, when building starts, then the user sees progress
  and receives either a real saved page or an explicit failure result.
- **DC-07:** Given the chat or build is interrupted, when the user returns, then the original
  conversation and current request remain available to resume.
- **DC-08:** Given secret text is supplied in chat, when it is handled, then it is not included in
  the ordinary saved conversation summary and the user is directed to Connected Tools.

## Subjective user-test questions

- Does the opening message make the value of a new dashboard page clear?
- Do the suggestions feel useful rather than generic?
- Does the conversation ask enough to build the right page without feeling repetitive?
- Does progress give the user confidence that actual connected work is occurring?
- Is failure recovery clear and low effort?

## Applicable principles

(none confirmed; candidate principles await user confirmation)

## Open questions

- What must “retention” and “real time” mean in the first suggested page?
- What must the user approve before the agent uses a connection, publishes a page, or replaces an
  existing page?
- Can several users join or edit one page-building conversation?
- What build duration should be considered acceptable before the product offers another action?

