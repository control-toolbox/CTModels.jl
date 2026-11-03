# The `build_solution` contract

```@meta
CurrentModule = CTModels
```

[`build_solution`](@ref CTModels.Solutions.build_solution) is the single entry point through
which a solver (CTDirect, CTFlows, or your own) hands its numerical output to CTModels. This
page states what it expects and what it checks; the other Solutions pages describe what
can be read back.

## Signatures

```julia
# one grid shared by every component
build_solution(ocp, T, X, U, v, P; objective, successful, kwargs...)

# one grid per component
build_solution(ocp, T_state, T_control, T_costate, T_path, X, U, v, P;
               objective, successful, kwargs...)
```

The first form calls the second with `T_state = T_control = T_costate = T_path = T`.
`objective::Float64` and `successful::Bool` are the only required keywords.

## Primal data

| Argument | Type | Shape |
| --- | --- | --- |
| `T`, `T_state`, `T_control`, `T_costate` | `Vector{Float64}` | increasing (a grid out of order is sorted, with a warning) |
| `T_path` | `Vector{Float64}` or `nothing` | `nothing` reuses the state grid for the path duals |
| `X` | `Matrix{Float64}` or `Function` | `length(T_state) × state_dimension(ocp)` |
| `U` | `Matrix{Float64}` or `Function` | `length(T_control) × control_dimension(ocp)` |
| `P` | `Matrix{Float64}` or `Function` | `length(T_costate) × state_dimension(ocp)` |
| `v` | `Vector{Float64}` | `variable_dimension(ocp)`, `Float64[]` when there is no variable |

