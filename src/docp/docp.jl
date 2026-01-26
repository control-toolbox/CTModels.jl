# DOCP Module
#
# This module provides Discretized Optimal Control Problem (DOCP) components
# for storing and managing discretized optimal control problems with their
# associated model and solution builders.
#
# Author: CTModels Development Team
# Date: 2026-01-26

module DOCP

using CTBase: CTBase
using DocStringExtensions
using ..CTModels.Optimization: AbstractOptimizationProblem
using ..CTModels.Optimization: AbstractBuilder, AbstractModelBuilder, AbstractSolutionBuilder
using ..CTModels.Optimization: AbstractOCPSolutionBuilder

# Include submodules
include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "builders.jl"))
include(joinpath(@__DIR__, "constructors.jl"))

# Public API - concrete DOCP types
export DiscretizedOptimalControlProblem, OCPBackendBuilders
export ADNLPModelBuilder, ExaModelBuilder
export ADNLPSolutionBuilder, ExaSolutionBuilder
export get_adnlp_model_builder, get_exa_model_builder
export get_adnlp_solution_builder, get_exa_solution_builder
export create_adnlp_model_builder, create_exa_model_builder
export create_adnlp_solution_builder, create_exa_solution_builder
export ocp_model, backend_builders, get_backend_builder
export available_backends, has_backend
export create_discretized_ocp, add_backend!, remove_backend

end # module DOCP
