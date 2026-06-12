"""
    Serialization

Serialization module for CTModels.

This module provides functions for importing and exporting optimal control
solutions to various formats (JLD2, JSON).

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- `export_ocp_solution`: Export a solution to file
- `import_ocp_solution`: Import a solution from file

# Supported Formats

- **JLD2**: Binary format (requires `JLD2.jl` package)
- **JSON**: Text format (requires `JSON3.jl` package)

# Private API

The following are internal utilities (accessible via `Serialization.function_name`):

- `__format`: Get default format
- `__filename_export_import`: Get default filename

See also: [`CTModels.Serialization.export_ocp_solution`](@ref),
[`CTModels.Serialization.import_ocp_solution`](@ref).
"""
module Serialization

import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using CTBase: CTBase

import ..CTModels.OCP
using ..OCP: AbstractModel, AbstractSolution, Solution
import ..OCP: __format, __filename_export_import, __control_interpolation

include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "export_import.jl"))
include(joinpath(@__DIR__, "reconstruction_helpers.jl"))

# Export public API
export export_ocp_solution, import_ocp_solution
export JLD2Tag, JSON3Tag, AbstractTag

end
