"""
Weak-dependency extension of CTModels providing `Plots.plot` / `plot!` for solutions.

Loaded automatically when both `CTModels` and `Plots` are available. This is a thin
**case layer**: it names and samples the optimal-control quantities (state, control,
costate, path constraints, duals), chooses a layout template, and delegates all layout
and rendering to the generic `CTBase.Plotting` engine.
"""
module CTModelsPlots

import CTBase.Plotting
import CTBase.Exceptions
import DocStringExtensions: TYPEDSIGNATURES

using CTModels: CTModels
using Plots: Plots

include(joinpath(@__DIR__, "case", "vocabulary.jl"))
include(joinpath(@__DIR__, "case", "panels.jl"))
include(joinpath(@__DIR__, "case", "decorations.jl"))
include(joinpath(@__DIR__, "case", "assemble.jl"))
include(joinpath(@__DIR__, "case", "plot.jl"))

end
