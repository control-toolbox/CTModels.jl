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
include(joinpath(@__DIR__, "Optimization", "Optimization.jl"))
using .Optimization

# Modelers module uses AbstractOptimizationProblem from Optimization (general)
include(joinpath(@__DIR__, "Modelers", "Modelers.jl"))
using .Modelers

# DOCP module provides concrete DOCP types (DiscretizedOptimalControlProblem)
# Loaded after Modelers since Modelers only need the general AbstractOptimizationProblem
include(joinpath(@__DIR__, "DOCP", "DOCP.jl"))
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

# 3. Utils module (interpolation, matrix operations, macros)
#    Depends on: CTBase (for ctNumber)
#    Must be loaded before OCP types because @ensure macro is used in OCP types
include(joinpath(@__DIR__, "utils", "utils.jl"))
using .Utils
# Import @ensure macro for use in OCP types
import .Utils: @ensure

# 5. OCP type definitions (components, model, solution)
#    Depends on: type aliases, defaults, and utils (@ensure macro)
include(joinpath(@__DIR__, "ocp", "types", "components.jl"))
include(joinpath(@__DIR__, "ocp", "types", "model.jl"))
include(joinpath(@__DIR__, "ocp", "types", "solution.jl"))

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
#    Note: print.jl will be moved to Display module
include(joinpath(@__DIR__, "ocp", "dual_model.jl"))
include(joinpath(@__DIR__, "ocp", "state.jl"))
include(joinpath(@__DIR__, "ocp", "control.jl"))
include(joinpath(@__DIR__, "ocp", "variable.jl"))
include(joinpath(@__DIR__, "ocp", "times.jl"))
include(joinpath(@__DIR__, "ocp", "dynamics.jl"))
include(joinpath(@__DIR__, "ocp", "objective.jl"))
include(joinpath(@__DIR__, "ocp", "constraints.jl"))
include(joinpath(@__DIR__, "ocp", "time_dependence.jl"))
include(joinpath(@__DIR__, "ocp", "definition.jl"))
include(joinpath(@__DIR__, "ocp", "print.jl"))  # TODO: Will be moved to Display module
include(joinpath(@__DIR__, "ocp", "model.jl"))
include(joinpath(@__DIR__, "ocp", "solution.jl"))

# 7. Display module (formatting and printing)
#    Depends on: OCP types (Model, Solution)
#    Note: Currently using ocp/print.jl, will transition to Display module
# include(joinpath(@__DIR__, "Display", "Display.jl"))
# using .Display

# 8. Serialization module (import/export)
#    Depends on: OCP types (AbstractModel, AbstractSolution)
#    Note: Currently using types/export_import_functions.jl
include(joinpath(@__DIR__, "types", "export_import_functions.jl"))
# include(joinpath(@__DIR__, "Serialization", "Serialization.jl"))
# using .Serialization

# 9. InitialGuess module
#    Depends on: OCP types, Utils (ctinterpolate, matrix2vec)
#    Note: Currently using init/, will transition to InitialGuess module
include(joinpath(@__DIR__, "InitialGuess", "types.jl"))
include(joinpath(@__DIR__, "InitialGuess", "initial_guess.jl"))
# include(joinpath(@__DIR__, "InitialGuess", "InitialGuess.jl"))
# using .InitialGuess

end
