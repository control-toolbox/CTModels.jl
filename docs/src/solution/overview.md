# Solutions

```@meta
CurrentModule = CTModels
```

A [`Solution`](@ref CTModels.Solutions.Solution) is the immutable container returned to the user
once a solver has run. It bundles the **primal trajectories** (state, control, costate), the
**optimisation variable**, the **objective value**, the **dual variables**, and the
**solver diagnostics** — all behind a uniform accessor surface.

CTModels does **not** solve OCPs; a `Solution` is assembled from raw numerical arrays by
[`build_solution`](@ref CTModels.Solutions.build_solution), the bridge an NLP backend calls.

```
model + numerical arrays (T, X, U, v, P, duals, infos)
                    │
              build_solution
                    ▼
                 Solution ──► state/control/costate/variable/objective/dual/…
```

## Reading order

| Page | Topic | Key symbols |
|---|---|---|
| [Time grids](time_grids.md) | One grid or several | [`UnifiedTimeGridModel`](@ref CTModels.Solutions.UnifiedTimeGridModel), [`MultipleTimeGridModel`](@ref CTModels.Solutions.MultipleTimeGridModel) |
| [Trajectories](trajectories.md) | Reading primal data | [`state`](@ref CTModels.Components.state), [`control`](@ref CTModels.Components.control), [`costate`](@ref CTModels.Components.costate) |
| [Duals & diagnostics](duals.md) | Multipliers and solver status | [`dual`](@ref CTModels.Solutions.dual), [`DualModel`](@ref CTModels.Solutions.DualModel), [`SolverInfos`](@ref CTModels.Solutions.SolverInfos) |

## Minimal end-to-end example

We reuse a minimal model and feed `build_solution` **fabricated** arrays (in practice these
come from a solver). State, control and costate are sampled on one uniform grid:

```@example sol_index
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)

N = 101
T = collect(range(0.0, 1.0; length=N))
X = hcat(cos.(T), -sin.(T))      # N×2 : state samples (rows = time)
U = reshape(-cos.(T), N, 1)      # N×1 : control samples
P = zeros(N, 2)                  # N×2 : costate samples
v = Float64[]                    # no optimisation variable

sol = CTModels.build_solution(ocp, T, X, U, v, P;
    objective=0.5,
    iterations=10,
    constraints_violation=1e-9,
    message="Solve_Succeeded",
    status=:Solve_Succeeded,
    successful=true,
)
```

The trajectories are returned as **callables** (interpolated from the samples), and the
diagnostics as scalars:

```@example sol_index
x = CTModels.state(sol)          # x(t) → state at time t
nothing # hide
```

```@repl sol_index
x(0.5)
CTModels.objective(sol)
CTModels.iterations(sol)
CTModels.successful(sol)
```

## Anatomy of a `Solution`

| Field group | Accessor(s) | Stored as |
|---|---|---|
| time grid | [`time_grid`](@ref CTModels.Components.time_grid), `is_empty`, [`is_empty_time_grid`](@ref CTModels.Solutions.is_empty_time_grid) | [`AbstractTimeGridModel`](@ref CTModels.Solutions.AbstractTimeGridModel) |
| state / control / costate | [`state`](@ref CTModels.Components.state), [`control`](@ref CTModels.Components.control), [`costate`](@ref CTModels.Components.costate) | callables `t → …` |
| variable / objective | [`variable`](@ref CTModels.Components.variable), [`objective`](@ref CTModels.Components.objective) | value |
| duals | [`dual`](@ref CTModels.Solutions.dual), [`DualModel`](@ref CTModels.Solutions.DualModel), [`has_duals`](@ref CTModels.Solutions.has_duals) | callables / vectors |
| diagnostics | [`iterations`](@ref CTModels.Solutions.iterations), [`status`](@ref CTModels.Solutions.status), [`successful`](@ref CTModels.Solutions.successful) | [`SolverInfos`](@ref CTModels.Solutions.SolverInfos) |
| model | [`model`](@ref CTModels.Solutions.model) | [`Model`](@ref CTModels.Models.Model) |

