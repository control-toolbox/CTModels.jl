"""
Weak-dependency extension of CTModels providing `Plots.plot` / `plot!` for solutions.

Loaded automatically when both `CTModels` and `Plots` are available. This is the thin
plumbing on top of the backend-free case layer [`CTModels.PlotCase`](@extref): the
public `Plots.plot` / `plot!` methods build the figure with
[`CTModels.PlotCase.build_figure`](@extref) and render it through the
`CTBase.Plotting` Plots backend.
"""
module CTModelsPlots

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting
using CTModels: CTModels, PlotCase
using Plots: Plots

include(joinpath(@__DIR__, "case", "plot.jl"))

end
