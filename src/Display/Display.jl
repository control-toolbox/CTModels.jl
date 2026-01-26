"""
    Display

Display and formatting module for CTModels.

This module provides functions for displaying and formatting optimal control
problems and solutions in human-readable formats.

# Public API

The following functions are exported and accessible via `Base.show`:

- `Base.show(io::IO, ::MIME"text/plain", ocp::Model)`: Display an optimal control problem
- `Base.show(io::IO, ::MIME"text/plain", sol::Solution)`: Display a solution

# Private API

The following are internal utilities (accessible via `Display.function_name`):

- `__print`: Internal printing helper
- `__print_abstract_definition`: Print abstract OCP definition
- `__print_mathematical_definition`: Print mathematical OCP formulation

See also: [`CTModels`](@ref)
"""
module Display

using DocStringExtensions
using CTBase
using MLStyle
using RecipesBase

# Import types from parent module (will be available after CTModels loads this)
# These are forward declarations - actual types defined in OCP module
import ..Model, ..PreModel, ..Solution, ..AbstractSolution

# Include display functions
include("print.jl")

# -----------------------------
# RecipesBase.plot stub - to be extended by CTModelsPlots extension
function RecipesBase.plot(sol::AbstractSolution, description::Symbol...; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
end

# Note: Base.show methods are automatically exported by Julia
# No explicit export needed for Base.show extensions

end