Each accessor dispatches on a typed field, so reading a solution never inspects raw
closures. The following pages take each group in turn.

## Displaying a solution

Typing a `Solution` in the REPL renders a single tree whose branches adapt to the
data that was actually provided — fields left as `NotProvided` are silently omitted.

### Case 1 — Full solver diagnostics

The typical output when an NLP solver fills every field:

```@example sol_display
using CTModels
pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
N = 11; T = collect(range(0.0, 1.0; length=N))
X = hcat(cos.(T), -sin.(T)); U = reshape(-cos.(T), N, 1); P = zeros(N, 2)
sol = CTModels.build_solution(ocp, T, X, U, Float64[], P;
    objective=0.5,
    iterations=10,
    constraints_violation=1e-9,
    message="Solve_Succeeded",
    status=:Solve_Succeeded,
    successful=true,
)
```

### Case 2 — Lightweight flow result

When only a message is meaningful (e.g. from CTFlows),
`iterations`, `status`, and `constraints_violation` are simply not shown:

```@example sol_display
sol_flow = CTModels.build_solution(ocp, T, X, U, Float64[], P;
    objective=0.5,
    message="Solution computed by CTFlows OCP flow",
    successful=true,
)
sol_flow
```

### Case 3 — With an optimisation variable

When the OCP has an optimisation variable, it appears between the objective and the
solver metadata:

```@example sol_display
pre_v = CTModels.PreModel()
CTModels.variable!(pre_v, 1, "T", ["T"])
CTModels.time!(pre_v; t0=0.0, tf=1.0)
CTModels.state!(pre_v, 1)
CTModels.control!(pre_v, 1)
CTModels.dynamics!(pre_v, (r, t, x, u, v) -> (r[1] = u[1]; nothing))
CTModels.objective!(pre_v, :min; mayer=(x0, xf, v) -> v[1]^2)
CTModels.time_dependence!(pre_v; autonomous=true)
ocp_v = CTModels.build(pre_v)
Xv = reshape(T, N, 1); Uv = ones(N, 1); Pv = zeros(N, 1)
sol_v = CTModels.build_solution(ocp_v, T, Xv, Uv, [1.5], Pv;
    objective=2.25,
    iterations=7,
    constraints_violation=1e-11,
    message="optimal",
    status=:first_order,
    successful=true,
)
```

### Case 4 — Variable duals and boundary duals

When a solver also provides dual variables (Lagrange multipliers), they appear nested
under the variable and as a separate "Boundary duals" row:

```@example sol_display
pre_d = CTModels.PreModel()
CTModels.variable!(pre_d, 1, "T", ["T"])
CTModels.time!(pre_d; t0=0.0, tf=1.0)
CTModels.state!(pre_d, 1)
CTModels.control!(pre_d, 1)
CTModels.dynamics!(pre_d, (r, t, x, u, v) -> (r[1] = u[1]; nothing))
CTModels.objective!(pre_d, :min; mayer=(x0, xf, v) -> v[1]^2)
CTModels.constraint!(pre_d, :variable; rg=1:1, lb=[0.5], ub=[2.0], label=:T_box)
bc!(r, x0, xf, v) = (r[1] = x0[1]; r[2] = xf[1] - 1.0; nothing)
CTModels.constraint!(pre_d, :boundary; f=bc!, lb=zeros(2), ub=zeros(2), label=:bc)
CTModels.time_dependence!(pre_d; autonomous=true)
ocp_d = CTModels.build(pre_d)
sol_d = CTModels.build_solution(ocp_d, T, Xv, Uv, [1.5], Pv;
    objective=2.25,
    iterations=12,
    constraints_violation=2e-10,
    message="optimal",
    status=:first_order,
    successful=true,
    variable_constraints_lb_dual=[0.0],
    variable_constraints_ub_dual=[0.3],
    boundary_constraints_dual=[1.2, -0.8],
)
```
