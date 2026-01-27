"""
    Serialization

Serialization module for CTModels.

This module provides functions for importing and exporting optimal control
solutions to various formats (JLD2, JSON).

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- [`export_ocp_solution`](@ref): Export a solution to file
- [`import_ocp_solution`](@ref): Import a solution from file

# Supported Formats

- **JLD2**: Binary format (requires `JLD2.jl` package)
- **JSON**: Text format (requires `JSON3.jl` package)

# Private API

The following are internal utilities (accessible via `Serialization.function_name`):

- `__format`: Get default format
- `__filename_export_import`: Get default filename

See also: [`CTModels`](@ref), [`export_ocp_solution`](@ref), [`import_ocp_solution`](@ref)
"""
module Serialization

using DocStringExtensions
using CTBase

# Import types from parent module
import ..AbstractModel, ..AbstractSolution, ..Solution

# Define export/import tag types
include("types.jl")

# Include serialization functions
include("export_import.jl")

# Export public API
export export_ocp_solution, import_ocp_solution
export JLD2Tag, JSON3Tag, AbstractTag

end
