# Optimal control problems

```@meta
CurrentModule = CTModels
```

CTModels defines and builds **optimal control problems** (OCPs) through four focused modules:
`CTModels.Components`, `CTModels.Models`, `CTModels.Building`, and `CTModels.Solutions`.
An OCP is assembled incrementally into a mutable
[`PreModel`](@ref CTModels.Building.PreModel), then frozen into an immutable
[`Model`](@ref CTModels.Models.Model) by [`build`](@ref CTModels.Building.build).

The model is built through a **three-stage pipeline**:

```text
PreModel  →  declare components  →  build  →  Model
(mutable)    state!/control!/...           (immutable)
```

The OCP layer is organised by responsibility across four modules:

| Module | Directory | What it provides |
|---|---|---|
| `CTModels.Components` | `src/Components/` | Component types ([`StateModel`](@ref CTModels.Components.StateModel), `TimeDependence`, …) and their accessors |
| `CTModels.Models` | `src/Models/` | Immutable [`Model`](@ref CTModels.Models.Model) type and all model accessor methods |
| `CTModels.Building` | `src/Building/` | [`PreModel`](@ref CTModels.Building.PreModel), declaration verbs (`state!`, `control!`, …), name validation, [`build`](@ref CTModels.Building.build) |
| `CTModels.Solutions` | `src/Solutions/` | [`build_solution`](@ref CTModels.Solutions.build_solution), solution types, dual model, interpolation |

## Reading order

| Page | Topic | Key symbols |
|---|---|---|
| [Types and traits](types_and_traits.md) | The noun/trait architecture | `TimeDependence`, `AbstractStateModel`, `Empty*` |
| [Components](components.md) | Declaring the spaces | [`state!`](@ref CTModels.Building.state!), [`control!`](@ref CTModels.Building.control!), [`variable!`](@ref CTModels.Building.variable!), [`time!`](@ref CTModels.Building.time!) |
| [Dynamics and objective](dynamics_objective.md) | The equations of motion and cost | [`dynamics!`](@ref CTModels.Building.dynamics!), [`objective!`](@ref CTModels.Building.objective!) |
| [Constraints](constraints.md) | Path, boundary and box constraints | [`constraint!`](@ref CTModels.Building.constraint!) |
| [Building a model](building.md) | Freezing the `PreModel` | [`build`](@ref CTModels.Building.build), [`Model`](@ref CTModels.Models.Model) |
| [Displaying models](display.md) | `Base.show` and mathematical rendering | `Model`, `PreModel` display |

## The pipeline on an example

[Getting started](../getting-started.md) builds the complete *beam* problem through this
pipeline: declaration of the spaces, in-place dynamics, Lagrange cost, boundary and box
constraints, then `build`. The pages listed above take each step in turn. `build_model` is an
alias of `build`; see [Building a model](building.md) for what `build` checks and
guarantees.

## Mathematical setting

CTModels represents a continuous-time OCP in **Bolza form**. With state
``x : [t_0, t_f] \to \mathbb{R}^n``, control ``u : [t_0, t_f] \to \mathbb{R}^m`` and an
optimisation variable ``v \in \mathbb{R}^q`` (free final time, design parameters, …):

```math
\begin{aligned}
\min_{x,\,u,\,v}\quad
& g\big(x(t_0), x(t_f), v\big) + \int_{t_0}^{t_f} f^0\big(t, x(t), u(t), v\big)\,\mathrm{d}t \\
\text{s.t.}\quad
& \dot{x}(t) = f\big(t, x(t), u(t), v\big), \\
& \text{path, boundary and box constraints.}
\end{aligned}
```

Two **orthogonal axes** shape the representation:

- **Time dependence** — whether ``f``, ``f^0`` depend explicitly on ``t``
  (`Autonomous` vs `NonAutonomous`).
- **Time structure** — whether ``t_0`` / ``t_f`` are fixed or free
  ([`FixedTimeModel`](@ref CTModels.Components.FixedTimeModel) vs
  [`FreeTimeModel`](@ref CTModels.Components.FreeTimeModel)).

How these axes become *traits* rather than separate types is the subject of
[Types and traits](types_and_traits.md).
