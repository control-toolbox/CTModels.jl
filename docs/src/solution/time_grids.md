# Time grids

```@meta
CurrentModule = CTModels
```

A solution stores the discretisation points at which its trajectories were computed. CTModels
supports either **one shared grid** or **one grid per component**, and chooses the
representation automatically.

| Type | When | Stores |
|---|---|---|
| [`UnifiedTimeGridModel`](@ref CTModels.Solutions.UnifiedTimeGridModel) | all components share a grid | a single vector |
| [`MultipleTimeGridModel`](@ref CTModels.Solutions.MultipleTimeGridModel) | state/control/costate/path differ | a named tuple of grids |
| [`EmptyTimeGridModel`](@ref CTModels.Solutions.EmptyTimeGridModel) | no discretisation yet | nothing |

```@example grids
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
nothing # hide
```

## One shared grid

When the four grids passed to [`build_solution`](@ref CTModels.Solutions.build_solution) are
identical, CTModels collapses them into a [`UnifiedTimeGridModel`](@ref CTModels.Solutions.UnifiedTimeGridModel)
to save memory:

```@example grids
T = collect(range(0.0, 1.0; length=101))
X = [1.0 - t/100 for t in 1:101, i in 1:2]
U = [sin(t/50) for t in 1:101, i in 1:1]
P = zeros(101, 2)

sol_u = CTModels.build_solution(ocp, T, T, T, T, X, U, Float64[], P;
    objective=0.5, iterations=10, constraints_violation=1e-6,
    message="ok", status=:optimal, successful=true)
nothing # hide
```

```@repl grids
CTModels.time_grid_model(sol_u) isa CTModels.UnifiedTimeGridModel
length(CTModels.time_grid(sol_u))
```

## One grid per component

Passing different grids for state, control, costate and path yields a
[`MultipleTimeGridModel`](@ref CTModels.Solutions.MultipleTimeGridModel); each component is then
queried by name through [`time_grid`](@ref CTModels.Components.time_grid):

```@example grids
T_state   = collect(range(0.0, 1.0; length=101))
T_control = collect(range(0.0, 1.0; length=51))
T_costate = collect(range(0.0, 1.0; length=76))
T_path    = collect(range(0.0, 1.0; length=61))

X = [1.0 - t/100 for t in 1:101, i in 1:2]
U = [sin(t/25) for t in 1:51, i in 1:1]
P = zeros(76, 2)

sol_m = CTModels.build_solution(ocp, T_state, T_control, T_costate, T_path,
    X, U, Float64[], P;
    objective=0.5, iterations=10, constraints_violation=1e-6,
    message="ok", status=:optimal, successful=true)
nothing # hide
```

```@repl grids
CTModels.time_grid_model(sol_m) isa CTModels.MultipleTimeGridModel
length(CTModels.time_grid(sol_m, :state))
length(CTModels.time_grid(sol_m, :control))
length(CTModels.time_grid(sol_m, :costate))
```

## Component aliases

`time_grid(sol, :states)`, `time_grid(sol, :duals)`, … accept many synonyms. They are
normalised to the four canonical grids (`:state`, `:control`, `:costate`, `:path`) by
[`clean_component_symbols`](@ref CTModels.Solutions.clean_component_symbols):

```@repl grids
CTModels.clean_component_symbols((:states, :controls, :costate, :constraint, :duals))
```

This is why box-constraint duals share the state/control grids, and path-constraint duals the
`:path` grid — the mapping is centralised in one place rather than scattered across accessors.
