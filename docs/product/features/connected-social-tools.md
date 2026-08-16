# Feature: connected-social-tools

Parent PRD: `docs/product/PRD.md#connect-company-tools`

## Purpose

Connect the dashboard to the social-media creator accounts that hold the company's audience and
reaction information.

## User outcome

The user can authorize real accounts, understand what information each connection makes available,
and recover when access or permission is not valid.

## Scope and non-goals

This feature includes a Connected Tools page, supported creator-service choices, safe account
authorization, connection status, available reaction information, reconnection, and removal. The
intended coverage is every social-media creator service whose available service lets this product
read audience reactions. The first release list still needs confirmation.

This feature does not publish or change social-media content. It does not promise information that a
service or account type does not make available. It does not put secret credential values into
ordinary product pages, conversations, summaries, or logs shown to the user.

## Positive flow

1. The user selects Connected Tools from the side menu. The user sees supported social-media creator
   services and the status of accounts that are already connected.
2. The user chooses a supported service. The user sees what account access and reaction information
   the dashboard will request.
3. The user authorizes the correct creator account through the service's trusted authorization
   experience. The dashboard does not ask the user to paste a secret into an ordinary chat.
4. The user returns to Connected Tools. The user sees the safe account identity, connection status,
   available reaction information, and any limits that affect it.
5. The user opens a page that uses the account. The page uses the authorized information and names
   its current data state.

## Negative and recovery flow

1. The user cancels or denies authorization. No account is marked connected, no partial credential
   is shown, and the user can try again or leave safely.
2. The selected account lacks a required permission. The user sees which capability is unavailable,
   the product does not show invented reactions, and the user can grant access or choose another
   account.
3. A service has no supported reaction information for that account type. The product states the
   limitation before the user depends on it and does not claim that the requested measure is live.
4. A connection expires or is revoked. Affected pages state that access is unavailable, unrelated
   pages continue to work, and the user can reconnect.
5. The service is temporarily unavailable. The user sees a temporary problem and a retry action.
   Existing saved pages and account meaning are not deleted.
6. A user attempts to paste a secret into a normal product conversation. The product warns the user,
   does not include the secret in an ordinary saved summary, and directs the user to the connection
   experience.
7. The user removes a connection. The user sees which pages can be affected and must confirm before
   removal. Later affected pages show an unavailable state rather than false current data.

## User inputs and visible outcomes

- Choosing a service shows the requested access and the information the service can provide.
- Authorizing an account shows a safe account name and connection state, not secret values.
- Granting or refusing permissions changes only the capabilities that are actually available.
- Reconnecting restores access when authorization succeeds.
- Removing a connection changes dependent pages to a clear unavailable state.

## Done outcomes

- **DC-01:** Given a supported creator service, when the user authorizes a valid account, then the
  safe account identity and connected state appear without exposing credential values.
- **DC-02:** Given a connected account, when the user reviews it, then the product states which
  reaction information is available and any relevant access limit.
- **DC-03:** Given authorization is denied or canceled, when the user returns, then no false
  connection exists and the user can try again.
- **DC-04:** Given a permission or account capability is missing, when information is requested, then
  the limitation is visible and the product does not invent data.
- **DC-05:** Given access expires or is revoked, when an affected page opens, then it shows an
  unavailable state and a route to reconnect.
- **DC-06:** Given a temporary service interruption, when access fails, then the user can retry and
  saved connection context is not silently deleted.
- **DC-07:** Given secret text enters an ordinary conversation, when the product handles it, then the
  secret is excluded from ordinary visible summaries and the user receives safe recovery guidance.
- **DC-08:** Given the user chooses to remove a connection, when they review the impact and confirm,
  then the account is disconnected and affected pages clearly stop claiming current data.

## Subjective user-test questions

- Does the authorization request explain the benefit and requested access clearly?
- Can the user tell which account is connected without seeing unsafe information?
- Do permission and expired-access messages help the user recover with confidence?
- Does removal communicate its effect without creating unnecessary fear?

## Applicable principles

(none confirmed; candidate principles await user confirmation)

## Open questions

- Which services and creator account types are mandatory for the first release?
- Which audience reaction measures are mandatory for each service?
- Who can connect, reconnect, or remove a company account?
- What credential retention, removal, and audit rules must apply?
- How current must each service's data be?

