"""
Weak-dependency extension of CTModels providing `Makie.plot` for solutions
(proof of concept — issue #366).

Loaded automatically when both `CTModels` and `Makie` are available (for example
via `CairoMakie` or `GLMakie`). Thin plumbing on top of the backend-free case
layer [`CTModels.PlotCase`](@extref): `Makie.plot` builds the figure with
[`CTModels.PlotCase.build_figure`](@extref) and renders it through the
`CTBase.Plotting` Makie backend.

## Scope

`plot` only. `plot!` overlay is not implemented (throws `NotImplemented`), and the
Makie backend itself does not yet draw reference-line decorations (box bounds,
initial/final time markers) or step/scatter control curves — see the parity
follow-up of #366.
"""
module CTModelsMakie

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting, Exceptions
using CTModels: CTModels, PlotCase
using Makie: Makie

"""
$(TYPEDSIGNATURES)

Plot the components of an optimal control [`CTModels.Solution`](@extref) with a
Makie backend.

Same `description` and keyword arguments as `Plots.plot(::CTModels.Solution)`
(`layout`, `control`, `time`, the `*_style` / `*_bounds_style` keywords, `color`,
`size`). Returns a `Makie.Figure`.

# Example
```julia-repl
julia> using CairoMakie

julia> plot(sol)

julia> plot(sol, :state, :control; layout=:group, control=:all)
```
"""
function Makie.plot(
    sol::CTModels.Solution, description::Symbol...; size=nothing, color=nothing, kwargs...
)
    build, render_kwargs = PlotCase.split_plot_kwargs(kwargs)
    fig = PlotCase.build_figure(sol, description...; size=size, build...)
    fig === nothing && return Makie.Figure()
    return if color === nothing
        Plotting.render(Plotting.MakieBackend(), fig; render_kwargs...)
    else
        Plotting.render(Plotting.MakieBackend(), fig; color=color, render_kwargs...)
    end
end

"""
$(TYPEDSIGNATURES)

Overlay is not implemented by the Makie proof-of-concept backend.

# Throws
- `CTBase.Exceptions.NotImplemented`: always — use the Plots backend for overlays,
  or wait for the parity follow-up of CTModels#366.
"""
function Makie.plot!(::CTModels.Solution, args...; kwargs...)
    return throw(
        Exceptions.NotImplemented(
            "Makie.plot!(::CTModels.Solution) (overlay) is not implemented";
            suggestion="use the Plots backend for overlays, or wait for the parity follow-up of CTModels#366",
            context="CTModelsMakie",
        ),
    )
end

end # module CTModelsMakie
