# Duals & diagnostics

```@meta
CurrentModule = CTModels
```

Beyond the primal trajectories, a solution carries the **Lagrange multipliers** of the
constraints (grouped in a [`DualModel`](@ref CTModels.Solutions.DualModel)) and the **solver
diagnostics** (a [`SolverInfos`](@ref CTModels.Solutions.SolverInfos)).

## A solution with duals

We build a small problem with a boundary constraint and two path constraints, then supply the
path-constraint multipliers as a callable `t → μ(t)`. State, control and costate are passed as
**functions** here (the array form is equally accepted):

```@example duals
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 1)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> -u[1])

CTModels.constraint!(pre, :boundary;
    f=(r, x0, xf, v) -> (r[1] = x0[1] + 1; nothing), lb=[0.0], ub=[0.0], label=:initial_con)
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x[1] + u[1]; nothing), lb=[-Inf], ub=[0.0])  # 1 row
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x[1] + 1; r[2] = u[1] + 1; nothing),
    lb=[-3.0, 1.0], ub=[1.0, 2.5], label=:con2)                                # 2 rows

CTModels.time_dependence!(pre; autonomous=false)
ocp = CTModels.build(pre)

x(t) = -exp(-t)
p(t) = exp(t - 1) - 1
u(t) = -x(t)
mu(t) = [-(p(t) + 1), 0.0, t]      # one entry per stacked path-constraint row

sol = CTModels.build_solution(ocp, collect(range(0.0, 1.0; length=201)),
    x, u, Float64[], p;
    objective=exp(-1) - 1, iterations=12, constraints_violation=0.0,
    message="Solve_Succeeded", status=:optimal, successful=true,
    path_constraints_dual=mu)
nothing # hide
```

## Reading a multiplier by label

[`dual`](@ref CTModels.Solutions.dual) resolves a constraint `label` to its multiplier — a callable
for time-dependent (path) constraints, a value for boundary/variable ones. The label `:con2`
covers the **two** path rows declared with it, so its dual is the 2-vector slice:

```@example duals
d = CTModels.dual(sol, ocp, :con2)
nothing # hide
```

```@repl duals
d(0.5)
```

The whole path multiplier is reached directly through the
[`DualModel`](@ref CTModels.Solutions.DualModel) accessor
[`path_constraints_dual`](@ref CTModels.Solutions.path_constraints_dual):

```@repl duals
CTModels.path_constraints_dual(sol)(0.5)
```

Boundary-constraint multipliers are read with
[`boundary_constraints_dual`](@ref CTModels.Solutions.boundary_constraints_dual):

```@repl duals
CTModels.boundary_constraints_dual(sol)
```

### Box-constraint duals

Box constraints on state, control, and variable components have separate lower-bound
and upper-bound dual accessors:

| Accessor | Returns |
|---|---|
| [`state_constraints_lb_dual`](@ref CTModels.Solutions.state_constraints_lb_dual) | state lower-bound duals |
| [`state_constraints_ub_dual`](@ref CTModels.Solutions.state_constraints_ub_dual) | state upper-bound duals |
| [`control_constraints_lb_dual`](@ref CTModels.Solutions.control_constraints_lb_dual) | control lower-bound duals |
| [`control_constraints_ub_dual`](@ref CTModels.Solutions.control_constraints_ub_dual) | control upper-bound duals |
| [`variable_constraints_lb_dual`](@ref CTModels.Solutions.variable_constraints_lb_dual) | variable lower-bound duals |
| [`variable_constraints_ub_dual`](@ref CTModels.Solutions.variable_constraints_ub_dual) | variable upper-bound duals |

Their dimensions are queried with
[`dim_dual_state_constraints_box`](@ref CTModels.Solutions.dim_dual_state_constraints_box),
[`dim_dual_control_constraints_box`](@ref CTModels.Solutions.dim_dual_control_constraints_box),
and
[`dim_dual_variable_constraints_box`](@ref CTModels.Solutions.dim_dual_variable_constraints_box).

### Checking for duals

A solution produced by a solver carries duals; a solution built by a flow does not.
Use [`has_duals`](@ref CTModels.Solutions.has_duals) to test this — when it returns
`false`, the dual model is an [`EmptyDualModel`](@ref CTModels.Solutions.EmptyDualModel)
and all dual accessors return `nothing`.

!!! note "Box duals are indexed per component"

    For state/control/variable **box** constraints, the stored duals are indexed by *primal
    component*. `dual(sol, model, :label)` returns `duals_lb[:, rg] - duals_ub[:, rg]` for the
    component range `rg` of the label. If several labels target the same component (the alias
    mechanism of the [Constraints](../model/constraints.md) page), they share that one
    multiplier — the solver only sees the intersected bound.

## Solver diagnostics

The [`SolverInfos`](@ref CTModels.Solutions.SolverInfos) record is exposed through scalar accessors:

```@repl duals
CTModels.iterations(sol)
CTModels.status(sol)
CTModels.message(sol)
CTModels.successful(sol)
CTModels.constraints_violation(sol)
```

The original [`Model`](@ref CTModels.Models.Model) can be retrieved from a solution with
[`model`](@ref CTModels.Solutions.model), and `infos(sol)` returns the `Dict{Symbol,Any}`
of any extra solver-specific data. These fields
are what [Serialization](../serialization/overview.md) writes to disk alongside the trajectories.
