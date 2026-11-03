# Plotting

```@meta
CurrentModule = CTModels
```

```@setup plt
using Plots
using CairoMakie: CairoMakie, Makie
```

When `Plots` is loaded, the `CTModelsPlots` extension adds a recipe so a
[`Solution`](@ref CTModels.Solutions.Solution) can be drawn directly with `plot` / `plot!`. The
recipe lays out the state, control, costate (and, when present, path constraints and their
duals) on a shared time axis.

```@example plt
using CTModels
using Plots      # activates the CTModelsPlots extension

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)
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

## Default plot

```@example plt
Plots.plot(sol)
```

## Choosing what to draw

Positional symbols after the solution select the groups to draw, among `:state`,
`:costate`, `:control`, `:path` (path constraints) and `:dual` (their multipliers). Without
any, a default set is chosen from the problem:

```@example plt
Plots.plot(sol, :state, :control)
```

## Constraints and their duals

The bottom of the `:split` figure has **one row per constraint label** — a path constraint,
a state box or a control box — pairing the constraint (left) with its dual (right):

```text
 x₁ │ p₁
 x₂ │ p₂
 ───┴───
   u₁            ← control, full width
 ───┬───
 c₁           │ μ₁   ← path constraint │ its dual
 x₂ (x2_box)  │      ← state box: x₂(t) with its bounds │ its dual
 u (u_box)    │      ← control box
