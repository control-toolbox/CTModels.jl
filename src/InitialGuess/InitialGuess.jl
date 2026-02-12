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

- [`InitialGuess`](@ref): Validated initial guess with callable trajectories
- [`OptimalControlPreInit`](@ref): Pre-initialization container for raw data

See also: [`CTModels`](@ref)
"""
module InitialGuess

using DocStringExtensions
using CTBase: CTBase
const Exceptions = CTBase.Exceptions

# Import types and aliases from OCP module
import ..OCP: AbstractModel, AbstractSolution
import ..OCP: AbstractModel, AbstractSolution

# Import functions from OCP module
import ..OCP: state, control, variable
import ..OCP: state_dimension, control_dimension, variable_dimension
import ..OCP: state_name, control_name, variable_name
import ..OCP: state_components, control_components, variable_components
import ..OCP: initial_time, final_time, time_name, time_grid
import ..OCP: has_fixed_initial_time, has_fixed_final_time
import ..OCP: has_free_initial_time, has_free_final_time

# Import utilities from Utils module
import ..Utils: ctinterpolate, matrix2vec

# Load types first
include("types.jl")

# Load implementation by component
include("utils.jl")      # Utilitaires de base
include("state.jl")      # Initialisation d'état
include("control.jl")    # Initialisation de contrôle
include("variable.jl")   # Initialisation de variable
include("builders.jl")   # Constructeurs
include("validation.jl") # Validation
include("api.jl")        # API publique

# Export public API
export initial_guess, pre_initial_guess, build_initial_guess, validate_initial_guess
export initial_state, initial_control, initial_variable
export InitialGuess, OptimalControlPreInit
export AbstractInitialGuess, AbstractOptimalControlPreInit

# Note: state, control, variable are NOT exported here as they are already
# defined in the parent CTModels module for Model and Solution types.
# The InitialGuess module defines additional methods for InitialGuess
# which extend the existing functions.

end
