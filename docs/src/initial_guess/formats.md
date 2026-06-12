# Input formats

```@meta
CurrentModule = CTModels
```

Each component of an initial guess (state, control, variable) accepts several shapes. CTModels
normalises them all to a **callable of time**, so the rest of the stack sees one interface.

| Per-component input | Interpreted as |
|---|---|
| a function `t -> …` | used directly |
| a vector `[a, b, …]` | the constant trajectory `t -> [a, b, …]` |
| a scalar (dim-1 component) | the constant trajectory `t -> [a]` |
| `nothing` | a built-in default |

```@example fmt
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
nothing # hide
```

## Functions

The most general form — a time-varying guess:

```@example fmt
init = CTModels.build_initial_guess(ocp,
    (state = t -> [cos(t), -sin(t)], control = t -> [0.5 * t]))
(init.state(0.0), init.state(1.0), init.control(1.0))
```

## Constants

A vector (or a scalar for a one-dimensional component) is broadcast to a **constant**
trajectory:

```@example fmt
init = CTModels.build_initial_guess(ocp, (state = [0.0, 1.0], control = 0.1))
(init.state(0.0), init.state(0.9), init.control(0.5))   # constant in time
```

## Defaults

Omitting a component (or passing `nothing` / `()`) yields the built-in default guess, sized to
the problem:

```@example fmt
init = CTModels.build_initial_guess(ocp, ())
(init.state(0.5), init.control(0.5))
```

## Pre-initialisation

[`pre_initial_guess`](@ref CTModels.Init.pre_initial_guess) packages raw, **model-independent**
data into a [`PreInitialGuess`](@ref CTModels.Init.PreInitialGuess); the model is only needed
later when [`build_initial_guess`](@ref CTModels.Init.build_initial_guess) validates it:

```@example fmt
pre_ig = CTModels.pre_initial_guess(state = t -> [0.0, 0.0], control = t -> [1.0])
init   = CTModels.build_initial_guess(ocp, pre_ig)
init.control(0.25)
```

How the dimensions are checked, and how to warm-start from a previous solution, is covered in
[Validation & warm-start](validation.md).
