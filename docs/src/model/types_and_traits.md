# Types and traits

```@meta
CurrentModule = CTModels
```

This page explains the **type architecture** of the [`CTModels.OCP`](@ref CTModels.OCP)
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
| [`AbstractStateModel`](@ref CTModels.OCP.AbstractStateModel) | [`StateModel`](@ref CTModels.OCP.StateModel) | [`StateModelSolution`](@ref CTModels.OCP.StateModelSolution) | — |
| [`AbstractControlModel`](@ref CTModels.OCP.AbstractControlModel) | [`ControlModel`](@ref CTModels.OCP.ControlModel) | [`ControlModelSolution`](@ref CTModels.OCP.ControlModelSolution) | [`EmptyControlModel`](@ref CTModels.OCP.EmptyControlModel) |
| [`AbstractVariableModel`](@ref CTModels.OCP.AbstractVariableModel) | [`VariableModel`](@ref CTModels.OCP.VariableModel) | [`VariableModelSolution`](@ref CTModels.OCP.VariableModelSolution) | [`EmptyVariableModel`](@ref CTModels.OCP.EmptyVariableModel) |
| [`AbstractTimeModel`](@ref CTModels.OCP.AbstractTimeModel) | [`FixedTimeModel`](@ref CTModels.OCP.FixedTimeModel) / [`FreeTimeModel`](@ref CTModels.OCP.FreeTimeModel) | — | — |
| [`AbstractObjectiveModel`](@ref CTModels.OCP.AbstractObjectiveModel) | [`MayerObjectiveModel`](@ref CTModels.OCP.MayerObjectiveModel) / [`LagrangeObjectiveModel`](@ref CTModels.OCP.LagrangeObjectiveModel) / [`BolzaObjectiveModel`](@ref CTModels.OCP.BolzaObjectiveModel) | — | — |
| [`AbstractDefinition`](@ref CTModels.OCP.AbstractDefinition) | [`Definition`](@ref CTModels.OCP.Definition) | — | [`EmptyDefinition`](@ref CTModels.OCP.EmptyDefinition) |

The **empty sentinel** lets dispatch stay total: a control-free problem carries an
`EmptyControlModel` rather than a `nothing`, so accessors like
[`control_dimension`](@ref CTModels.OCP.control_dimension) return `0` without a special case.

```@example types
using CTModels

sm  = CTModels.StateModel("x", ["x₁", "x₂"])
evm = CTModels.EmptyVariableModel()

(CTModels.dimension(sm), CTModels.name(sm), evm isa CTModels.OCP.AbstractVariableModel)
```

## The two trait axes

Two orthogonal yes/no axes are **not** modelled as separate types but as traits.

### Time dependence

[`TimeDependence`](@ref CTModels.OCP.TimeDependence) has the two values
[`Autonomous`](@ref CTModels.OCP.Autonomous) and
[`NonAutonomous`](@ref CTModels.OCP.NonAutonomous). It is carried as the **first type
parameter** of [`Model`](@ref CTModels.OCP.Model), so the distinction between
``\dot{x} = f(x,u)`` and ``\dot{x} = f(t,x,u)`` is available at compile time. The extractor
is [`is_autonomous`](@ref CTModels.OCP.is_autonomous):

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

CTModels.is_autonomous(ocp)
```

### Time structure

Whether each end of the interval is fixed or free is the **type** of the corresponding
[`AbstractTimeModel`](@ref CTModels.OCP.AbstractTimeModel) inside the
[`TimesModel`](@ref CTModels.OCP.TimesModel). The extractors read the structure without
exposing the concrete type:

| Question | Extractor |
|---|---|
| Is ``t_0`` fixed / free? | [`has_fixed_initial_time`](@ref CTModels.OCP.has_fixed_initial_time) / [`has_free_initial_time`](@ref CTModels.OCP.has_free_initial_time) |
| Is ``t_f`` fixed / free? | [`has_fixed_final_time`](@ref CTModels.OCP.has_fixed_final_time) / [`has_free_final_time`](@ref CTModels.OCP.has_free_final_time) |

```@example types
(CTModels.has_fixed_initial_time(ocp), CTModels.has_fixed_final_time(ocp))
```

A [`FreeTimeModel`](@ref CTModels.OCP.FreeTimeModel) stores the **index** into the
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

This mirrors the ecosystem-wide design described in the package philosophy
(`dev/philosophy/types-traits-interfaces.md`).
