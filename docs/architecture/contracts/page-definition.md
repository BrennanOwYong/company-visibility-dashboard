# Page Definition Contract

## Purpose

A page definition is the only publishable output of the page-building agent. The trusted runtime
interprets it. The agent cannot insert arbitrary script, network address, SQL, credential reference,
or provider request.

## Required structure

A versioned definition contains:

- `schema_version`, stable `page_id`, title, approved `icon_key`, purpose, and plain-language
  how-it-works summary.
- The pinned page request ID, accepted Memory summary version ID, and capability manifest versions.
- A bounded ordered list of sections and widgets.
- For each widget: approved visualization key, accessible title and description, canonical metric
  requests, safe filters, bounded time window, approved transformations, empty state, unavailable
  state, and source-label policy.
- Layout values from approved responsive layout tokens.

## Approved behavior

The first component registry can contain metric card, time series, grouped comparison, table, text
explanation, and source-status panel. A component is not available until it has schema validation,
accessibility behavior, browser tests, size limits, and safe rendering tests.

Approved transformations are named, bounded functions over normalized observations, such as sum,
count, change, ratio, moving average, and provider-by-provider grouping. A transformation definition
states its valid units and empty/zero behavior. The agent cannot supply expression text.

## Deterministic validation

Publication requires all checks to pass:

1. Schema version and size limits.
2. Workspace and pinned-version ownership.
3. Approved component, transformation, icon, and layout keys.
4. Every metric request exists in its pinned capability manifest.
5. Unit compatibility and bounded time ranges.
6. Accessible name, description, keyboard order, and non-color status signal.
7. No script, markup injection, network address, SQL, file path, prompt directive, or secret-like
   value.
8. Deterministic render with success, empty, partial, delayed, and unavailable fixtures.
9. Purpose and how-it-works summary match the confirmed request fields.

The validator returns a versioned report with stable rule IDs and safe locations. A failed report is
build evidence; it cannot be published.

## Version behavior

Definitions are immutable. A schema reader supports all active published schema versions. A change
creates a new candidate and validation report. Publication atomically changes the current version.
Rollback changes the current pointer to a prior validated version; it never mutates a definition.

