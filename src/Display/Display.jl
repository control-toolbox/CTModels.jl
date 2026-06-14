"""
    Display

Display and formatting module for CTModels.

This module provides functions for displaying and formatting optimal control
problems and solutions in human-readable formats.

# Organisation

- **ansi.jl**: ANSI helpers and generic Expr printing ([`_ansi_color`](@ref), [`_print_ansi_styled`](@ref))
- **definition.jl**: Abstract (symbolic) definition printing ([`_print_abstract_definition`](@ref))
- **mathematical.jl**: Mathematical definition printing ([`__print_mathematical_definition`](@ref))
- **model.jl**: Display for [`CTModels.Models.Model`](@ref)
- **pre_model.jl**: Display for [`CTModels.Building.PreModel`](@ref)
- **solution.jl**: Display for [`CTModels.Solutions.Solution`](@ref)

# Public API

The following functions are exported and accessible via `Base.show`:

- `Base.show(io::IO, ::MIME"text/plain", ocp::CTModels.Models.Model)`: Display an optimal control problem
- `Base.show(io::IO, ::MIME"text/plain", sol::CTModels.Solutions.Solution)`: Display a solution

# Private API

The following are internal utilities (accessible via `Display.function_name`):

- `__print`: Internal printing helper
- `__print_abstract_definition`: Print abstract OCP definition
- `__print_mathematical_definition`: Print mathematical OCP formulation

# Dependencies

External: `MLStyle`, `RecipesBase`, `MacroTools`.

See also: `CTModels.Components`, `CTModels.Models`, `CTModels.Building`, `CTModels.Solutions`.
"""
module Display

import CTBase.Exceptions
import DocStringExtensions: TYPEDSIGNATURES

using CTBase: CTBase
using MLStyle: MLStyle
using RecipesBase: RecipesBase
using MacroTools: MacroTools

using ..Components
using ..Models
using ..Building
using ..Solutions

# Include display functions (split by responsibility)
include(joinpath(@__DIR__, "ansi.jl"))
include(joinpath(@__DIR__, "definition.jl"))
include(joinpath(@__DIR__, "mathematical.jl"))
include(joinpath(@__DIR__, "model.jl"))
include(joinpath(@__DIR__, "pre_model.jl"))
include(joinpath(@__DIR__, "solution.jl"))

# -----------------------------
# RecipesBase.plot stub - to be extended by CTModelsPlots extension
function RecipesBase.plot(sol::Solutions.AbstractSolution, description::Symbol...; kwargs...)
    throw(Exceptions.ExtensionError(:Plots; message="to plot solutions"))
end

# Note: Base.show methods are automatically exported by Julia
# No explicit export needed for Base.show extensions

end
