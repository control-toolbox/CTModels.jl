"""
[`CTModels`](@ref) module.

Lists all the imported modules and packages:

$(IMPORTS)

List of all the exported names:

$(EXPORTS)
"""
module CTModels

# imports
using DocStringExtensions
using OrderedCollections: OrderedDict

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
#    Note: Moved to OCP module (aliases.jl) and Serialization module (types.jl)
#    No longer needed here as they are loaded with their respective modules

# 2. OCP defaults (functions returning default values)
#    Note: Now included in OCP module (Core/defaults.jl)

# 3. Utils module (interpolation, matrix operations, macros)
#    Depends on: CTBase (for ctNumber)
#    Must be loaded before OCP types because @ensure macro is used in OCP types
include(joinpath(@__DIR__, "Utils", "Utils.jl"))
using .Utils
# Import @ensure macro for use in OCP types
import .Utils: @ensure

# 5. OCP type definitions (components, model, solution)
#    Note: Now included in OCP module (Types/ directory)

# 6. OCP module (optimal control problem core)
#    Depends on: all foundational types, Utils
#    Note: Replaces all individual ocp/ includes with organized module
#    Note: Compatibility aliases (AbstractOptimalControlProblem, etc.) are now in OCP
include(joinpath(@__DIR__, "OCP", "OCP.jl"))
using .OCP

# ============================================================================ #
# IMPLEMENTATIONS
# ============================================================================ #
# Load implementations after all types are defined

# 7. Display module (formatting and printing)
#    Depends on: OCP types (Model, Solution)
include(joinpath(@__DIR__, "Display", "Display.jl"))
using .Display

# 8. Serialization module (import/export)
#    Depends on: OCP types (AbstractModel, AbstractSolution)
include(joinpath(@__DIR__, "Serialization", "Serialization.jl"))
using .Serialization

# 9. InitialGuess module
#    Depends on: OCP types, Utils (ctinterpolate, matrix2vec)
#    Must be loaded after OCP to extend state/control/variable functions
include(joinpath(@__DIR__, "InitialGuess", "InitialGuess.jl"))
using .InitialGuess

end
