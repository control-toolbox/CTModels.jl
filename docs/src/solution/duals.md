# Duals & diagnostics

```@meta
CurrentModule = CTModels
```

Beyond the primal trajectories, a solution carries the **Lagrange multipliers** of the
constraints (grouped in a [`DualModel`](@ref CTModels.OCP.DualModel)) and the **solver
diagnostics** (a [`SolverInfos`](@ref CTModels.OCP.SolverInfos)).

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

[`dual`](@ref CTModels.OCP.dual) resolves a constraint `label` to its multiplier — a callable
for time-dependent (path) constraints, a value for boundary/variable ones. The label `:con2`
covers the **two** path rows declared with it, so its dual is the 2-vector slice:

```@example duals
d = CTModels.dual(sol, ocp, :con2)
d(0.5)
```

The whole path multiplier is reached directly through the
[`DualModel`](@ref CTModels.OCP.DualModel) accessor
[`path_constraints_dual`](@ref CTModels.OCP.path_constraints_dual):

```@example duals
CTModels.path_constraints_dual(sol)(0.5)
```

!!! note "Box duals are indexed per component"

    For state/control/variable **box** constraints, the stored duals are indexed by *primal
    component*. `dual(sol, model, :label)` returns `duals_lb[:, rg] - duals_ub[:, rg]` for the
    component range `rg` of the label. If several labels target the same component (the alias
    mechanism of the [Constraints](../model/constraints.md) page), they share that one
    multiplier — the solver only sees the intersected bound.

## Solver diagnostics

The [`SolverInfos`](@ref CTModels.OCP.SolverInfos) record is exposed through scalar accessors:

```@example duals
(CTModels.iterations(sol),
 CTModels.status(sol),
 CTModels.message(sol),
 CTModels.successful(sol),
 CTModels.constraints_violation(sol))
```

`infos(sol)` returns the `Dict{Symbol,Any}` of any extra solver-specific data. These fields
are what [Serialization](../serialization/index.md) writes to disk alongside the trajectories.
```
