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
| reference lines (box bounds, initial and final times) | `src/PlotCase/decorations.jl` |
| the arrangement of panels for `:split` and `:group` | `src/PlotCase/assemble.jl` |
| the keyword surface of `plot` | `build_figure` and `_BUILD_KEYS` in `src/PlotCase/build.jl` |
| the `Plots.plot` / `Makie.plot` methods themselves | `ext/CTModelsPlots.jl`, `ext/CTModelsMakie.jl` |

A change to the IR or to the rendering of a panel type belongs to `CTBase.Plotting`, not to
CTModels.
