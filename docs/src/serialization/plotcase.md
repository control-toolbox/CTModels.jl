# Plotting architecture

```@meta
CurrentModule = CTModels
```

This page is for contributors who change what the solution figure contains. To *use* the
plots, see [Plotting](plotting.md).

## Three layers

The figure is described once, independently of any plotting package, and rendered by two
thin backends:

```text
Solution ── CTModels.PlotCase.build_figure ──► CTBase.Plotting.Figure ──► render
             (core, no plotting dependency)     (backend-free IR)          │
                                                                           ├─ CTModelsPlots → Plots.Plot
                                                                           └─ CTModelsMakie → Makie.Figure
```

- **`CTModels.PlotCase`** (core module) knows optimal control: which groups exist (state,
  costate, control, path constraints, duals), how to sample them from a `Solution`, which
  reference lines to add (box bounds, initial and final times), and how to arrange the
  panels for `layout=:split` and `layout=:group`. It has no dependency on Plots or Makie.
- **`CTBase.Plotting`** owns the figure IR (`Figure`, panels, layout nodes) and its
  renderers, shared by every control-toolbox package that plots. See the *Plotting
  Engine* guide of the [CTBase documentation](https://control-toolbox.org/CTBase.jl).
- **`CTModelsPlots` / `CTModelsMakie`** (extensions) only add the `Plots.plot` /
  `Makie.plot` methods: they split the keywords, call
  [`build_figure`](@ref CTModels.PlotCase.build_figure), and pass the result to the
  `PlotsBackend` or `MakieBackend` renderer.

Because both backends render the same IR, they stay at feature parity by construction: a
new panel or decoration added in `PlotCase` appears in both.

## Building a figure without a backend

[`build_figure`](@ref CTModels.PlotCase.build_figure) is callable from the core, which
makes the content of a figure testable without loading a plotting package:

```@example pc
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)
CTModels.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)

N = 21
T = collect(range(0.0, 1.0; length=N))
sol = CTModels.build_solution(ocp, T, hcat(T, ones(N)), ones(N, 1), Float64[], zeros(N, 2);
    objective=1.0, successful=true)

fig = CTModels.PlotCase.build_figure(sol, :state, :control; layout=:group)
nothing # hide
```

```@repl pc
typeof(fig)
```

## What is plotted

`build_figure` draws up to five groups, selected by the description symbols (`:state`,
`:costate`, `:control`, `:path`, `:dual`) and hidden by a `*_style=:none` keyword. In
`layout=:split`, they are arranged in three blocks:

```text
(state | costate)          one cell per component, paired column by column
control                    full width
constraint rows            one row per constraint label: (constraint | dual)
```

`layout=:group` draws the state, the costate and the control only: one cell per group, with
a legend. The path constraints and the duals have no `:group` cell.

### The constraint rows

The third block is built from `ConstraintRow`s, listed
by `_constraint_rows(sol, model)` in `src/PlotCase/rows.jl`. A row is one constraint
label, and its two sides are drawn from the same row:

| `kind` | left (`:path`) | right (`:dual`) | row exists |
| --- | --- | --- | --- |
| `:path` | the rows of the path constraint, `g(t, x, u, v)`, with its bounds | `dual(sol, model, label)` | always (the right side needs `row.dual`) |
| `:state` | the bounded components of the state, with the bounds of the box | `dual(sol, model, label)` | the dual is known |
| `:control` | the bounded components of the control, with the bounds of the box | `dual(sol, model, label)` | the dual is known |

- **Order**: path constraints, then state boxes, then control boxes, each in declaration
  order. The built model does not keep the order between kinds.
- **Not plotted**: boundary constraints and variable boxes (their duals do not depend on
  time), and a box whose dual is unknown (the mask of `has_dual`).
- **One row per label**: a label that bounds several components (a vector box, a
  multi-row path constraint) is one row whose cells are as numerous as its components.
- **The dual of a box** is a single signed curve per component, `zU − zL` for two bounds
  (ct-conventions `SGN2`, `SGN3`); `Solutions.dual` builds it, the plot only samples it.
- **Grids**: each side carries its own grid — the path grid for a path constraint, the
  state or control grid for a box — as every `Panel` does.
- **Gating**: `do_plot` (`src/PlotCase/vocabulary.jl`) sets the `path` and `dual` flags
  from the rows: `:dual` needs at least one dual to draw, `:path` needs a path constraint,
  or a box row when `:dual` is requested. The `:split` branch of `_build_root`
  (`src/PlotCase/build.jl`) then draws each row's left side if `:path` is on (and, for a
  box, `:dual` too) and its right side if `:dual` is on and `row.dual`.
