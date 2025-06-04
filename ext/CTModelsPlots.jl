module CTModelsPlots

#
using DocStringExtensions
using MLStyle # pattern matching

#
using CTBase
using CTModels
using LinearAlgebra
using Plots # redefine plot, plot!
using Plots.Measures
#import Plots: plot, plot!

include("plot_utils.jl")
include("plot_default.jl")
include("plot.jl")

end