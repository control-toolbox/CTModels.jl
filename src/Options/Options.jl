"""
Generic option handling for CTModels tools and strategies.

This module provides the foundational types and functions for:
- Option value tracking with provenance
- Option schema definition with validation and aliases
- Option extraction with alias support
- Type validation and helpful error messages

The Options module is deliberately generic and has no dependencies on other
CTModels modules, making it reusable across the ecosystem.
"""
module Options

using CTBase: CTBase
using DocStringExtensions

# ==============================================================================
# Include submodules
# ==============================================================================

include(joinpath(@__DIR__, "option_value.jl"))
include(joinpath(@__DIR__, "option_schema.jl"))
include(joinpath(@__DIR__, "option_definition.jl"))
include(joinpath(@__DIR__, "extraction.jl"))

# ==============================================================================
# Public API
# ==============================================================================

export OptionValue, OptionSchema, OptionDefinition, extract_option, extract_options

end # module Options