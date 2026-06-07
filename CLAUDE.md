# CTModels.jl — Claude project context

## Essential rules

1. **Never commit or push without explicit approval.** Ask first, every time.
2. **Run tests via the `ct-dev-mcp` MCP** — `get_test_command` → run with `tee` →
   `generate_report`. Never invent the test command.
3. **Build docs draft-first** — `draft = true` globally to validate links, then per file
   with `Draft = false`, then full build. See `dev/RULES.md`.
4. **Qualify everything** — `Module.symbol` at every call site; `import Pkg: Pkg` not
   `using Pkg`; no top-level package exports.
5. **Write a plan before coding** — any task touching more than one file or a public
   interface needs a plan confirmed by the user first. Template in `dev/planning.md`.
6. **Docstrings last** — written only after the API is stable.
7. **Fake types at module top-level** — never inside test functions (world-age issues).

## Where to find more

| Topic | File |
| --- | --- |
| Code philosophy (modules, types/traits, exceptions, docstrings, testing, docs) | [`dev/philosophy/`](dev/philosophy/PHILOSOPHY.md) |
| Operational rules (MCP, doc build, git, output capture) | [`dev/RULES.md`](dev/RULES.md) |
| Plan template | [`dev/planning.md`](dev/planning.md) |
| Active refactor roadmap | [`reports/dev/action_plan.md`](reports/dev/action_plan.md) |
| Architecture reflections | [`reports/dev/`](reports/dev/README.md) |

## Project structure (quick reference)

```text
src/CTModels.jl         # top-level manifest — exports nothing
src/<Module>/<Module>.jl  # submodule manifests
ext/                    # weak-dependency extensions (JLD2, JSON, Plots)
test/suite/             # tests by functionality, not by src layout
docs/                   # Documenter.jl site
dev/                    # philosophy, rules, planning template (versioned)
reports/                # working notes, ephemeral (gitignored in production)
```

## Key architecture point

CTModels focuses on the mathematical model layer for optimal control problems. It provides types and building blocks for states, controls, variables, time grids, and constraints; structures for representing numerical solutions; initial-guess management; and optional extensions for serialization and plotting.
