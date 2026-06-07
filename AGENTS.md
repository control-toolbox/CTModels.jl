# CTModels.jl — Agent Navigation Guide

Quick-reference for any agent working on this repository.

---

## Project Overview

**CTModels.jl** is a Julia package in the [control-toolbox](https://github.com/control-toolbox) ecosystem.
It provides the **mathematical model layer** for optimal control problems: types and building blocks for states, controls, variables, time grids, and constraints; structures for representing numerical solutions; initial-guess management; and optional extensions for serialization and plotting.

---

## Source Architecture

Submodule layout (all public symbols accessed via qualified paths — no top-level exports):

```
src/
├── CTModels.jl         # Top-level manifest — exports nothing
├── Display/            # Base.show extensions for models and solutions
├── Init/               # Initial guess construction and validation
├── OCP/                # Optimal Control Problem types and builders
│   ├── Components/     # state, control, dynamics, objective, constraints
│   ├── Building/       # model and solution construction
│   ├── Types/          # abstract types and concrete implementations
│   └── Validation/     # name validation and other checks
├── Serialization/      # export/import functionality (JLD2, JSON)
└── Utils/              # interpolation, matrix utilities, @ensure macro

ext/
├── CTModelsJLD.jl      # JLD2 serialization extension
├── CTModelsJSON.jl     # JSON serialization extension
├── CTModelsPlots.jl    # Plotting extension (Plots.jl)
├── plot.jl             # Plot recipes and implementations
├── plot_default.jl     # Default plotting configurations
└── plot_utils.jl       # Plotting utilities

test/suite/             # Tests organised by functionality (not by src layout)
docs/                   # Documenter.jl site (auto-generated API via CTBase)
dev/                    # Code philosophy, operational rules, plan template (versioned)
reports/                # Working notes and architectural reports (ephemeral)
```

---

## Developer resources

| File | Purpose |
|---|---|
| [`dev/philosophy/PHILOSOPHY.md`](dev/philosophy/PHILOSOPHY.md) | Code philosophy — modules, types/traits, exceptions, docstrings, testing, docs |
| [`dev/RULES.md`](dev/RULES.md) | Operational rules — running tests (MCP), building docs, git, output capture |
| [`dev/planning.md`](dev/planning.md) | Plan template — phases, steps, human checkpoints |
| [`reports/dev/action_plan.md`](reports/dev/action_plan.md) | Active development roadmap (if any) |

---

## Devin Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `architecture.md` | — | Introducing new types, restructuring modules, reviewing SOLID/patterns |
| `docstrings.md` | — | Writing or reviewing Julia docstrings |
| `documentation.md` | `glob: docs/**/*` | Documenter.jl layout, `make.jl` template, `api_reference.jl`, `InterLinks` setup |
| `exceptions.md` | — | Adding error paths, contract stubs, argument validation |
| `modules.md` | `glob: src/**/*.jl, ext/**/*.jl` | Submodule conventions: qualified imports, manifest pattern, export policy, DAG ordering |
| `performance.md` | — | Hot paths, inner loops, profiling, benchmarking |
| `plan.md` | — | Writing an implementation plan before coding |
| `testing-creation.md` | — | Writing or reviewing test files under `test/suite/` |
| `testing-execution.md` | `model_decision` | How to run tests (commands, `tee` capture) |
| `type-stability.md` | — | New structs, parametric types, `@inferred` test design |

Workflows live in `.devin/workflows/`.

---

## Key Conventions

- **No top-level exports** — use `CTModels.Submodule.symbol` everywhere.
- **Qualified imports** — `using PackageName: PackageName`, never bare `using`.
- **Fake types at module top-level** — never inside test functions.
- **Plans before code** — write a plan and confirm with the user before touching files. Template: [`dev/planning.md`](dev/planning.md).
- **Docstrings last** — written only after all implementation steps are stable.
- **Never commit or push without explicit user approval.**
