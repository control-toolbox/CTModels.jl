"""
    Utils

Utility functions module for CTModels.

This module provides general-purpose utility functions used throughout CTModels,
including interpolation, matrix operations, and function transformations.

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- `ctinterpolate`: Linear interpolation for data
- `ctinterpolate_constant`: Piecewise-constant interpolation for data
- `matrix2vec`: Convert matrices to vectors

# Private API

The following are internal utilities (accessible via `Utils.function_name`):

- `to_out_of_place`: Convert in-place functions to out-of-place
- `@ensure`: Validation macro for preconditions

See also: `CTModels`
"""
module Utils

using DocStringExtensions
using CTBase: ctNumber

# Private utilities (not exported)
include("function_utils.jl")
include("macros.jl")

# Public utilities (exported)
include("interpolation.jl")
include("matrix_utils.jl")

# Export public API
export ctinterpolate, ctinterpolate_constant, matrix2vec

end
