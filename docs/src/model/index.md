# Optimal control problems

```@meta
CurrentModule = CTModels
```

The [`CTModels.OCP`](@ref CTModels.OCP) submodule is the heart of CTModels: it defines and
builds **optimal control problems** (OCPs). An OCP is assembled incrementally into a mutable
[`PreModel`](@ref CTModels.OCP.PreModel), then frozen into an immutable
[`Model`](@ref CTModels.OCP.Model) by [`build`](@ref CTModels.OCP.build).

CTModels builds a model through a **three-stage pipeline**:

```
PreModel  →  declare components  →  build  →  Model
(mutable)    state!/control!/...           (immutable)
```

The `OCP` submodule is organised by responsibility, each in its own subdirectory:

| Layer | Subdirectory | What it provides |
|---|---|---|
| **Types** | `OCP/Types/` | Component, model and solution types ([`StateModel`](@ref CTModels.OCP.StateModel), [`Model`](@ref CTModels.OCP.Model), …) |
| **Core** | `OCP/Core/` | Defaults and the [`TimeDependence`](@ref CTModels.OCP.TimeDependence) trait |
| **Validation** | `OCP/Validation/` | Name-uniqueness checks across components |
| **Components** | `OCP/Components/` | The `state!`, `control!`, `dynamics!`, … declaration verbs |
| **Building** | `OCP/Building/` | [`build`](@ref CTModels.OCP.build) (model) and [`build_solution`](@ref CTModels.OCP.build_solution) |

## Reading order

| Page | Topic | Key symbols |
|---|---|---|
| [Types and traits](types_and_traits.md) | The noun/trait architecture | [`TimeDependence`](@ref CTModels.OCP.TimeDependence), `AbstractStateModel`, `Empty*` |
| [Components](components.md) | Declaring the spaces | [`state!`](@ref CTModels.OCP.state!), [`control!`](@ref CTModels.OCP.control!), [`variable!`](@ref CTModels.OCP.variable!), [`time!`](@ref CTModels.OCP.time!) |
| [Dynamics and objective](dynamics_objective.md) | The equations of motion and cost | [`dynamics!`](@ref CTModels.OCP.dynamics!), [`objective!`](@ref CTModels.OCP.objective!) |
| [Constraints](constraints.md) | Path, boundary and box constraints | [`constraint!`](@ref CTModels.OCP.constraint!) |
| [Building a model](building.md) | Freezing the `PreModel` | [`build`](@ref CTModels.OCP.build), [`Model`](@ref CTModels.OCP.Model) |

## Qualified access

CTModels exports nothing at the package level: every public symbol is reached through a
qualified path `CTModels.symbol`. Bring the package into scope and call its verbs qualified:

```@example model_index
using CTModels
nothing # hide
```

## Minimal end-to-end example

We build the *beam* problem: minimise ``\int_0^1 u(t)^2\,\mathrm{d}t`` subject to
``\dot{x} = (x_2, u)``, fixed boundary conditions, and box constraints on ``x_1`` and ``u``.

```@example model_index
# 1. A fresh, mutable pre-model
pre = CTModels.PreModel()

# 2. Declare the time interval, the spaces and (here) no optimisation variable
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)        # x ∈ ℝ²
CTModels.control!(pre, 1)      # u ∈ ℝ

# 3. Dynamics ẋ = (x₂, u), written in place
function beam_dynamics!(r, t, x, u, v)
    r[1] = x[2]
    r[2] = u[1]
    return nothing
end
CTModels.dynamics!(pre, beam_dynamics!)

# 4. Lagrange cost ∫ u² → min
beam_lagrange(t, x, u, v) = u[1]^2
CTModels.objective!(pre, :min; lagrange=beam_lagrange)

# 5. Boundary and box constraints
function beam_boundary!(r, x0, xf, v)
    r[1] = x0[1]      # x₁(0) = 0
    r[2] = x0[2] - 1  # x₂(0) = 1
    r[3] = xf[1]      # x₁(1) = 0
    r[4] = xf[2] + 1  # x₂(1) = -1
    return nothing
end
CTModels.constraint!(pre, :boundary; f=beam_boundary!, lb=zeros(4), ub=zeros(4), label=:bc)
CTModels.constraint!(pre, :state;   rg=1:1, lb=[0.0],   ub=[0.1],  label=:x1_box)
CTModels.constraint!(pre, :control; rg=1:1, lb=[-10.0], ub=[10.0], label=:u_box)

# 6. Mark the system autonomous and freeze it into an immutable Model
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
```

Once built, the `Model` answers queries through accessors:

```@example model_index
(CTModels.state_dimension(ocp),
 CTModels.control_dimension(ocp),
 CTModels.variable_dimension(ocp),
 CTModels.is_autonomous(ocp))
```

The shortcut `CTModels.build_model(pre)` is an alias for `CTModels.build(pre)`; see
[Building a model](building.md) for what `build` checks and guarantees.

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
  ([`Autonomous`](@ref CTModels.OCP.Autonomous) vs
  [`NonAutonomous`](@ref CTModels.OCP.NonAutonomous)).
- **Time structure** — whether ``t_0`` / ``t_f`` are fixed or free
  ([`FixedTimeModel`](@ref CTModels.OCP.FixedTimeModel) vs
  [`FreeTimeModel`](@ref CTModels.OCP.FreeTimeModel)).

How these axes become *traits* rather than separate types is the subject of
[Types and traits](types_and_traits.md).
```
