# DOCP Module
#
# This module provides the DiscretizedOptimalControlProblem type and implements
# the AbstractOptimizationProblem contract.
#
# Author: CTModels Development Team
# Date: 2026-01-26

module DOCP

using CTBase: CTBase
using DocStringExtensions
using ..CTModels.Optimization: AbstractOptimizationProblem
using ..CTModels.Optimization: AbstractBuilder, AbstractModelBuilder, AbstractSolutionBuilder
using ..CTModels.Optimization: AbstractOCPSolutionBuilder
import ..CTModels.Optimization: get_adnlp_model_builder, get_exa_model_builder
import ..CTModels.Optimization: get_adnlp_solution_builder, get_exa_solution_builder

# Include submodules
include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "contract_impl.jl"))
include(joinpath(@__DIR__, "accessors.jl"))

# Public API
export DiscretizedOptimalControlProblem
export ocp_model

end # module DOCP
