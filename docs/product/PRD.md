# Current Product Requirements

This file is the sole active product-level source of truth. Replace it when product intent changes; Git history preserves superseded requirements.

## Problem and users

People who run a company use many creator and social-media tools. Each tool presents its own
accounts, audiences, and reactions. It is difficult to see how the company performs as a whole.
It is also costly to explain the same tool meanings and data locations each time a new dashboard
view is made.

The initial user is a person who wants to monitor company performance without manually building a
new reporting system for every question. The exact company roles and access differences are open
product decisions.

In this product:

- A **connected tool** is a service account that the user has authorized the dashboard to read.
- A **dashboard page** is a saved view that answers one company question with connected data.
- The **page-building agent** is the assistant in the product that creates a working dashboard page
  from the user's conversation.
- The **Memory page** is a saved conversation and summary of what the organization's tools and data
  mean.
- A **tool taxonomy** is the organization's list and grouping of its tools, accounts, and data
  sources.
- A **tool ontology** is the organization's explanation of how meanings relate across those tools.
  For example, it explains whether a subscriber on one platform should be compared with a follower
  on another platform.

## Desired outcomes

- Give the user one soft pastel orange dashboard for company-wide visibility.
- Let the user securely connect supported social-media creator accounts and use available audience
  reaction data.
- Let the user describe a company question in a chat and receive a working, connected dashboard
  page.
- Help the user begin with useful page suggestions, such as retention across posting platforms or
  subscriber count over time.
- Keep created pages, their original conversations, and clear summaries so the user can return.
- Keep current organization knowledge about tools, accounts, data meaning, and data access so page
  creation needs less repeated exploration.

## Scope

- A persistent side menu with access to connected tools, Memory, saved dashboard pages, and a plus
  button for page creation.
- A soft pastel orange visual style across the product.
- Connection and credential management for social-media creator services that make audience
  reaction data available through their services.
- Clear connection, permission, expired-access, unavailable-data, and recovery states.
- A page-creation chat with an opening message, suggested visualization ideas, and natural-language
  follow-up questions.
- Page creation that uses real connected tools and the organization's current Memory summary.
- A new side-menu destination for each successfully created page.
- Persistent page conversation, purpose, behavior summary, and return visits.
- A persistent Memory conversation and current summary covering tools, accounts, data sources,
  meanings across tools, business meaning, and ways to find or access data.
- Privacy and recovery behavior that keeps credentials out of ordinary chat and summaries.

## Out of scope

- Claiming support for a service or measure that the service does not make available.
- Publishing posts or changing content on connected social-media accounts.
- Displaying invented data when a connection, permission, or requested measure is unavailable.
- Storing passwords, access tokens, or other credentials in page-creation or Memory conversations.
- Defining company roles, billing, external customer access, or a public dashboard in the first
  requirements draft.
- Automatically changing an existing page in a way that removes its original purpose without user
  confirmation.

## Product constraints

- A created page must use real connected data when it claims to show live company information.
- The product must state when data is missing, delayed, unavailable, or no longer authorized.
- Credentials must be handled through the connected-tools experience. They must not appear in
  ordinary conversation, saved summaries, page content, or evidence shown to the user.
- The original page-creation conversation and the original Memory conversation must persist until
  the user uses an agreed removal action. The exact retention and removal rules need confirmation.
- A current summary may change as the user clarifies the organization. It must not silently rewrite
  the preserved original conversation.
- Page building must use the latest accepted Memory summary and must ask when that summary does not
  resolve an important ambiguity.
- Functional browser tests must cover the agreed positive, negative, interruption, privacy,
  persistence, and recovery flows before subjective user testing.

## User journeys

### Connect company tools

The user opens Connected Tools from the side menu, chooses a supported creator service, authorizes
an account, and sees what account and reaction information is available. If access fails or a
permission is missing, the user sees the cause, no false data appears, and the user can reconnect or
choose another account.

### Teach the dashboard about the organization

The user opens Memory and explains the organization's tools in natural language. For a broad request
such as “track Instagram,” the conversation asks which accounts, metrics, audiences, reactions,
business meanings, and access paths matter. The user reviews the updated summary and can return to
correct it later. Sensitive credential text is not retained in the normal conversation or summary.

### Ask for a dashboard page

The user selects the plus button. The page explains that visualizing company data can improve
company-wide visibility and offers useful page ideas. The user describes a need or chooses a
suggestion. The page-building agent uses connected tools and current Memory, asks only for unresolved
meaning, and shows progress without pretending that an unavailable connection works.

### Use and revisit a created page

After successful creation, the page appears in the side menu with an icon or tab. The user opens it,
sees the requested information and its data state, and can read the original conversation plus a
summary of why the page exists and how it works. On a later visit, the page and its context remain
available and show current connected data or a clear unavailable state.

## Success measures

- A user can connect a supported creator account and can see which reaction information is
  available without exposing its credentials.
- A user can add a page from a suggestion or a natural-language request and can reach it from the
  side menu after creation.
- Every generated page explains its purpose and current data state and retains its original request
  conversation.
- The Memory page retains its original conversation and a current user-reviewable summary.
- When a user returns, saved pages and Memory remain available and use the latest accepted
  organization meaning.
- Browser tests prove the specified successful and recovery journeys. Human testing judges whether
  the navigation, prompts, progress, and explanations feel clear and low effort.
- Quantitative targets for creation time, refresh delay, reliability, and user effort remain open.

## Open product decisions

- Which company roles use the first release, and which content can each role see or change?
- Which social-media platforms and creator account types must be present in the first release?
- Which reaction measures are required for each platform?
- What do “retention” and “real time” mean for the first suggested visualization?
- When must the user approve page-building access, publication, replacement, or major revision?
- How should the product choose and let the user change a new page icon?
- What are the required data refresh times and the expected behavior when the user is offline?
- How long are conversations, summaries, pages, and connection records retained, and how does the
  user remove them?
- Is Memory shared across the organization, limited to a team, or private to one user?
- Who can approve changes to organization meanings, and does Memory need version review or rollback?
- Should each generated page show which Memory statements guided its creation?
- What quantitative thresholds define a successful first release?
