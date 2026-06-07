# Building a model

```@meta
CurrentModule = CTModels
```

[`build`](@ref CTModels.OCP.build) turns a fully-declared, mutable
[`PreModel`](@ref CTModels.OCP.PreModel) into an **immutable**
[`Model`](@ref CTModels.OCP.Model). `build_model` is an alias of `build`.

## Prerequisites

Before building, the pre-model must be **consistent**: times, state, complete dynamics,
objective and the time-dependence flag must all be set. The check is
[`__is_consistent`](@ref CTModels.OCP.__is_consistent); `build` raises a structured error if
a piece is missing. Control and variable are optional — their absence is represented by the
[`EmptyControlModel`](@ref CTModels.OCP.EmptyControlModel) /
[`EmptyVariableModel`](@ref CTModels.OCP.EmptyVariableModel) sentinels.

Two extra declarations complete the problem:

- [`time_dependence!`](@ref CTModels.OCP.time_dependence!) — marks the system
  `autonomous=true|false` (sets the [`TimeDependence`](@ref CTModels.OCP.TimeDependence) trait);
- [`definition!`](@ref CTModels.OCP.definition!) — *optional* — attaches the symbolic
  problem definition (a Julia `Expr`) as a [`Definition`](@ref CTModels.OCP.Definition);
  without it the model carries an [`EmptyDefinition`](@ref CTModels.OCP.EmptyDefinition).

```@example building
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
```

## What a built `Model` guarantees

Building freezes the structure and exposes it through accessors. Because every component is
a concrete typed field, queries are type-stable and need no closure inspection:

```@example building
(CTModels.state_dimension(ocp),
 CTModels.control_dimension(ocp),
 CTModels.variable_dimension(ocp),
 CTModels.initial_time(ocp),
 CTModels.final_time(ocp),
 CTModels.is_autonomous(ocp),
 CTModels.has_lagrange_cost(ocp))
```

Missing a required piece is caught at build time:

```@example building
incomplete = CTModels.PreModel()
CTModels.state!(incomplete, 1)
try
    CTModels.build(incomplete)        # no times, dynamics, objective…
catch e
    typeof(e)
end
```

## Where `build` sits in the pipeline

```
PreModel ──validate──► consistent? ──freeze──► Model
   │                       │                      │
state!/…              __is_consistent        immutable, typed
time_dependence!      name uniqueness        accessor surface
definition! (opt.)    dynamics complete
```

The immutable `Model` is the object every downstream package consumes: it is the input to
[Solutions](../solution/index.md), [Initial guesses](../initial_guess/index.md) and
[Serialization](../serialization/index.md).
```
