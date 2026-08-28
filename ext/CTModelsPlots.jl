"""
Weak-dependency extension of CTModels providing `Plots.plot` / `plot!` for solutions.

Loaded automatically when both `CTModels` and `Plots` are available. This is the thin
plumbing on top of the backend-free case layer [`CTModels.PlotCase`](@extref): the
public `Plots.plot` / `plot!` methods build the figure with
[`CTModels.PlotCase.build_figure`](@extref) and render it through the
`CTBase.Plotting` Plots backend. Everything domain-specific (the vocabulary, panels,
decorations, layout template) lives in `CTModels.PlotCase`.
"""
module CTModelsPlots

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting
using CTModels: CTModels, PlotCase
using Plots: Plots

# --- internal implementations (backend-agnostic build + Plots render) --------

"""
$(TYPEDSIGNATURES)

Internal implementation of `Plots.plot(::CTModels.Solution)`.

Builds the figure with [`CTModels.PlotCase.build_figure`](@extref) and renders it
via [`CTBase.Plotting`](@extref) (Plots backend).
"""
function _plot(
    sol::CTModels.Solution, description::Symbol...; size=nothing, color=nothing, kwargs...
)
    build, render_kwargs = PlotCase.split_plot_kwargs(kwargs)
    fig = PlotCase.build_figure(sol, description...; size=size, build...)
    # Nothing to draw (empty description, every group :none, or only path/dual in
    # :group): return an empty figure, as the historical CTModels plot did.
    fig === nothing && return Plots.plot()
    return if color === nothing
        Plotting.render(Plotting.PlotsBackend(), fig; render_kwargs...)
    else
        Plotting.render(Plotting.PlotsBackend(), fig; color=color, render_kwargs...)
    end
end

"""
$(TYPEDSIGNATURES)

Internal implementation of `Plots.plot!(::Plots.Plot, ::CTModels.Solution)`.

Builds the figure with [`CTModels.PlotCase.build_figure`](@extref) and overlays it
onto the existing plot `p` via [`CTBase.Plotting`](@extref) (Plots backend).
"""
function _plot!(
    p::Plots.Plot, sol::CTModels.Solution, description::Symbol...; color=nothing, kwargs...
)
    build, render_kwargs = PlotCase.split_plot_kwargs(kwargs)
    fig = PlotCase.build_figure(sol, description...; build...)
    fig === nothing && return p
    # Empty target (e.g. `plot!(sol)` onto a bare `plot()`): the figure has no cells to
    # overlay, so build a fresh figure and substitute it field-by-field into `p`,
    # preserving `p`'s identity — the historical empty-figure path (R1).
    if isempty(p.series_list)
        fresh = if color === nothing
            Plotting.render(Plotting.PlotsBackend(), fig; render_kwargs...)
        else
            Plotting.render(Plotting.PlotsBackend(), fig; color=color, render_kwargs...)
        end
        for k in fieldnames(typeof(p))
            setfield!(p, k, getfield(fresh, k))
        end
        return p
    end
    return if color === nothing
        Plotting.render!(Plotting.PlotsBackend(), p, fig; render_kwargs...)
    else
        Plotting.render!(Plotting.PlotsBackend(), p, fig; color=color, render_kwargs...)
    end
end

# --- public methods (thin; forward to _plot / _plot!) ------------------------

"""
$(TYPEDSIGNATURES)

Plot the components of an optimal control [`CTModels.Solution`](@extref).

Generates a set of subplots showing the state, control, costate, path constraints and
dual variables over time, depending on the problem and the given `description`.

# Arguments
- `sol`: the optimal control solution to visualise.
- `description`: symbols selecting which groups to include; any of `:state`, `:costate`,
  `:control`, `:path` (path constraints), `:dual` (their multipliers). If none is given,
  a default set is used based on the problem.

# Keyword arguments
- `layout::Symbol = :split`: `:split` (one subplot per component) or `:group` (group
  each signal into a single subplot with a legend).
- `control::Symbol = :components`: `:components` (a curve per control component), `:norm`
  (the Euclidean norm `‖u(t)‖`) or `:all` (both).
- `time::Symbol = :default`: `:default` (real time) or `:normalize`/`:normalise` (`[0, 1]`).
- `color`: colour applied to every curve.
- `size`: figure size; defaults to a heuristic based on the layout.

## Style options
Each `*_style` keyword is a `NamedTuple` of plotting attributes, or `:none` to hide the
group/decoration: `state_style`, `costate_style`, `control_style`, `path_style`,
`dual_style`, `time_style` (initial/final time markers), and the bounds decorations
`state_bounds_style`, `control_bounds_style`, `path_bounds_style`.

# Returns
A `Plots.Plot`. All layout and rendering is delegated to `CTBase.Plotting`.

# Example
```julia-repl
julia> plot(sol)
julia> plot(sol, :state, :control; layout=:group, control=:all)
julia> plot(sol; state_style=(color=:blue,), costate_style=:none)
```
"""
function Plots.plot(sol::CTModels.Solution, description::Symbol...; kwargs...)
    return _plot(sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Overlay the optimal control solution `sol` onto the existing plot `p`. Same behaviour and
keyword arguments as [`Plots.plot(::CTModels.Solution)`](@extref); an empty `p` is filled as
if by `plot`.
"""
function Plots.plot!(
    p::Plots.Plot, sol::CTModels.Solution, description::Symbol...; kwargs...
)
    return _plot!(p, sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Overlay the optimal control solution `sol` onto the current plot (`Plots.current()`).
"""
function Plots.plot!(sol::CTModels.Solution, description::Symbol...; kwargs...)
    return _plot!(Plots.current(), sol, description...; kwargs...)
end

end # module CTModelsPlots
