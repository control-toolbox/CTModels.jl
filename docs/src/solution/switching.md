# Switching structure

```@meta
CurrentModule = CTModels
```

```@setup sw
using Plots
```

An indirect method fixes the **structure** of the solution: the times at which the control
law changes, the jumps of the state or costate at these times, the sequence of arcs
(`bang`, `singular`, `boundary`, …). A direct method does not: it returns values on a
grid. A [`Solution`](@ref CTModels.Solutions.Solution) keeps this structure in a
[`SwitchingModel`](@ref CTModels.Solutions.SwitchingModel), given to
[`build_solution`](@ref CTModels.Solutions.build_solution) with the `switching` keyword:

- the switching times, strictly inside the time span;
- one label per phase (`""` for a phase with no label);
- the left and right limits of the state, costate and control at every switching time.

The trajectories of the solution stay single-valued and **left-continuous**: at a switching
time, `state(sol)(tᵢ)` returns the value before the jump. The value after it is read with
[`right_limit`](@ref CTModels.Solutions.right_limit).

## A solution with a jump

The state below jumps by `+1` at `t = 0.5`, where the control switches from `1` to `-1`:

```@example sw
using CTModels

pre = CTModels.PreModel()
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 1)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)

τ = 0.5
T = collect(range(0.0, 1.0; length=11))
X = reshape([t <= τ ? t : t + 1 for t in T], :, 1)
U = reshape([t <= τ ? 1.0 : -1.0 for t in T], :, 1)
P = zeros(length(T), 1)

switching = CTModels.SwitchingModel(;
    times=[τ],
    labels=["bang+", "bang-"],
    state=([τ;;], [τ + 1;;]),        # (left, right), one row per switching time
    costate=([0.0;;], [0.0;;]),
    control=([1.0;;], [-1.0;;]),
)
sol = CTModels.build_solution(ocp, T, X, U, Float64[], P;
    objective=0.0, successful=true, control_interpolation=:linear, switching=switching)
```

The display lists the switching times and the sequence of phases; an unlabelled phase shows
as `·`.

## Reading the structure

```@repl sw
CTModels.switching_times(sol)
CTModels.phase_labels(sol)
CTModels.state(sol)(τ)                    # left-continuous: before the jump
CTModels.right_limit(sol, :state, 1)      # after the jump
CTModels.left_limit(sol, :control, 1), CTModels.right_limit(sol, :control, 1)
```

A one-dimensional component is a scalar, as everywhere in CTModels.

When the trajectories are given as matrices, the interpolation uses the limits, so that the
jump is not smeared over the grid cell that follows it:

```@repl sw
CTModels.state(sol)(0.55)                 # between the right limit 1.5 and x(0.6) = 1.6
```

Trajectories given as functions are used as they are.

## Plotting

Each jump is drawn as a vertical segment, from the left to the right limit; a vertical line
marks each switching time, with the look of the initial and final time markers; the phase
labels are written on the control cell:

```@example sw
plot(sol)
```

| Keyword | Values (default first) | Effect |
| --- | --- | --- |
| `switching_style` | `NamedTuple()` / a `NamedTuple` / `:none` | style of the switching-time lines, merged on the time markers' style; `:none` hides them |
| `phase_labels` | `:control` / `:all` / `:none` | write the labels on the control cell (or on the first drawn group when the control is not drawn), on every group, or nowhere |
| `phase_labels_style` | `NamedTuple()` | `color`, `fontsize`, `halign`, `valign` of the labels |

```@example sw
plot(sol; switching_style=(color=:red,), phase_labels=:all)
```

## Saving and loading

[`export_ocp_solution`](@ref CTModels.Serialization.export_ocp_solution) writes the
switching structure with the solution (JLD2 and JSON), and
[`import_ocp_solution`](@ref CTModels.Serialization.import_ocp_solution) reads it back, so the
imported trajectories keep their jumps. A file without switching structure, including a file
written by an older version, is read with an
[`EmptySwitchingModel`](@ref CTModels.Solutions.EmptySwitchingModel).

## Time grids have no repeated time

A trajectory takes one value at each time: a time grid with a repeated time raises an
`IncorrectArgument`. A jump is stored in the switching model, not as a repeated time with two
values.

```@repl sw
CTModels.build_solution(ocp, [0.0, 0.5, 0.5, 1.0], zeros(4, 1), zeros(4, 1), Float64[],
    zeros(4, 1); objective=0.0, successful=true)
```
