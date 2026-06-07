# Solutions

```@meta
CurrentModule = CTModels
```

A [`Solution`](@ref CTModels.OCP.Solution) is the immutable container returned to the user
once a solver has run. It bundles the **primal trajectories** (state, control, costate), the
**optimisation variable**, the **objective value**, the **dual variables**, and the
**solver diagnostics** — all behind a uniform accessor surface.

CTModels does **not** solve OCPs; a `Solution` is assembled from raw numerical arrays by
[`build_solution`](@ref CTModels.OCP.build_solution), the bridge an NLP backend calls.

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
| [Time grids](time_grids.md) | One grid or several | [`UnifiedTimeGridModel`](@ref CTModels.OCP.UnifiedTimeGridModel), [`MultipleTimeGridModel`](@ref CTModels.OCP.MultipleTimeGridModel) |
| [Trajectories](trajectories.md) | Reading primal data | [`state`](@ref CTModels.OCP.state), [`control`](@ref CTModels.OCP.control), [`costate`](@ref CTModels.OCP.costate) |
| [Duals & diagnostics](duals.md) | Multipliers and solver status | [`dual`](@ref CTModels.OCP.dual), [`DualModel`](@ref CTModels.OCP.DualModel), [`SolverInfos`](@ref CTModels.OCP.SolverInfos) |

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
(x(0.5),
 CTModels.objective(sol),
 CTModels.iterations(sol),
 CTModels.successful(sol))
```

## Anatomy of a `Solution`

| Field group | Accessor(s) | Stored as |
|---|---|---|
| time grid | [`time_grid`](@ref CTModels.OCP.time_grid) | [`AbstractTimeGridModel`](@ref CTModels.OCP.AbstractTimeGridModel) |
| state / control / costate | [`state`](@ref CTModels.OCP.state), [`control`](@ref CTModels.OCP.control), [`costate`](@ref CTModels.OCP.costate) | callables `t → …` |
| variable / objective | [`variable`](@ref CTModels.OCP.variable), [`objective`](@ref CTModels.OCP.objective) | value |
| duals | [`dual`](@ref CTModels.OCP.dual), [`DualModel`](@ref CTModels.OCP.DualModel) | callables / vectors |
| diagnostics | [`iterations`](@ref CTModels.OCP.iterations), [`status`](@ref CTModels.OCP.status), [`successful`](@ref CTModels.OCP.successful) | [`SolverInfos`](@ref CTModels.OCP.SolverInfos) |

Each accessor dispatches on a typed field, so reading a solution never inspects raw
closures. The following pages take each group in turn.
```
