"""
Weak-dependency extension of CTModels providing Plots.jl recipes.

Loaded automatically when both `CTModels` and `Plots` are available in the session.
Extends `Plots.plot` and `Plots.plot!` to accept a `CTModels.Solution`, rendering
state, control, costate, and dual trajectories in a configurable layout.
"""
module CTModelsPlots

import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using CTBase: CTBase
using CTModels: CTModels
using MLStyle: MLStyle
import LinearAlgebra: norm
import Plots.Measures: mm
import Plots: @recipe
using Plots: Plots

include(joinpath(@__DIR__, "plot_utils.jl"))
include(joinpath(@__DIR__, "plot_default.jl"))
include(joinpath(@__DIR__, "plot.jl"))

end
