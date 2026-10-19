# CTModels.jl

```@meta
CurrentModule = CTModels
```

`CTModels.jl` is the **model layer** of the [control-toolbox](https://github.com/control-toolbox)
ecosystem. It defines how an optimal control problem (OCP), its numerical solution and an
initial guess are represented, and nothing else: it neither parses, discretises nor solves.

!!! info "Who this documentation is for"

    This site documents CTModels for **developers** of the control-toolbox packages and for
    **experienced users** who work with the model objects directly. To model and solve
    optimal control problems, start with
    [OptimalControl.jl](https://control-toolbox.org/OptimalControl.jl), which wraps
    CTModels behind the `@def` DSL and `solve`.

## Place in the ecosystem

```text
   CTParser ── @def ──► PreModel ── build ──► Model ◄──────────────────┐
                        (CTModels.Building)   (CTModels.Models)        │
                                                │                      │
                         CTDirect (direct) ─────┤                      │
                         CTFlows (indirect) ────┤                      │
                                                ▼                      │
                    solver output ── build_solution ──► Solution ──────┘
                                    (CTModels.Solutions)  │
                                                          ├─► Init (warm start)
                                                          ├─► Serialization (JSON, JLD2)
                                                          └─► PlotCase ─► Plots / Makie
```

- [CTParser.jl](https://github.com/control-toolbox/CTParser.jl) turns the `@def` DSL into
  calls to the `Building` verbs (`state!`, `dynamics!`, `constraint!`, …) and `build`.
- [CTDirect.jl](https://github.com/control-toolbox/CTDirect.jl) discretises a `Model` into
  an NLP and turns the NLP solution back into a `Solution` with `build_solution`.
- [CTFlows.jl](https://github.com/control-toolbox/CTFlows.jl) builds Hamiltonian flows from
  a `Model` and returns `Solution` objects as well.
- [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl) provides the resolution
  infrastructure (NLP solvers, modelers, ODE integrators) used by CTDirect and CTFlows.
- [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl) re-exports a
  selection of CTModels symbols for end users.

## Modules

| Module | Responsibility |
| --- | --- |
| `CTModels.Components` | Component types (state, control, variable, times, objective, constraints) and their accessors |
| `CTModels.Models` | The immutable `Model` and its accessors |
| `CTModels.Building` | The mutable `PreModel`, the declaration verbs (`state!`, `dynamics!`, …) and `build` |
| `CTModels.Solutions` | `Solution`, `build_solution`, time grids, dual model, solver infos |
| `CTModels.Init` | Initial guesses: input formats, validation, warm start |
| `CTModels.Display` | `Base.show` for models, pre-models, components and solutions |
| `CTModels.Serialization` | `export_ocp_solution` / `import_ocp_solution` (implemented by extensions) |
| `CTModels.PlotCase` | Backend-free description of the solution figure (rendered by the plotting extensions) |

| Extension | Trigger package | Adds |
| --- | --- | --- |
| `CTModelsJSON` | `JSON` | JSON export and import of a `Solution` |
| `CTModelsJLD` | `JLD2` | JLD2 export and import of a `Solution` |
| `CTModelsPlots` | `Plots` | `Plots.plot(sol)` / `Plots.plot!(sol)` |
| `CTModelsMakie` | `Makie` (via `CairoMakie`, `GLMakie`, …) | `Makie.plot(sol)` / `Makie.plot!(fig, sol)` |

## Conventions

!!! note "Qualified access"

    CTModels exports no symbol at the package level. Each submodule exports its public API
    and the package brings the submodules in, so every public symbol is reached as
    `CTModels.symbol`, for example `CTModels.state!` or `CTModels.build_solution`; this is the
    form used throughout this documentation. The fully qualified form
    `CTModels.Building.state!` refers to the same function.

- **One-dimensional is scalar.** A one-dimensional state, control or variable is a
  `Number`, never a length-1 vector: user functions receive `u`, not `u[1]`, and solution
  and initial-guess trajectories return scalars.
- **In-place functions.** Dynamics and nonlinear constraints are written in place,
  `f!(r, t, x, u, v)` and `b!(r, x0, xf, v)`, with the full argument list even for an
  autonomous problem.
- **Structured errors.** Invalid inputs raise the typed exceptions of
  `CTBase.Exceptions` (`IncorrectArgument`, `PreconditionError`, `ExtensionError`, …), with
  a message, the received and expected values, and a hint.

## How this documentation is organised

- [Getting started](getting-started.md): a model, a solution and an initial guess in five
  minutes.
- **OCP model**: the `PreModel → build → Model` pipeline, the type and trait
  architecture, each declaration verb, and the display of models.
- **Solutions**: the anatomy of a `Solution`, the [`build_solution` contract](solution/build_solution.md)
  for solver authors, time grids, trajectories, duals and diagnostics.
- **Initial guesses**: input formats, validation and warm start.
- **Extensions**: export and import, plotting with Plots and Makie, and the
  [plotting architecture](serialization/plotcase.md).
- [Performance](guide/performance.md): the hot path / setup path rule and how type
  stability is checked.
- **API Reference**: one page of public symbols per submodule, and one page of internals
  (private symbols and extensions).

!!! tip "Ask DeepWiki"
    [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/control-toolbox/CTModels.jl) offers an interactive, AI-generated overview of this codebase. Answers may be inaccurate: this documentation is the reference.
