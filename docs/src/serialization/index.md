# Serialization & extensions

```@meta
CurrentModule = CTModels
```

CTModels keeps heavy, optional dependencies out of its core. Saving solutions (JSON, JLD2) and
plotting them live in **package extensions** under `ext/`, loaded automatically by Julia only
when the trigger package is present.

| Extension | Trigger package | Adds |
|---|---|---|
| `CTModelsJSON` | `JSON3` | JSON export/import of a [`Solution`](@ref CTModels.OCP.Solution) |
| `CTModelsJLD` | `JLD2` | JLD2 (binary) export/import |
| `CTModelsPlots` | `Plots` | `Plots.plot(sol)` / `Plots.plot!(sol)` |

The public wrappers [`export_ocp_solution`](@ref CTModels.Serialization.export_ocp_solution),
[`import_ocp_solution`](@ref CTModels.Serialization.import_ocp_solution) and the plot recipe
live in the core; their **implementations** live in the extension. Until the trigger package is
loaded, calling a wrapper raises a descriptive `CTBase.ExtensionError` — the core never hard-
depends on JSON3, JLD2 or Plots.

```
core wrapper ──(trigger pkg loaded?)──► extension method
     │                  │
export_ocp_solution    no ─► CTBase.ExtensionError
plot recipe            yes ─► JSON3 / JLD2 / Plots implementation
```

## Reading order

| Page | Topic | Key symbols |
|---|---|---|
| [Export & import](export_import.md) | Persisting solutions | [`export_ocp_solution`](@ref CTModels.Serialization.export_ocp_solution), [`import_ocp_solution`](@ref CTModels.Serialization.import_ocp_solution) |
| [Plotting](plotting.md) | Visualising trajectories | `Plots.plot`, `Plots.plot!` |

## A solution to serialize

The examples in this guide reuse one fabricated solution:

```@example ser_index
using CTModels
using JSON3     # activates the CTModelsJSON extension

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
X = hcat(cos.(T), -sin.(T))
U = reshape(-cos.(T), N, 1)
P = zeros(N, 2)
sol = CTModels.build_solution(ocp, T, X, U, Float64[], P;
    objective=0.5, iterations=10, constraints_violation=1e-9,
    message="ok", status=:optimal, successful=true)
nothing # hide
```

## Round-trip in one line each

```@example ser_index
base = joinpath(tempdir(), "ctmodels_overview")
CTModels.export_ocp_solution(sol; filename=base, format=:JSON)
reloaded = CTModels.import_ocp_solution(ocp; filename=base, format=:JSON)

(CTModels.objective(sol), CTModels.objective(reloaded))
```

See [Export & import](export_import.md) for the formats and the resampling strategy, and
[Plotting](plotting.md) for the Plots recipe.
