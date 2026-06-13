# Components

```@meta
CurrentModule = CTModels
```

The four declaration verbs populate the spaces of the problem on a
[`PreModel`](@ref CTModels.Building.PreModel). Each may be called **once**; calling it twice, or
with inconsistent dimensions, raises a structured exception.

| Verb | Declares | Stores into `pre.…` |
|---|---|---|
| [`state!`](@ref CTModels.Building.state!) | state space ``x \in \mathbb{R}^n`` | `pre.state` |
| [`control!`](@ref CTModels.Building.control!) | control space ``u \in \mathbb{R}^m`` | `pre.control` |
| [`variable!`](@ref CTModels.Building.variable!) | optimisation variable ``v \in \mathbb{R}^q`` | `pre.variable` |
| [`time!`](@ref CTModels.Building.time!) | the interval ``[t_0, t_f]`` | `pre.times` |

```@example components
using CTModels
import CTBase
pre = CTModels.PreModel()
nothing # hide
```

## Dimension, name and components

A space has a **dimension**, a **display name**, and per-**component** names. Omitted names
are generated (`"x"`, then `"x₁", "x₂", …`). Each declaration accepts `String` or `Symbol`.

```@example components
CTModels.state!(pre, 2, "x", ["q", "w"])

(CTModels.dimension(pre.state),   # 2
 CTModels.name(pre.state),        # "x"
 CTModels.components(pre.state))  # ["q", "w"]
```

```@example components
CTModels.control!(pre, 1)                 # default name "u"
CTModels.components(pre.control)
```

## The optimisation variable

[`variable!`](@ref CTModels.Building.variable!) declares the time-independent decision variable
``v`` (free final time, design parameters, …). A dimension of `0` means *no variable*:
`pre.variable` then stays an [`EmptyVariableModel`](@ref CTModels.Components.EmptyVariableModel).

```@example components
CTModels.variable!(pre, 2, "v")
(CTModels.dimension(pre.variable), CTModels.components(pre.variable))
```

## Time: fixed and free ends

[`time!`](@ref CTModels.Building.time!) sets the interval. Each end is either **fixed** (a value
`t0=`/`tf=`) or **free** (an index `ind0=`/`indf=` into ``v``, optimised by the solver).

```@example components
CTModels.time!(pre; t0=0.0, tf=1.0)        # both ends fixed
(CTModels.time_name(pre.times),
 CTModels.has_fixed_initial_time(pre.times),
 CTModels.has_fixed_final_time(pre.times))
```

A **free final time** stored at index `2` of ``v`` (declared above with dimension 2):

```@example components
pre2 = CTModels.PreModel()
CTModels.variable!(pre2, 2, "v")
CTModels.time!(pre2; t0=0.0, indf=2)
(CTModels.has_free_final_time(pre2.times), CTModels.final_time(pre2.times, [0.0, 1.5]))
```

For a free time the value is read from ``v``, hence
[`final_time`](@ref CTModels.Components.final_time) takes the variable vector. See
[Types and traits](types_and_traits.md) for the `Fixed`/`Free` distinction.

## Naming rules

Names must be **unique across all components** of the problem. The validation
([`OCP/Validation/`](building.md)) rejects empty names, duplicates within a declaration, and
collisions with names already declared elsewhere:

```@example components
pre3 = CTModels.PreModel()
CTModels.state!(pre3, 2, "x", ["a", "b"])
try
    CTModels.control!(pre3, 1, "a")   # "a" already names a state component
catch e
    e isa CTBase.Exceptions.IncorrectArgument
end
```

These rules guarantee that a label like `:a` resolves unambiguously to one component when
reading a solution or a constraint.
