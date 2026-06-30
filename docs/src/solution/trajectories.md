# Trajectories

```@meta
CurrentModule = CTModels
```

The primal part of a solution is read through accessors that return **callables of time**
(interpolated from the stored samples) for the trajectories, and plain values for the
variable and the objective.

| Accessor | Returns | Shape |
|---|---|---|
| [`state`](@ref CTModels.Components.state) | `x(t)` | callable → ``\mathbb{R}^n`` |
| [`control`](@ref CTModels.Components.control) | `u(t)` | callable → ``\mathbb{R}^m`` |
| [`costate`](@ref CTModels.Components.costate) | `p(t)` | callable → ``\mathbb{R}^n`` |
| [`variable`](@ref CTModels.Components.variable) | `v` | value |
| [`objective`](@ref CTModels.Components.objective) | optimal cost | scalar |

```@example traj
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 1, "v")
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)

N = 101
T = collect(range(0.0, 1.0; length=N))
X = hcat(cos.(T), -sin.(T))
U = reshape(-cos.(T), N, 1)
P = zeros(N, 2)
v = [2.0]                         # the optimisation variable value

sol = CTModels.build_solution(ocp, T, X, U, v, P;
    objective=0.5, iterations=10, constraints_violation=1e-9,
    message="ok", status=:optimal, successful=true)
nothing # hide
```

## Reading trajectories

The trajectories are callables, so they can be evaluated at **any** time in the interval,
not only at grid points — the samples are interpolated:

```@example traj
x = CTModels.state(sol)
u = CTModels.control(sol)
p = CTModels.costate(sol)
nothing # hide
```

```@repl traj
x(0.0)
x(0.123)
u(0.5)
p(1.0)
```

```@repl traj
CTModels.variable(sol)
CTModels.objective(sol)
```

## Interpolation of the control

State and costate are interpolated **linearly**. The control may instead be **piecewise
constant** — typical of direct collocation — selected by the `control_interpolation` keyword
of [`build_solution`](@ref CTModels.Solutions.build_solution) (`:linear` or `:constant`). The choice
is recorded and read back with
[`control_interpolation`](@ref CTModels.Solutions.control_interpolation):

```@example traj
sol_const = CTModels.build_solution(ocp, T, X, U, v, P;
    objective=0.5, iterations=10, constraints_violation=1e-9,
    message="ok", status=:optimal, successful=true,
    control_interpolation=:constant)
nothing # hide
```

```@repl traj
CTModels.control_interpolation(sol)
CTModels.control_interpolation(sol_const)
```

Because the interpolation kind is a stored field — not baked into an opaque closure —
downstream code (plotting, serialization) can branch on it explicitly. The
[Duals & diagnostics](duals.md) page covers the remaining accessors.
