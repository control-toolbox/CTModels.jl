"""
[`CTModels`](@ref) module.

Lists all the imported modules and packages:

$(IMPORTS)

List of all the exported names:

$(EXPORTS)
"""
module CTModels

# imports
using Base
using CTBase: CTBase
using DocStringExtensions
using Interpolations
using MLStyle
using Parameters # @with_kw: to have default values in struct
using MacroTools: striplines
using RecipesBase: plot, plot!, RecipesBase
using OrderedCollections: OrderedDict
using SolverCore
using ADNLPModels
using ExaModels
using KernelAbstractions
using NLPModels

# Modules
include(joinpath(@__DIR__, "Options", "Options.jl"))
using .Options

include(joinpath(@__DIR__, "Strategies", "Strategies.jl"))
using .Strategies

include(joinpath(@__DIR__, "Orchestration", "Orchestration.jl"))
using .Orchestration

# Optimization module provides general optimization types (AbstractOptimizationProblem, builders)
include(joinpath(@__DIR__, "optimization", "optimization.jl"))
using .Optimization

# Modelers module uses AbstractOptimizationProblem from Optimization (general)
include(joinpath(@__DIR__, "Modelers", "Modelers.jl"))
using .Modelers

# DOCP module provides concrete DOCP types (DiscretizedOptimalControlProblem)
# Loaded after Modelers since Modelers only need the general AbstractOptimizationProblem
include(joinpath(@__DIR__, "docp", "docp.jl"))
using .DOCP

# ============================================================================ #
# TYPES AND FOUNDATIONS
# ============================================================================ #
# Load fundamental types first as they have no dependencies and are used
# everywhere in the codebase.

# 1. Type aliases (Dimension, ctNumber, Time, etc.) and export/import types
#    These are the most basic types with no dependencies
include(joinpath(@__DIR__, "types", "types.jl"))

# 2. OCP defaults (functions returning default values)
#    Depends on: type aliases (uses Dimension, ctVector, etc.)
include(joinpath(@__DIR__, "ocp", "defaults.jl"))

# 3. Utility functions (interpolation, matrix operations, macros)
#    Depends on: type aliases (uses ctNumber, etc.)
#    Must be loaded before OCP types because @ensure macro is used in OCP types
include(joinpath(@__DIR__, "utils", "utils.jl"))

# 4. OCP type definitions (components, model, solution)
#    Depends on: type aliases, defaults, and utils (@ensure macro)
include(joinpath(@__DIR__, "ocp", "types", "components.jl"))
include(joinpath(@__DIR__, "ocp", "types", "model.jl"))
include(joinpath(@__DIR__, "ocp", "types", "solution.jl"))

# 5. NLP types (backends, builders, modelers)
#    Depends on: OCP types (uses AbstractModel, AbstractSolution)
# include(joinpath(@__DIR__, "nlp", "types.jl"))  # LEGACY - Replaced by Optimization module

# # 6. Export/import functions (require OCP types)
# #    Depends on: OCP types (uses AbstractModel, AbstractSolution)
# include(joinpath(@__DIR__, "types", "export_import_functions.jl"))

# ============================================================================ #
# COMPATIBILITY ALIASES
# ============================================================================ #
# Aliases for CTSolvers compatibility
# Depends on: OCP types

"""
Type alias for [`AbstractModel`](@ref).

Provides compatibility with CTSolvers naming conventions.
"""
const AbstractOptimalControlProblem = CTModels.AbstractModel

"""
Type alias for [`AbstractSolution`](@ref).

Provides compatibility with CTSolvers naming conventions.
"""
const AbstractOptimalControlSolution = CTModels.AbstractSolution

# ============================================================================ #
# IMPLEMENTATIONS
# ============================================================================ #
# Load implementations after all types are defined

# 6. OCP implementations (dynamics, constraints, model building, etc.)
#    Depends on: all OCP types
include(joinpath(@__DIR__, "ocp", "ocp.jl"))

# 7. NLP implementations (problem core, backends, discretization)
#    Depends on: OCP and NLP types
# include(joinpath(@__DIR__, "nlp", "problem_core.jl"))  # LEGACY - Replaced by Optimization.contract
# include(joinpath(@__DIR__, "nlp", "nlp_backends.jl"))  # LEGACY - Replaced by Modelers module
include(joinpath(@__DIR__, "nlp", "extract_solver_infos.jl"))
# include(joinpath(@__DIR__, "nlp", "discretized_ocp.jl"))  # LEGACY - Replaced by DOCP.contract_impl
include(joinpath(@__DIR__, "nlp", "model_api.jl"))
# 8. Initialization (types and functions for initial guesses)
#    Depends on: OCP types (uses AbstractModel, AbstractSolution)
include(joinpath(@__DIR__, "init", "types.jl"))
include(joinpath(@__DIR__, "init", "initial_guess.jl"))

end