# Modelers Module
# 
# This module provides strategy-based modelers for converting discretized optimal 
# control problems to NLP backend models using the new AbstractStrategy contract.
#
# Author: CTModels Development Team
# Date: 2026-01-25

module Modelers

using CTBase: CTBase
using DocStringExtensions
using SolverCore
using ADNLPModels
using ExaModels
using ..CTModels.Options
using ..CTModels.Strategies
using ..CTModels.Optimization: AbstractOptimizationProblem

# Include submodules
include(joinpath(@__DIR__, "abstract_modeler.jl"))
include(joinpath(@__DIR__, "adnlp_modeler.jl"))
include(joinpath(@__DIR__, "exa_modeler.jl"))

# Public API
export AbstractOptimizationModeler
export ADNLPModeler, ExaModeler

end # module Modelers
