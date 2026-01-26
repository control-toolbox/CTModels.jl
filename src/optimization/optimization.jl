# Optimization Module
#
# This module provides general optimization problem types and builder interfaces
# that are independent of specific optimal control problem implementations.
#
# Author: CTModels Development Team
# Date: 2026-01-26

module Optimization

using CTBase: CTBase
using DocStringExtensions

# Include submodules
include(joinpath(@__DIR__, "abstract_types.jl"))
include(joinpath(@__DIR__, "builders.jl"))

# Public API
export AbstractOptimizationProblem
export AbstractBuilder, AbstractModelBuilder, AbstractSolutionBuilder
export AbstractOCPSolutionBuilder

end # module Optimization
