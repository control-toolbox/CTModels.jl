"""
    InitialGuess

Initial guess module for CTModels.

This module provides types and functions for constructing and managing initial
guesses for optimal control problems. Initial guesses help warm-start numerical
solvers by providing starting trajectories for state, control, and variables.

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- `initial_guess`: Construct a validated initial guess
- `pre_initial_guess`: Create a pre-initialization object

# Types

- `InitialGuess`: Validated initial guess with callable trajectories
- `PreInitialGuess`: Pre-initialization container for raw data

"""
module Init

import CTBase.Core
import CTBase.Interpolation
import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using CTBase: CTBase

using ..Components
using ..Models
using ..Solutions

# Load types first
include(joinpath(@__DIR__, "types.jl"))

# Load implementation by component
include(joinpath(@__DIR__, "utils.jl"))
include(joinpath(@__DIR__, "state.jl"))
include(joinpath(@__DIR__, "control.jl"))
include(joinpath(@__DIR__, "variable.jl"))
include(joinpath(@__DIR__, "builders.jl"))
include(joinpath(@__DIR__, "validation.jl"))
include(joinpath(@__DIR__, "api.jl"))

# Export public API
export initial_guess, pre_initial_guess, build_initial_guess, validate_initial_guess
export initial_state, initial_control, initial_variable
export InitialGuess, PreInitialGuess
export AbstractInitialGuess, AbstractPreInitialGuess

# Note: state, control, variable are NOT exported here as they are already
# defined in the parent CTModels module for Model and Solution types.
# The InitialGuess module defines additional methods for InitialGuess
# which extend the existing functions.

end
