"""
    InitialGuess

Initial guess module for CTModels.

This module provides types and functions for constructing and managing initial
guesses for optimal control problems. Initial guesses help warm-start numerical
solvers by providing starting trajectories for state, control, and variables.

# Organisation

- **types.jl**: Abstract and concrete initial guess types ([`CTModels.Init.InitialGuess`](@ref), [`CTModels.Init.PreInitialGuess`](@ref))
- **utils.jl**: Time grid and data formatting helpers ([`CTModels.Init._format_time_grid`](@ref), [`CTModels.Init._format_init_data_for_grid`](@ref))
- **state.jl**: State initialisation functions ([`CTModels.Init.initial_state`](@ref))
- **control.jl**: Control initialisation functions ([`CTModels.Init.initial_control`](@ref))
- **variable.jl**: Variable initialisation functions ([`CTModels.Init.initial_variable`](@ref))
- **builders.jl**: Component-level and time-grid builders ([`CTModels.Init._build_block_with_components`](@ref), [`CTModels.Init._build_time_dependent_init`](@ref))
- **validation.jl**: Validation and construction from various formats ([`CTModels.Init._validate_initial_guess`](@ref), [`CTModels.Init._initial_guess_from_solution`](@ref))
- **api.jl**: Public API for initial guess construction ([`CTModels.Init.initial_guess`](@ref), [`CTModels.Init.build_initial_guess`](@ref), [`CTModels.Init.validate_initial_guess`](@ref))

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- `initial_guess`: Construct a validated initial guess
- `pre_initial_guess`: Create a pre-initialization object
- `build_initial_guess`: Build and validate an initial guess from various formats
- `validate_initial_guess`: Validate an initial guess against a problem
- `initial_state`: State initialisation helper
- `initial_control`: Control initialisation helper
- `initial_variable`: Variable initialisation helper

# Types

- [`CTModels.Init.InitialGuess`](@ref): Validated initial guess with callable trajectories
- [`CTModels.Init.PreInitialGuess`](@ref): Pre-initialization container for raw data
- [`CTModels.Init.AbstractInitialGuess`](@ref): Abstract base type for initial guesses
- [`CTModels.Init.AbstractPreInitialGuess`](@ref): Abstract base type for pre-initialization data

# Dependencies

External: `CTBase.Core`, `CTBase.Interpolation`, `CTBase.Exceptions`.

See also: [`CTModels.Components`](@ref), [`CTModels.Models`](@ref), [`CTModels.Solutions`](@ref), [`CTModels.Building`](@ref).
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
include(joinpath(@__DIR__, "init_functors.jl"))
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
