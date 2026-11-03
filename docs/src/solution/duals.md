# Duals & diagnostics

```@meta
CurrentModule = CTModels
```

Beyond the primal trajectories, a solution carries the **Lagrange multipliers** of the
constraints (grouped in a [`DualModel`](@ref CTModels.Solutions.DualModel)) and the **solver
diagnostics** (a [`SolverInfos`](@ref CTModels.Solutions.SolverInfos)).

## A solution with duals

We build a small problem with a boundary constraint and two path constraints, then give the
path-constraint multipliers **by label**, each as a callable `t → μ(t)`. State, control and
costate are passed as **functions** here (the array form is equally accepted):

```@example duals
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 1)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> -u)

CTModels.constraint!(pre, :boundary;
    f=(r, x0, xf, v) -> (r[1] = x0 + 1; nothing), lb=[0.0], ub=[0.0], label=:initial_con)
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x + u; nothing), lb=[-Inf], ub=[0.0], label=:mixed)  # 1 row
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x + 1; r[2] = u + 1; nothing),
    lb=[-3.0, 1.0], ub=[1.0, 2.5], label=:con2)                                # 2 rows

CTModels.time_dependence!(pre; autonomous=false)
ocp = CTModels.build(pre)

x(t) = -exp(-t)
p(t) = exp(t - 1) - 1
u(t) = -x(t)
# x + u ≤ 0 is active, with the nonnegative dual e^{t-1} (single bound, see the sign
# convention below); :con2 is inactive on its first row, and the signed dual t of its second
# row says its upper side is active. The dual of :initial_con is not given: it is unknown.
duals = Dict(:mixed => t -> p(t) + 1, :con2 => t -> [0.0, t])

sol = CTModels.build_solution(ocp, collect(range(0.0, 1.0; length=201)),
    x, u, Float64[], p;
    objective=exp(-1) - 1, iterations=12, constraints_violation=0.0,
    message="Solve_Succeeded", status=:optimal, successful=true,
    duals=duals)
nothing # hide
```

## Sign convention

