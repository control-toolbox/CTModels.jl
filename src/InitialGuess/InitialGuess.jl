"""
    InitialGuess

Initial guess module for CTModels.

This module provides types and functions for constructing and managing initial
guesses for optimal control problems. Initial guesses help warm-start numerical
solvers by providing starting trajectories for state, control, and variables.

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- [`initial_guess`](@ref): Construct a validated initial guess
- [`pre_initial_guess`](@ref): Create a pre-initialization object

# Types

- [`OptimalControlInitialGuess`](@ref): Validated initial guess with callable trajectories
- [`OptimalControlPreInit`](@ref): Pre-initialization container for raw data

See also: [`CTModels`](@ref)
"""
module InitialGuess

using DocStringExtensions
using CTBase

# Import types from OCP module
import ..OCP: AbstractModel, AbstractSolution
# Create local aliases for compatibility
const AbstractOptimalControlProblem = AbstractModel

# Import functions from OCP module
import ..OCP: state, control, variable
import ..OCP: state_dimension, control_dimension, variable_dimension
import ..OCP: state_name, control_name, variable_name

# Import utilities from Utils module
import ..Utils: ctinterpolate, matrix2vec

# Load types first
include("types.jl")

# Load implementation
include("initial_guess.jl")

# Export public API
export initial_guess, pre_initial_guess, build_initial_guess, validate_initial_guess
export OptimalControlInitialGuess, OptimalControlPreInit
export AbstractOptimalControlInitialGuess, AbstractOptimalControlPreInit

# Note: state, control, variable are NOT exported here as they are already
# defined in the parent CTModels module for Model and Solution types.
# The InitialGuess module defines additional methods for OptimalControlInitialGuess
# which extend the existing functions.

end
