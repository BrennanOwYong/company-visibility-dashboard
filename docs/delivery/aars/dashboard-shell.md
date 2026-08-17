# Builder AAR draft — dashboard-shell

The AAR is an advisory optimization record. It does not block mandatory testing.

## Repeated module-specific steps

The repeatable shell verification sequence is: run `npm run typecheck`, `npm run lint`,
`npm run test:unit`, then `bin/project-test`; start the server with a dedicated loopback `PORT`,
request `/health` and `/api/v1/navigation`, and inspect the JSON lines for correlation fields and
safe attributes.

## Skill candidates

This sequence is a candidate for a local `web-experience` verification script. It was repeated
during implementation and self-test, but no separate skill was created because the project test
contract already owns the whole-project command.

## Module trip-ups

The shell must render fixed destinations from the client fixture before the navigation request
completes. A navigation failure must not replace those entries. Browser telemetry must use an
allowlist before it reaches the structured log sink.