- **Titles and labels**: the first row carries the titles and the phase labels, the last
  one the time label. One rule for every row, as for state | costate: the left cell carries the
  name and the paired right cell none (`dual <label>` when the right side is drawn alone).
  A path constraint is named by its label, a box by its component and its label,
  `x₂ (x2_box)`.

```@example pc
pre2 = CTModels.PreModel()
CTModels.variable!(pre2, 0)
CTModels.time!(pre2; t0=0.0, tf=1.0)
CTModels.state!(pre2, 2)
CTModels.control!(pre2, 1)
CTModels.dynamics!(pre2, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
CTModels.objective!(pre2, :min; lagrange=(t, x, u, v) -> u^2)
CTModels.constraint!(pre2, :path; f=(r, t, x, u, v) -> (r[1] = x[1] + x[2]; nothing),
    lb=[-Inf], ub=[3.0], label=:c1)
CTModels.constraint!(pre2, :state; rg=2:2, lb=[-0.5], ub=[2.0], label=:x2_box)
CTModels.constraint!(pre2, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box)
CTModels.time_dependence!(pre2; autonomous=true)
ocp2 = CTModels.build(pre2)
M = 21
T2 = collect(range(0.0, 1.0; length=M))
sol2 = CTModels.build_solution(ocp2, T2, hcat(T2, ones(M)), ones(M, 1), Float64[], zeros(M, 2);
    objective=1.0, successful=true, path_constraints_dual=hcat(T2),
    state_constraints_lb_dual=zeros(M, 2), state_constraints_ub_dual=zeros(M, 2),
    control_constraints_lb_dual=zeros(M, 1), control_constraints_ub_dual=zeros(M, 1))
nothing # hide
```

The rows of this solution, and the cells that result:

```@repl pc
[(r.label, r.kind, r.rows, r.dual) for r in CTModels.PlotCase._constraint_rows(sol2, ocp2)]
using CTBase: Plotting
fig2 = CTModels.PlotCase.build_figure(sol2);
[(l.axes.title, l.axes.ylabel) for l in Plotting.leaves(fig2.root)]
```

## Keywords: build or render

`plot(sol; kwargs...)` mixes two kinds of keywords.
[`split_plot_kwargs`](@ref CTModels.PlotCase.split_plot_kwargs) separates them:

- the keywords listed in `PlotCase._BUILD_KEYS` (`layout`, `control`, `time` and the
  `*_style` keywords) shape the figure and go to `build_figure`;
- every other keyword is forwarded to the renderer, which resolves it for its backend.

```@repl pc
CTModels.PlotCase.split_plot_kwargs((layout=:group, state_style=(color=:red,), dpi=300))
```

## Where to change what

| To change | Edit |
| --- | --- |
| the accepted group symbols and defaults (`:state`, `:dual`, default layout, …) | `src/PlotCase/vocabulary.jl` |
| how a group is sampled and labelled | `src/PlotCase/panels.jl` |
| which constraint rows exist, and the cells of a row | `src/PlotCase/rows.jl` |
| reference lines (box bounds, initial and final times) | `src/PlotCase/decorations.jl` |
| the arrangement of panels for `:split` and `:group` (the constraint block is built in `_build_root`) | `src/PlotCase/assemble.jl`, `src/PlotCase/build.jl` |
| the keyword surface of `plot` | `build_figure` and `_BUILD_KEYS` in `src/PlotCase/build.jl` |
| the `Plots.plot` / `Makie.plot` methods themselves | `ext/CTModelsPlots.jl`, `ext/CTModelsMakie.jl` |

A change to the IR or to the rendering of a panel type belongs to `CTBase.Plotting`, not to
CTModels.
