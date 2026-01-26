# Optimization Module
#
# This module provides general optimization problem types, builder interfaces,
# and the contract that optimization problems must implement.
#
# Author: CTModels Development Team
# Date: 2026-01-26

module Optimization

using CTBase: CTBase
using DocStringExtensions

# Include submodules
include(joinpath(@__DIR__, "abstract_types.jl"))
include(joinpath(@__DIR__, "builders.jl"))
include(joinpath(@__DIR__, "contract.jl"))
include(joinpath(@__DIR__, "model_api.jl"))

# Public API - Abstract types
export AbstractOptimizationProblem
export AbstractBuilder, AbstractModelBuilder, AbstractSolutionBuilder
export AbstractOCPSolutionBuilder

# Public API - Concrete builder types
export ADNLPModelBuilder, ExaModelBuilder
export ADNLPSolutionBuilder, ExaSolutionBuilder

# Public API - Contract functions
export get_adnlp_model_builder, get_exa_model_builder
export get_adnlp_solution_builder, get_exa_solution_builder

# Public API - Model building functions
export build_model, build_solution

end # module Optimization
