"""
    Serialization

Serialization module for CTModels.

This module provides functions for importing and exporting optimal control
solutions to various formats (JLD2, JSON).

# Organisation

- **types.jl**: Abstract and concrete types for format tags ([`CTModels.Serialization.AbstractTag`](@extref), [`CTModels.Serialization.JLD2Tag`](@extref), [`CTModels.Serialization.JSON3Tag`](@extref))
- **export_import.jl**: Public API for export/import ([`CTModels.Serialization.export_ocp_solution`](@extref), [`CTModels.Serialization.import_ocp_solution`](@extref))
- **reconstruction_helpers.jl**: Internal helpers for solution reconstruction ([`CTModels.Serialization._reconstruct_solution_from_data`](@extref), [`CTModels.Serialization._extract_time_vector`](@extref))

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

See also: [`CTModels.Serialization.export_ocp_solution`](@extref),
[`CTModels.Serialization.import_ocp_solution`](@extref).
"""
module Serialization

using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using CTBase: CTBase, Exceptions

using ..Components
using ..Models
using ..Building
using ..Solutions

include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "export_import.jl"))
include(joinpath(@__DIR__, "reconstruction_helpers.jl"))

# Export public API
export export_ocp_solution, import_ocp_solution
export JLD2Tag, JSON3Tag, AbstractTag

end