The duals follow the sign convention of the ecosystem, stated once in
[ct-conventions, `SGN1`–`SGN6`](https://github.com/control-toolbox/ct-conventions/blob/main/rules/signs.md)
and discussed in
[OptimalControl.jl#1014](https://github.com/control-toolbox/OptimalControl.jl/discussions/1014).
A multiplier belongs to a constraint and to a problem, not to the way they are written,
nor to the solver or the method:

| Constraint | `dual(sol, model, :label)` | Rule |
| --- | --- | --- |
| single finite bound, `c ≥ lb` or `c ≤ ub` (path constraint or box) | the multiplier of that side, `≥ 0` | `SGN2` |
| equality `c = b` | signed | `SGN3` |
| two finite bounds `lb ≤ c ≤ ub` | signed `μU − μL`: `≥ 0` when the upper side is active, `≤ 0` when the lower side is | `SGN3` |

- `min J` and `max -J` have the same duals and the same costate (`SGN1`, `SGN4`).
- The same constraint written as a path constraint or as a box has the same dual, and a
  direct and an indirect solution give the same duals (`SGN5`).
- CTModels **stores** the duals it is given: the convention is applied by the producers of
  solutions (the NLP solvers through CTSolvers, CTDirect, CTFlows). For the boxes, which
  are stored as two nonnegative multipliers per component (lower and upper bound),
  [`dual`](@ref CTModels.Solutions.dual) applies the rule itself, from the bounds of the
  model.

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
[`boundary_constraints_dual`](@ref CTModels.Solutions.boundary_constraints_dual). No
boundary label was given here, so the solution stores none:

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

A solution produced by a direct solve carries every dual; the solution of a CTFlows flow
carries the duals of the path constraints given to the flow by their label, and only them.
Use [`has_duals`](@ref CTModels.Solutions.has_duals) to test whether a solution carries
any dual — when it returns `false`, the dual model is an
[`EmptyDualModel`](@ref CTModels.Solutions.EmptyDualModel) and all dual accessors return
`nothing`.

[`has_dual`](@ref CTModels.Solutions.has_dual) tells whether the dual of one label is known,
that is whether [`dual`](@ref CTModels.Solutions.dual) returns it:

```@repl duals
CTModels.has_dual(sol, ocp, :con2)
CTModels.has_dual(sol, ocp, :initial_con)
```

[`dual`](@ref CTModels.Solutions.dual) throws:

- an `IncorrectArgument` for a label that is not a constraint of the model;
- a `PreconditionError` for a label whose dual the solution does not hold: a label absent
  from the `duals` given to `build_solution`, or a kind of constraint whose duals were not
  stored at all. A missing dual is never read as `0`. The suggestion of the error is the
  note `infos(sol)[:missing_duals]` left by the producer of the solution, when there is
  one: it says why the dual is missing and how to get it.

```@repl duals
CTModels.dual(sol, ocp, :initial_con)
```

!!! note "Box duals are indexed per component"

    For state/control/variable **box** constraints, the stored duals are indexed by *primal
    component*, as two nonnegative multipliers (lower and upper bound). For the component
    range `rg` of a label, `dual(sol, model, :label)` returns, per component, the
    lower-bound multiplier for a component with a lower bound only, the upper-bound
    multiplier for an upper bound only, and `duals_ub - duals_lb` for two finite bounds or a
    fixed component (see the sign convention above). If several labels target the same
    component (the alias mechanism of the [Constraints](../model/constraints.md) page),
    they share that one multiplier — the solver only sees the intersected bound.

## How the duals are stored

This section is for developers of CTModels and of the producers of solutions (CTDirect,
CTFlows). A user only needs `duals=` and [`dual`](@ref CTModels.Solutions.dual).

**The label is the only interface.** A producer gives `label => value`; the order of the
rows is a CTModels internal. [`constraint_rows`](@ref CTModels.Models.constraint_rows) gives
it, `(kind, rows)`:

```@repl duals
CTModels.Models.constraint_rows(ocp, :mixed)
CTModels.Models.constraint_rows(ocp, :con2)
CTModels.Models.constraint_rows(ocp, :initial_con)
```

- A path or boundary label occupies contiguous rows of the stacked constraint
  (`path_constraints_nl(ocp)`, `boundary_constraints_nl(ocp)`), in the order of
  declaration. For a box label, `rows` are the components it bounds.
- **Stacked storage.** The [`DualModel`](@ref CTModels.Solutions.DualModel) keeps the path
  duals as one function of time with one entry per row, and the boundary duals as one
  vector. The rows of the labels not given hold `NaN`, so that the raw accessors
  `path_constraints_dual(sol)` and `boundary_constraints_dual(sol)` never return a fake
  `0`.
- **Masks of the known rows.** `path_constraints_dual_known` and
  `boundary_constraints_dual_known` are the authority on what is known. They are
  canonical: `nothing` when every row of the stored duals is known (the storage is then the
  same as before the labels), a `Vector{Bool}` only for a partial knowledge. A kind of
  constraint with no known row is stored as `nothing`.
- **Placement** (`src/Solutions/labelled_duals.jl`). When every path label is a matrix,
  they are stacked into one matrix and interpolated as a whole. As soon as one is a
  function, every part becomes a function of time and they are combined into a
  [`StackedDuals`](@ref CTModels.Solutions.StackedDuals), a callable struct over a typed
  tuple with a generated call method; it is on the hot path, see
  [Performance](../guide/performance.md).
- **Serialization** (format 3). The masks are written only when some rows are unknown; the
  unknown entries are `null` in JSON (`NaN` in JLD2). Reading a file goes back to labels and
  passes `duals=`; a file without masks is read with every stored row known.

Here every path label was given, so the mask is `nothing`. With `:con2` only, the row of
`:mixed` is unknown:

```@example duals
sol_part = CTModels.build_solution(ocp, collect(range(0.0, 1.0; length=201)),
    x, u, Float64[], p; objective=exp(-1) - 1, successful=true,
    duals=Dict(:con2 => t -> [0.0, t]))
nothing # hide
```

```@repl duals
CTModels.dual_model(sol).path_constraints_dual_known
CTModels.dual_model(sol_part).path_constraints_dual_known
CTModels.path_constraints_dual(sol_part)(0.5)
```

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
