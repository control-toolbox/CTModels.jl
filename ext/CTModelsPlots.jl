module CTModelsPlots

#
using DocStringExtensions
using MLStyle # pattern matching

#
using CTBase
using CTModels
using LinearAlgebra
using Plots # redefine plot, plot!
#import Plots: plot, plot!

include("default.jl")
include("plot.jl")

end