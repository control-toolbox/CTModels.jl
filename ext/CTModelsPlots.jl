"""
Weak-dependency extension of [`CTModels`](@ref) providing Plots.jl recipes.

Loaded automatically when both `CTModels` and `Plots` are available in the session.
Extends `Plots.plot` and `Plots.plot!` to accept a `CTModels.Solution`, rendering
state, control, costate, and dual trajectories in a configurable layout.
"""
module CTModelsPlots

#
using DocStringExtensions
using MLStyle: MLStyle

#
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
using LinearAlgebra
using Plots # redefine plot, plot!
using Plots.Measures
#import Plots: plot, plot!

include("plot_utils.jl")
include("plot_default.jl")
include("plot.jl")

export plot, plot!

end
