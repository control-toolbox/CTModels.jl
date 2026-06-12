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

"""
module Display

import CTBase.Exceptions
import DocStringExtensions: TYPEDSIGNATURES

using CTBase: CTBase
using MLStyle: MLStyle
using RecipesBase: RecipesBase
using MacroTools: MacroTools

using ..OCP

# Include display functions (split by responsibility)
include(joinpath(@__DIR__, "ansi.jl"))
include(joinpath(@__DIR__, "definition.jl"))
include(joinpath(@__DIR__, "mathematical.jl"))
include(joinpath(@__DIR__, "model.jl"))
include(joinpath(@__DIR__, "pre_model.jl"))

# -----------------------------
# RecipesBase.plot stub - to be extended by CTModelsPlots extension
function RecipesBase.plot(sol::OCP.AbstractSolution, description::Symbol...; kwargs...)
    throw(Exceptions.ExtensionError(:Plots; message="to plot solutions"))
end

# Note: Base.show methods are automatically exported by Julia
# No explicit export needed for Base.show extensions

end