```

As for the state | costate pair, the left cell carries the name and the paired right cell
none; a box is named by its component and its label, `x₂ (x2_box)`.

A box is drawn like a path constraint because its dual follows the same sign convention
(ct-conventions `SGN5`): the pair makes the complementarity visible — the component
touches a bound exactly where the dual is nonzero. For a component with two bounds, the
dual is the signed `zU − zL`: negative at the lower bound, positive at the upper one. Both
bounds are drawn on the left cell.

```@example plt
pre_box = CTModels.PreModel()
CTModels.variable!(pre_box, 0)
CTModels.time!(pre_box; t0=0.0, tf=1.0)
CTModels.state!(pre_box, 2)
CTModels.control!(pre_box, 1)
CTModels.dynamics!(pre_box, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
CTModels.objective!(pre_box, :min; lagrange=(t, x, u, v) -> u^2)
CTModels.constraint!(pre_box, :path; f=(r, t, x, u, v) -> (r[1] = x[1] + x[2]; nothing),
    lb=[-Inf], ub=[3.0], label=:c1)
CTModels.constraint!(pre_box, :state; rg=2:2, lb=[-0.5], ub=[2.0], label=:x2_box)
CTModels.constraint!(pre_box, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box)
CTModels.time_dependence!(pre_box; autonomous=true)
ocp_box = CTModels.build(pre_box)

M = 51
Tb = collect(range(0.0, 1.0; length=M))
sol_box = CTModels.build_solution(ocp_box, Tb, hcat(Tb .^ 2, 2Tb), reshape(1 .- Tb, M, 1),
    Float64[], hcat(1 .- Tb, -Tb);
    objective=1 / 3, successful=true,
    duals=Dict(:c1 => Tb),
    state_constraints_lb_dual=hcat(zeros(M), max.(0.0, 1 .- 4Tb)),
    state_constraints_ub_dual=hcat(zeros(M), max.(0.0, 4Tb .- 3)),
    control_constraints_lb_dual=reshape(max.(0.0, 0.5 .- Tb), M, 1),
    control_constraints_ub_dual=zeros(M, 1))
Plots.plot(sol_box)
```

The selection stays `:path` and `:dual`:

- `:path` draws the left cells — the path constraints;
- `:dual` draws the right cells — the dual of every path constraint and every box whose
  dual the solution knows (`has_dual`, see [Duals & diagnostics](../solution/duals.md));
- a box is a pair: its left cell is drawn when both `:path` and `:dual` are requested
  (otherwise it would only repeat the component of the state or control panel), so
  `plot(sol, :path)` shows the path constraints only, as before; and a box whose dual is
  unknown has no row;
- when some rows have their dual and others not, the rows without one keep an empty right
  cell marked *dual not known*, so that the time axes of the block stay aligned;
- the dual of a control box is drawn as steps when the control is piecewise constant, like
  its component on the left;
- several labels may bound one component (a second declaration is an alias of the first,
  see [Constraints](../model/constraints.md)): each label has its row;
- `path_style` and `dual_style` style the two sides, `state_bounds_style` and
  `control_bounds_style` the bounds of the box rows.

Box duals of the *variable* are not plotted (they do not depend on time); they stay in the
text display of the solution. The `:group` layout does not draw path constraints nor
duals.

## Layout and control options

| Keyword | Values (default first) | Effect |
| --- | --- | --- |
| `layout` | `:split` / `:group` | one subplot per component, or one subplot per group with a legend |
| `control` | `:components` / `:norm` / `:all` | a curve per control component, the norm ``\lVert u(t) \rVert``, or both |
| `time` | `:default` / `:normalize` | physical time, or rescaled to ``[0, 1]`` |
| `color`, `size` | | colour of every curve, figure size |

```@example plt
Plots.plot(sol; layout=:group, control=:all)
```

Each group and decoration also takes a style keyword, a `NamedTuple` of plotting
attributes or `:none` to hide it: `state_style`, `costate_style`, `control_style`,
`path_style`, `dual_style`, `time_style` (initial and final time markers), and the bound
decorations `state_bounds_style`, `control_bounds_style`, `path_bounds_style`.

```@example plt
Plots.plot(sol; state_style=(color=:blue,), costate_style=:none)
```

## Switching times and phase labels

A solution with a switching structure (see [Switching structure](../solution/switching.md))
draws each jump as a vertical segment, marks each switching time with a vertical line
(`switching_style`, by default like the time markers; `:none` hides them) and writes the
phase labels on the control cell (`phase_labels = :control`, `:all` or `:none`;
`phase_labels_style` for their style). With `jumps = :none`, the curve is broken between
the two limits instead of drawing the vertical segment.

## Overlaying solutions

`plot!` adds a solution to an existing figure — handy for comparing two solves on the same
axes:

```@example plt
plt = Plots.plot(sol)
Plots.plot!(plt, sol; time=:normalize)
plt
```

Because the recipe reads the *typed* solution (its time grids, interpolation kind, and dual
structure) rather than raw arrays, the same call works for unified- and multiple-grid
solutions alike — see [Time grids](../solution/time_grids.md).

## Makie backend

A second backend renders the same figure with [Makie.jl](https://docs.makie.org),
at feature parity with the Plots backend (reference lines, step controls, overlay
and forwarded attributes all supported). Load a Makie backend package
(`CairoMakie`, `GLMakie`, …); the `CTModelsMakie` extension then provides
`Makie.plot(sol)`, returning a `Makie.Figure`:

```@example plt
Makie.plot(sol)
```

```@example plt
Makie.plot(sol; layout=:group, control=:all)
```

`Makie.plot!` overlays onto an existing figure, the same way `Plots.plot!` does:

```@example plt
f = Makie.plot(sol)
Makie.plot!(f, sol; time=:normalize)
f
```

The positional group symbols and the keyword arguments (`layout`, `control`, `time`, the
`*_style` keywords, `color`, `size`) are identical to the Plots backend. When both
`Plots` and a Makie package are loaded, `plot` must be qualified —
`Plots.plot(sol)` renders with Plots, `Makie.plot(sol)` with Makie.

Style keywords beyond the neutral vocabulary (`color`, `linewidth`, `linestyle`,
`alpha`, `seriestype`) are resolved per backend: the Plots backend forwards any
attribute Plots recognises, while the Makie backend only forwards a fixed whitelist
and drops the rest. See the *Plotting Engine* guide in the CTBase documentation
("User Attributes: Series vs Axis") for the exact rule.
