# Initial guesses

```@meta
CurrentModule = CTModels
```

The [`CTModels.Init`](@ref CTModels.Init) submodule builds **initial guesses** — starting
trajectories for state, control and variable that warm-start a numerical solver. A good guess
is often decisive on hard problems.

`Init` separates *construction* from *validation* through a small pipeline:

```
raw data ──► pre_initial_guess / initial_guess ──► InitialGuess (unvalidated)
                                                          │
                                          validate_initial_guess (against the model)
                                                          ▼
                                                 InitialGuess (validated)
```

[`build_initial_guess`](@ref CTModels.Init.build_initial_guess) is the **single entry point**
that does both: it accepts many input formats, converts them, and validates dimensions against
the [`Model`](@ref CTModels.OCP.Model).

## Reading order

| Page | Topic | Key symbols |
|---|---|---|
| [Input formats](formats.md) | What you can pass per component | [`initial_guess`](@ref CTModels.Init.initial_guess), [`pre_initial_guess`](@ref CTModels.Init.pre_initial_guess) |
| [Validation & warm-start](validation.md) | Dimension checks and reuse | [`build_initial_guess`](@ref CTModels.Init.build_initial_guess), [`validate_initial_guess`](@ref CTModels.Init.validate_initial_guess) |

## Accepted inputs to `build_initial_guess`

| Input | Meaning |
|---|---|
| `nothing` / `()` | default guess |
| [`InitialGuess`](@ref CTModels.Init.InitialGuess) | validated as-is |
| [`PreInitialGuess`](@ref CTModels.Init.PreInitialGuess) | converted, then validated |
| [`Solution`](@ref CTModels.OCP.Solution) | warm-start from a previous solve |
| `NamedTuple` | `(state=…, control=…, variable=…)` |

## Minimal example

```@example init_index
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

init = CTModels.build_initial_guess(ocp, (state=t -> [0.0, 0.0], control=t -> [0.1]))
```

The result is a validated [`InitialGuess`](@ref CTModels.Init.InitialGuess) whose components
are callables of time:

```@example init_index
(init.state(0.5), init.control(0.5))
```
```
