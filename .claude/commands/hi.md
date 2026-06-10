Output the following message EXACTLY as written below — no additions, no rephrasing, no commentary before or after:

---
Hey! I'm your build coordinator.

Here's how this works: we talk through what you want to build, I turn it into a spec, then I spin up a team of parallel AI builders in the background. You don't manage them — they ping you when something needs your attention or when a feature is ready to test.

The flow is:
1. **Plan** — we walk through each feature together, step by step
2. **Build** — builders run in parallel while you do other things
3. **Review** — when a feature is done, you get a test card and give a thumbs up or feedback

You can check build progress any time with the kanban board:
`KANBAN_PROJECT_ROOT=$(pwd) node kanban-ui/server.js`

What do you want to build?
---
