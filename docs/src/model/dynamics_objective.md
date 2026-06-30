# Dynamics and objective

```@meta
CurrentModule = CTModels
```

With the spaces declared, two verbs supply the **equations of motion** and the **cost**:
[`dynamics!`](@ref CTModels.Building.dynamics!) and
[`objective!`](@ref CTModels.Building.objective!).

```@example dynobj
using CTModels

function fresh()                       # a pre-model with state, control, times set
    pre = CTModels.PreModel()
    CTModels.variable!(pre, 0)
    CTModels.time!(pre; t0=0.0, tf=1.0)
    CTModels.state!(pre, 2)
    CTModels.control!(pre, 1)
    return pre
end
nothing # hide
```

## Dynamics

The right-hand side ``f`` of ``\dot{x} = f(t, x, u, v)`` is always written **in place**:
the first argument `r` is the buffer to fill. The full signature is `f!(r, t, x, u, v)`,
even for an autonomous system (the unused `t` keeps one uniform interface).

```@example dynobj
pre = fresh()
function f!(r, t, x, u, v)
    r[1] = x[2]
    r[2] = u[1]
    return nothing
end
CTModels.dynamics!(pre, f!)
```

### Component-wise dynamics

Alternatively, define the dynamics **block by block** over disjoint state ranges. Each
partial right-hand side fills its own local buffer (`r[1]` is the first row of its range).
This is convenient when components come from different physical models.

```@example dynobj
pre = fresh()
CTModels.dynamics!(pre, 1:1, (r, t, x, u, v) -> (r[1] = x[2]; nothing))
CTModels.dynamics!(pre, 2:2, (r, t, x, u, v) -> (r[1] = u[1]; nothing))
```

The ranges must **tile** `1:n` without overlap; mixing the full form and the block form, or
leaving a gap, raises an `Exceptions.PreconditionError`. The completeness check is
[`__is_dynamics_complete`](@ref CTModels.Building.__is_dynamics_complete), run by `build`.

## Objective

[`objective!`](@ref CTModels.Building.objective!) takes the optimisation direction
(`:min` or `:max`) and one or both of a **Mayer** term and a **Lagrange** term. The three
combinations map to the three objective types of
[Types and traits](types_and_traits.md):

| Provided | Cost | Objective type |
|---|---|---|
| `lagrange` | ``\int_{t_0}^{t_f} f^0\,\mathrm{d}t`` | [`LagrangeObjectiveModel`](@ref CTModels.Components.LagrangeObjectiveModel) |
| `mayer` | ``g(x(t_0), x(t_f), v)`` | [`MayerObjectiveModel`](@ref CTModels.Components.MayerObjectiveModel) |
| both | Bolza: ``g + \int f^0`` | [`BolzaObjectiveModel`](@ref CTModels.Components.BolzaObjectiveModel) |

The Lagrange integrand has signature `f⁰(t, x, u, v)`; the Mayer term `g(x0, xf, v)`.

```@example dynobj
pre = fresh()
CTModels.dynamics!(pre, f!)
CTModels.objective!(pre, :min;
    mayer    = (x0, xf, v) -> xf[1]^2,
    lagrange = (t, x, u, v) -> u[1]^2,
)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
nothing # hide
```

```@repl dynobj
CTModels.criterion(ocp)
CTModels.has_mayer_cost(ocp)
CTModels.has_lagrange_cost(ocp)
```

Because the cost is stored as a typed object, downstream code dispatches on it (Mayer /
Lagrange / Bolza) instead of inspecting closures — see the
[Solutions](../solution/overview.md) guide for how the objective **value** is read back.

## Error cases

Calling `dynamics!` before the state is set raises a `PreconditionError`:

```@example dynobj
pre_no_state = CTModels.PreModel()
CTModels.time!(pre_no_state; t0=0.0, tf=1.0)
nothing # hide
```

```@repl dynobj
try # hide
CTModels.dynamics!(pre_no_state, (r, t, x, u, v) -> (r[1] = 0.0; nothing))
catch e # hide
showerror(IOContext(stdout, :color => false), e) # hide
end # hide
```

In block form, overlapping ranges raise a `PreconditionError` immediately:

```@example dynobj
pre_overlap = fresh()
CTModels.dynamics!(pre_overlap, 1:1, (r, t, x, u, v) -> (r[1] = x[2]; nothing))
nothing # hide
```

```@repl dynobj
try # hide
CTModels.dynamics!(pre_overlap, 1:2, (r, t, x, u, v) -> (r[1] = x[1]; nothing))  # overlaps 1:1
catch e # hide
showerror(IOContext(stdout, :color => false), e) # hide
end # hide
```
