"""
Weak-dependency extension of CTModels providing `Makie.plot` / `plot!` for solutions.

Loaded automatically when both `CTModels` and `Makie` are available (for example via
`CairoMakie` or `GLMakie`). This is the thin plumbing on top of the backend-free case
layer [`CTModels.PlotCase`](@extref): the public `Makie.plot` / `plot!` methods build
the figure with [`CTModels.PlotCase.build_figure`](@extref) and render it through the
`CTBase.Plotting` Makie backend, which is at feature parity with the Plots backend.
Everything domain-specific (the vocabulary, panels, decorations, layout template)
lives in `CTModels.PlotCase` and is shared with the `CTModelsPlots` extension.
"""
module CTModelsMakie

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting
using CTModels: CTModels, PlotCase
using Makie: Makie

# --- internal implementations (backend-agnostic build + Makie render) --------

"""
$(TYPEDSIGNATURES)

Internal implementation of `Makie.plot(::CTModels.Solution)`.

Builds the figure with [`CTModels.PlotCase.build_figure`](@extref) and renders it
via [`CTBase.Plotting`](@extref) (Makie backend).
"""
function _plot(
    sol::CTModels.Solution, description::Symbol...; size=nothing, color=nothing, kwargs...
)
    build, render_kwargs = PlotCase.split_plot_kwargs(kwargs)
    fig = PlotCase.build_figure(sol, description...; size=size, build...)
    # Nothing to draw (empty description, every group :none, or only path/dual in
    # :group): return an empty figure, as the Plots backend does.
    fig === nothing && return Makie.Figure()
    return if color === nothing
        Plotting.render(Plotting.MakieBackend(), fig; render_kwargs...)
    else
        Plotting.render(Plotting.MakieBackend(), fig; color=color, render_kwargs...)
    end
end

"""
$(TYPEDSIGNATURES)

Internal implementation of `Makie.plot!(::Makie.Figure, ::CTModels.Solution)`.

Builds the figure with [`CTModels.PlotCase.build_figure`](@extref) and overlays it
onto `f` via [`CTBase.Plotting`](@extref) (Makie backend); an empty `f` is filled as
if by `plot`.
"""
function _plot!(
    f::Makie.Figure, sol::CTModels.Solution, description::Symbol...; color=nothing, kwargs...
)
    build, render_kwargs = PlotCase.split_plot_kwargs(kwargs)
    fig = PlotCase.build_figure(sol, description...; build...)
    fig === nothing && return f
    return if color === nothing
        Plotting.render!(Plotting.MakieBackend(), f, fig; render_kwargs...)
    else
        Plotting.render!(Plotting.MakieBackend(), f, fig; color=color, render_kwargs...)
    end
end

# --- public methods (thin; forward to _plot / _plot!) ------------------------

"""
$(TYPEDSIGNATURES)

Plot the components of an optimal control [`CTModels.Solution`](@extref) with a
Makie backend.

Same `description` and keyword arguments as [`Plots.plot(::CTModels.Solution)`](@extref)
(`layout`, `control`, `time`, the `*_style` / `*_bounds_style` keywords, `color`,
`size`). Returns a `Makie.Figure`.

# Example
```julia-repl
julia> using CairoMakie

julia> plot(sol)

julia> plot(sol, :state, :control; layout=:group, control=:all)
```
"""
function Makie.plot(sol::CTModels.Solution, description::Symbol...; kwargs...)
    return _plot(sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Overlay the optimal control solution `sol` onto the existing `Makie.Figure` `f`. Same
behaviour and keyword arguments as [`Plots.plot(::CTModels.Solution)`](@extref); an
empty `f` is filled as if by `plot`.
"""
function Makie.plot!(
    f::Makie.Figure, sol::CTModels.Solution, description::Symbol...; kwargs...
)
    return _plot!(f, sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Overlay the optimal control solution `sol` onto the current Makie figure
(`Makie.current_figure()`), creating one if none exists.
"""
function Makie.plot!(sol::CTModels.Solution, description::Symbol...; kwargs...)
    f = Makie.current_figure()
    return _plot!(f === nothing ? Makie.Figure() : f, sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Create an empty `Makie.Figure`, forwarding keyword arguments (`size`, …).

Mirror of `Plots.plot(; kwargs...)`: a blank canvas to overlay solutions onto with
`Makie.plot!`. Makie has no zero-argument `plot` of its own, so this fills that gap
for the `Plots`-style workflow `f = plot(; size=…); plot!(f, sol)`.

# Example
```julia-repl
julia> using CairoMakie

julia> f = plot(; size=(800, 800));

julia> plot!(f, sol)
```
"""
Makie.plot(; kwargs...) = Makie.Figure(; kwargs...)

end # module CTModelsMakie
