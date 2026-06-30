# Code-index tooling research: graphify + opensrc (2026-06-21)

Researched at the owner's request. Both are directly relevant to the **Deep Review (brownfield)**
phase (which needs a live code index) and to builder/planner context.

## graphify — `safishamsi/graphify` — the code-index candidate
Turns a repo (code, SQL schemas, docs, PDFs, images, video) into a queryable knowledge graph.
- **Pipeline:** tree-sitter AST extraction (36 grammars, LOCAL, no API calls) → LLM semantic
  extraction for prose/diagrams → entity linking with confidence tags (EXTRACTED / INFERRED /
  AMBIGUOUS) → Leiden community detection + god-node ranking → `graph.json` + interactive
  `graph.html` + `GRAPH_REPORT.md`.
- **Query surface:** CLI (`graphify query "..."`, `path A B`, `explain X`) AND an **MCP server**
  with `query_graph, get_node, get_neighbors, shortest_path, list_prs, get_pr_impact, triage_prs`.
- ~71x token compression vs reading raw files. Exports GraphML, Cypher (Neo4j/FalkorDB),
  Mermaid call-flow, Obsidian. Installs as a per-platform skill. Python 3.10+.

**Maps to Deep Review almost 1:1.** The Notion spec wants "a symbol-and-dependency graph from
tree-sitter / LSP / code-graph, regenerated incrementally per commit, queried deterministically."
graphify is that, plus an MCP interface. `get_neighbors` / `shortest_path` verify assumptions
(does X exist, does X depend on Y); `get_pr_impact` is exactly the "propagate the change along the
dependency graph to dependent tasks" need; `--update` is the incremental per-commit regen.

**Caveat:** the LLM/semantic + clustering layer is non-deterministic. For Deep Review, keep the
deterministic checks (symbol exists, signature, dependency edge) on the tree-sitter/graph layer
and reserve the LLM layer for what determinism cannot settle — matches the wisdom's two-layer rule.

## opensrc — `vercel-labs/opensrc` — dependency source for agents
Rust CLI that fetches + caches the real SOURCE of packages (npm, PyPI, crates.io, GitHub) so agents
read implementations, not just types/docs. `opensrc path zod` returns a cached path; then
`rg "parse" $(opensrc path zod)`. Registry syntax e.g. `opensrc path pypi:requests`. Ships an agent
skill at `skills/opensrc`. First run fetches+caches; later calls are instant.

**Maps to** the planner/builder "reuse what exists, don't reinvent" and "don't hallucinate library
APIs" needs. When a ticket consumes an external module, the builder reads its real source.
Complements graphify: graphify maps OUR repo; opensrc fetches THIRD-PARTY source.

## How they fit the factory
- Deep Review code index → graphify (`graph.json` + MCP server), `--update` per commit.
- Builder/planner dependency understanding → opensrc.
- Both install as skills, which fits our `skills/` + `.claude/` model.

## Open question for the owner
Adopt graphify as the Deep Review index backend, or build a lighter tree-sitter symbol graph
ourselves? graphify is heavier (LLM layer + clustering) than the minimal deterministic symbol
graph Deep Review strictly needs, but it is ready-made and ships the MCP query surface. opensrc is
lower-risk to adopt as-is for dependency reading.

## Sources
- https://github.com/safishamsi/graphify  ·  https://graphify.net/
- https://github.com/vercel-labs/opensrc  ·  https://opensrc.sh/
