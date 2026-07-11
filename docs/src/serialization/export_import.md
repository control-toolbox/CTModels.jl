# Export & import

```@meta
CurrentModule = CTModels
```

[`export_ocp_solution`](@ref CTModels.Serialization.export_ocp_solution) writes a
[`Solution`](@ref CTModels.Solutions.Solution) to disk;
[`import_ocp_solution`](@ref CTModels.Serialization.import_ocp_solution) reads it back, given
the [`Model`](@ref CTModels.Models.Model) it belongs to. Two formats are available, each behind its
extension:

| `format` | Extension | File |
|---|---|---|
| `:JLD` (default) | `CTModelsJLD` (`JLD2`) | binary `.jld2` |
| `:JSON` | `CTModelsJSON` (`JSON3`) | text `.json` |

```@example exim
using CTModels
using JSON3      # CTModelsJSON
using JLD2       # CTModelsJLD

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
sol = CTModels.build_solution(ocp, T, hcat(cos.(T), -sin.(T)),
    reshape(-cos.(T), N, 1), Float64[], zeros(N, 2);
    objective=0.5, iterations=10, constraints_violation=1e-9,
    message="ok", status=:optimal, successful=true)
nothing # hide
```

## Both formats round-trip

The `filename` is a **base** path; the extension is appended automatically.

```@example exim
base = joinpath(tempdir(), "ctmodels_demo")

CTModels.export_ocp_solution(sol; filename=base, format=:JSON)
CTModels.export_ocp_solution(sol; filename=base, format=:JLD)

from_json = CTModels.import_ocp_solution(ocp; filename=base, format=:JSON)
from_jld  = CTModels.import_ocp_solution(ocp; filename=base, format=:JLD)
nothing # hide
```

```@repl exim
CTModels.objective(from_json)
CTModels.objective(from_jld)
```

The reloaded solution behaves exactly like the original — its trajectories are again callables
of time:

```@example exim
x = CTModels.state(from_json)
nothing # hide
```

```@repl exim
x(0.5)
```

## How trajectories survive serialization

A trajectory is a *function* `t -> x(t)`, which neither JSON nor JLD2 can store directly.
CTModels works around this by **resampling**: before writing, each trajectory is evaluated on
its time grid (the helpers in
[`OCP/Building/discretization_utils.jl`](../model/building.md)), and only the resulting arrays
are persisted. On import, the arrays are wrapped back into interpolated callables — the same
mechanism used when [building a solution](../solution/trajectories.md).

!!! note "Low-level tags"

    The format keyword dispatches internally on the tags
    [`JLD2Tag`](@ref CTModels.Serialization.JLD2Tag) and
    [`JSON3Tag`](@ref CTModels.Serialization.JSON3Tag), both subtypes of
    [`AbstractTag`](@ref CTModels.Serialization.AbstractTag). The extension methods
    `export_ocp_solution(CTModels.JLD2Tag(), sol; …)` etc. are what each `ext/` file
    implements; the `format=` wrapper is the public, dependency-free entry point.
