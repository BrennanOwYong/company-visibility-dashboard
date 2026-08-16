# Current Product Principles

Product principles are optional, cross-feature truths inferred by the Product Manager from repeated user intent. Do not invent principles merely to fill this file.

For each principle, record:

- The repeated user need it expresses.
- Which active features it governs.
- What must remain consistent across those features.
- Positive examples and unacceptable counterexamples in user language.
- How the user will recognize that the product honors it.

Builders may reference this file but must never edit it.

## Confirmation status

No cross-feature product principle is confirmed yet. The following candidates come directly from
repeated user requirements. The Product Manager must offer them to the user for confirmation before
a planner or builder treats them as governing rules.

## Candidate: Show connected company truth

- **Repeated user need:** The user wants company-wide visibility from actual connected tools, not a
  visual mock-up that looks complete.
- **Candidate feature coverage:** `connected-social-tools`, `page-builder-chat`,
  `generated-dashboard-pages`, and `company-memory`.
- **Proposed consistent behavior:** Show the source and current availability of company information.
  State when information is missing, delayed, unclear, or no longer authorized.
- **Positive example:** A page shows the available Instagram reactions and states when they were
  updated.
- **Unacceptable example:** A page fills an unavailable measure with invented or unlabeled sample
  data.
- **How the user could recognize it:** The user can tell what information is real, where it came
  from, and whether it is current.

## Candidate: Remember meaning so the user does not repeat work

- **Repeated user need:** Created pages, original conversations, purpose summaries, and organization
  knowledge must persist and guide later work.
- **Candidate feature coverage:** `company-memory`, `page-builder-chat`, and
  `generated-dashboard-pages`.
- **Proposed consistent behavior:** Reuse the latest accepted organization meaning, preserve original
  conversations, and ask only about unresolved meaning.
- **Positive example:** After the user defines which Instagram account and audience matter, a later
  page request uses that meaning and asks only about the new measure.
- **Unacceptable example:** Every page request asks the user to rediscover the same account, source,
  and business meaning.
- **How the user could recognize it:** Later work starts with the right context and requires less
  explanation and exploration.

## Candidate: Keep credentials separate from ordinary work

- **Repeated user need:** The dashboard must connect to real tools, while Memory and page
  conversations also persist.
- **Candidate feature coverage:** `connected-social-tools`, `company-memory`,
  `page-builder-chat`, and `generated-dashboard-pages`.
- **Proposed consistent behavior:** Collect credentials only in the connection experience. Do not
  repeat them in chats, summaries, generated pages, or visible evidence.
- **Positive example:** Memory refers to the connected creator account by its safe display name.
- **Unacceptable example:** A saved Memory summary contains an access token pasted by the user.
- **How the user could recognize it:** The product can use connected services without exposing secret
  values in its normal pages and conversations.
