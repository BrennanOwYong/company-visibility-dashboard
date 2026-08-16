# Current Decisions

- Use one persistent application shell and route all fixed and generated pages through it.
- Use a fixed component registry to render validated page definitions.
- Use server-sent events for durable progress and state updates, with replay after reconnect.
- Keep navigation load independent of provider refresh.
- Use shared patterns for current, delayed, empty, partial, unavailable, and blocked states.

Exact design tokens, icon selection, and browser support remain open product decisions.

