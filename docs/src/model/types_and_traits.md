# Types and traits

```@meta
CurrentModule = CTModels
```

This page explains the **type architecture** of the CTModels OCP layer
submodule, following the package tenet:

!!! note "One abstract type per *noun*, one trait-parameter per *axis*"

    Conceptual variants ("is this a state model or a control model?") are encoded as
    **types**. Orthogonal yes/no axes ("autonomous?", "free final time?") are encoded as
    **traits** carried in a type parameter, and selected by dispatch through an extractor.

## Noun families

Each *noun* of an OCP has one abstract supertype and a small family of concrete subtypes.
The pattern is uniform: a *definition* type (structure only) and a *solution* type
(structure + a numerical value), plus an *empty* sentinel where a component may be absent.

| Abstract type | Definition | Solution | Empty sentinel |
|---|---|---|---|
| [`AbstractStateModel`](@ref CTModels.Components.AbstractStateModel) | [`StateModel`](@ref CTModels.Components.StateModel) | [`StateModelSolution`](@ref CTModels.Components.StateModelSolution) | — |
| [`AbstractControlModel`](@ref CTModels.Components.AbstractControlModel) | [`ControlModel`](@ref CTModels.Components.ControlModel) | [`ControlModelSolution`](@ref CTModels.Components.ControlModelSolution) | [`EmptyControlModel`](@ref CTModels.Components.EmptyControlModel) |
| [`AbstractVariableModel`](@ref CTModels.Components.AbstractVariableModel) | [`VariableModel`](@ref CTModels.Components.VariableModel) | [`VariableModelSolution`](@ref CTModels.Components.VariableModelSolution) | [`EmptyVariableModel`](@ref CTModels.Components.EmptyVariableModel) |
| [`AbstractTimeModel`](@ref CTModels.Components.AbstractTimeModel) | [`FixedTimeModel`](@ref CTModels.Components.FixedTimeModel) / [`FreeTimeModel`](@ref CTModels.Components.FreeTimeModel) | — | — |
| [`AbstractObjectiveModel`](@ref CTModels.Components.AbstractObjectiveModel) | [`MayerObjectiveModel`](@ref CTModels.Components.MayerObjectiveModel) / [`LagrangeObjectiveModel`](@ref CTModels.Components.LagrangeObjectiveModel) / [`BolzaObjectiveModel`](@ref CTModels.Components.BolzaObjectiveModel) | — | — |
| [`AbstractDefinition`](@ref CTModels.Components.AbstractDefinition) | [`Definition`](@ref CTModels.Components.Definition) | — | [`EmptyDefinition`](@ref CTModels.Components.EmptyDefinition) |

The **empty sentinel** lets dispatch stay total: a control-free problem carries an
`EmptyControlModel` rather than a `nothing`, so accessors like
[`control_dimension`](@ref CTModels.Models.control_dimension) return `0` without a special case.

```@example types
using CTModels

sm  = CTModels.StateModel("x", ["x₁", "x₂"])
evm = CTModels.EmptyVariableModel()
nothing # hide
```

```@repl types
CTModels.dimension(sm)
CTModels.name(sm)
evm isa CTModels.Components.AbstractVariableModel
```

## The trait axes

Orthogonal yes/no axes are **not** modelled as separate types but as traits.

### Time dependence

`TimeDependence` has the two values `Autonomous` and `NonAutonomous`. It is carried as the **first type
parameter** of [`Model`](@ref CTModels.Models.Model), so the distinction between
``\dot{x} = f(x,u)`` and ``\dot{x} = f(t,x,u)`` is available at compile time. The extractor is `is_autonomous`:

```@example types
pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 1)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
nothing # hide
```

```@repl types
CTModels.is_autonomous(ocp)
```

### Control dependence

Whether the problem carries a control input is the **type** of the
[`AbstractControlModel`](@ref CTModels.Components.AbstractControlModel) inside the
[`Model`](@ref CTModels.Models.Model): an
[`EmptyControlModel`](@ref CTModels.Components.EmptyControlModel) means *control-free*, any
other control model means *with control*. This is exposed through the
`CTBase.Traits.ControlDependence` axis (values `ControlFree` / `WithControl`), shared
ecosystem-wide, with the extractors `is_control_free` and `has_control`:

```@repl types
CTModels.is_control_free(ocp)
CTModels.has_control(ocp)
```

Like time dependence, the predicates are generic functions owned by `CTBase.Traits`; the
`Model` only declares the trait and reports its value (read from the control model type, not
from the control dimension).

### Time structure

Whether each end of the interval is fixed or free is the **type** of the corresponding
[`AbstractTimeModel`](@ref CTModels.Components.AbstractTimeModel) inside the
[`TimesModel`](@ref CTModels.Components.TimesModel). The extractors read the structure without
exposing the concrete type:

| Question | Extractor |
|---|---|
| Is ``t_0`` fixed / free? | [`has_fixed_initial_time`](@ref CTModels.Components.has_fixed_initial_time) / [`has_free_initial_time`](@ref CTModels.Components.has_free_initial_time) |
| Is ``t_f`` fixed / free? | [`has_fixed_final_time`](@ref CTModels.Components.has_fixed_final_time) / [`has_free_final_time`](@ref CTModels.Components.has_free_final_time) |

```@repl types
CTModels.has_fixed_initial_time(ocp)
CTModels.has_fixed_final_time(ocp)
```

A [`FreeTimeModel`](@ref CTModels.Components.FreeTimeModel) stores the **index** into the
optimisation variable ``v`` where the free time lives, rather than a value — see
[Components](components.md).

## Why traits, not twin types

Modelling "autonomous vs non-autonomous" as two unrelated `Model` types would duplicate every
method and break as soon as a third axis appears (the combinatorial explosion of
2 × 2 × … types). Keeping each axis a trait-parameter means:

- methods are written once on the abstract type and **dispatch only where the axis matters**;
- adding an axis adds a parameter, not a new type hierarchy;
- the public surface stays the *nouns* (`StateModel`, `Model`, …) and the *extractors*
  (`is_autonomous`, `has_free_final_time`), never the raw parameters.

This mirrors the ecosystem-wide design described in the
[control-toolbox Handbook](https://github.com/control-toolbox/Handbook/blob/main/PHILOSOPHY.md).