Matrices have **one row per time point and one column per component**. Inputs are always
vectors and matrices, also in dimension one; the [one-dimensional is scalar](../index.md#Conventions)
rule applies to what the solution returns:

```@example bs
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 1, "tf")
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 1)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)
CTModels.constraint!(pre, :path; f=(r, t, x, u, v) -> (r[1] = x + u; nothing),
    lb=[-1.0], ub=[1.0], label=:p)
CTModels.constraint!(pre, :boundary; f=(r, x0, xf, v) -> (r[1] = x0; nothing),
    lb=[0.0], ub=[0.0], label=:x0)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)

N = 11
T = collect(range(0.0, 1.0; length=N))
X = reshape(T, N, 1)                 # N × 1
U = ones(N, 1)                       # N × 1
P = zeros(N, 1)                      # N × 1
v = [1.0]                            # length 1

sol = CTModels.build_solution(ocp, T, X, U, v, P; objective=1.0, successful=true)
nothing # hide
```

```@repl bs
CTModels.state(sol)(0.5)
CTModels.control(sol)(0.5)
CTModels.variable(sol)
```

A `Function` `t -> x(t)` is accepted in place of a matrix for `X`, `U`, `P` and the path
duals. It is not sampled: a copy of it (`deepcopy`, so that later changes to captured
variables do not affect the solution) is stored and called directly, its result being
converted to a scalar in dimension one. The grids are still needed for display, plotting
and serialization.

## Time grids

- When all the provided grids are equal, the solution stores a single
  [`UnifiedTimeGridModel`](@ref CTModels.Solutions.UnifiedTimeGridModel); otherwise a
  [`MultipleTimeGridModel`](@ref CTModels.Solutions.MultipleTimeGridModel). See
  [Time grids](time_grids.md).
- A grid that is the longest grid without its last point (for instance a control grid
  `T[1:end-1]` from a direct method) is extended to the longest one, so that a unified grid
  can still be used; its data is not modified.
- State and costate are interpolated linearly. The control is piecewise constant by
  default; pass `control_interpolation=:linear` for a control computed from the state and
  costate, as in indirect methods. Control box duals follow the control interpolation.
- A grid holds each time once: a repeated time raises an `IncorrectArgument`. A grid that
  is not increasing is sorted, with a warning.

## Switching structure

A solution made of phases, typically from an indirect method, passes its structure with the
`switching` keyword: a [`SwitchingModel`](@ref CTModels.Solutions.SwitchingModel) with the
switching times, the phase labels and the left/right limits of the state, costate and
control (default: an [`EmptySwitchingModel`](@ref CTModels.Solutions.EmptySwitchingModel)).
The switching times must lie strictly inside the time span, and each matrix of limits must
have one row per switching time and one column per component, or no column when the limits
are not known. See [Switching structure](switching.md).

## Dual variables

All duals are optional. They are given **by label**, in the `duals` keyword; the duals of
the **boxes** can also be given by component, in their own keywords (the native form of the
bound multipliers of an NLP solver).

| Keyword | Type | Shape |
| --- | --- | --- |
| `duals` | `AbstractDict{Symbol}` | `label => value`, for every kind of label (below) |
| `state_constraints_lb_dual`, `state_constraints_ub_dual` | `Matrix{Float64}` or `Function` | `length(T_state) × state_dimension(ocp)`, or `t -> vector` |
| `control_constraints_lb_dual`, `control_constraints_ub_dual` | `Matrix{Float64}` or `Function` | `length(T_control) × control_dimension(ocp)`, or `t -> vector` |
| `variable_constraints_lb_dual`, `variable_constraints_ub_dual` | `Vector{Float64}` | `variable_dimension(ocp)` |

In `duals`, the value of a label depends on its kind and on its number of rows `n` (the
number of components of the constraint declared under that label):

| Label | Value |
| --- | --- |
| path | a `Function` `t -> value` (a scalar when `n = 1`), or a `Matrix` `length(T_path) × n` (a `Vector` when `n = 1`) |
| boundary | a `Number` when `n = 1`, a `Vector` of length `n` otherwise |
| state or control box | as a path label, on `T_state` or `T_control`: the **signed** dual |
| variable box | as a boundary label: the **signed** dual |

A box label takes the signed dual of the
[sign convention](duals.md#Sign-convention), the value
[`dual`](@ref CTModels.Solutions.dual) returns, and CTModels splits it back into the two
multipliers it stores per component:

| Component | lower-bound multiplier | upper-bound multiplier |
| --- | --- | --- |
| lower bound only | `d` | `0` |
| upper bound only | `0` | `d` |
| two bounds, or fixed | `max(-d, 0)` | `max(d, 0)` |

A component bounded by no label carries a known `0`, as with the box keywords. Several
labels on one component (aliases) share its multiplier: give it by one of them, the others
read the same dual; giving it by two labels is an `IncorrectArgument`. A kind of
dual is given one way: giving the duals of one kind both by label and by keyword (for
instance a state box label and `state_constraints_lb_dual`) is an `IncorrectArgument`;
different kinds may be given different ways.

A label **absent** from `duals` is **unknown**: [`dual`](@ref CTModels.Solutions.dual)
throws for it, and [`has_dual`](@ref CTModels.Solutions.has_dual) returns `false`. A label
given as `0` is a known `0`. The producer never needs the order of the rows: CTModels places
each label (see [How the duals are stored](duals.md#How-the-duals-are-stored)).

```@example bs
sol = CTModels.build_solution(ocp, T, X, U, v, P; objective=1.0, successful=true,
    duals=Dict(:p => t -> 2t))   # :x0 not given: unknown
nothing # hide
```

```@repl bs
CTModels.dual(sol, ocp, :p)(0.5)
CTModels.has_dual(sol, ocp, :x0)
```

!!! warning "Deprecated: `path_constraints_dual` and `boundary_constraints_dual`"

    The duals of the path and boundary constraints used to be given by position, in the
    stacked order of the constraints (`path_constraints_dual`, one column per row of
    `path_constraints_nl(ocp)`; `boundary_constraints_dual`, one entry per row of
    `boundary_constraints_nl(ocp)`). These keywords still work, with every row known, but
    emit a deprecation warning and will be removed at the next breaking release. Nothing
    could check the order, so a dual given in another order silently went to the wrong
    label. Giving them together with `duals` is an error.

Box duals have **one column per primal component**, not one per declared constraint:
components without a bound carry a zero multiplier, and several labels on one component
share its multiplier. This is what lets [`dual`](@ref CTModels.Solutions.dual) return the
multiplier of any label; see [Duals & diagnostics](duals.md).

## Diagnostics

| Keyword | Type | Default |
| --- | --- | --- |
| `objective` | `Float64` | required |
| `successful` | `Bool` | required |
| `iterations` | `Int` | not provided |
| `constraints_violation` | `Float64` | not provided |
| `message` | `String` | not provided |
| `status` | `Symbol` | not provided |
| `infos` | `Dict{Symbol,Any}` | empty |

Fields that are not provided are omitted from the display of the solution, which is what a
flow-based result typically needs; see the display examples in [Solutions](overview.md).

## What is checked

`build_solution` raises an `IncorrectArgument`, with the received and expected sizes, when:

- the number of columns of `X`, `U`, `P` or a box dual does not match the model;
- `v` or a variable box dual has the wrong length;
- a label of `duals` is not a path or boundary constraint of the model (a box label
  included), or its value has the wrong type or the wrong number of rows;
- `control_interpolation` is neither `:constant` nor `:linear`;
- a time grid holds a repeated time;
- a switching time lies outside the time span, or the limits of the switching model have
  the wrong number of columns.

```@repl bs
CTModels.build_solution(ocp, T, X, U, Float64[], P; objective=1.0, successful=true)
```

```@repl bs
CTModels.build_solution(ocp, T, X, U, v, P; objective=1.0, successful=true,
    duals=Dict(:x0 => [1.0, 2.0]))
```
