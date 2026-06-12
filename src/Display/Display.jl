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

# Import types from parent module (will be available after CTModels loads this)
# These are forward declarations - actual types defined in OCP module
import ..OCP: Model, PreModel, Solution, AbstractSolution
import ..OCP: AbstractDefinition, Definition, EmptyDefinition

# Import internal helpers from OCP for display
import ..OCP: __is_empty, definition, __is_consistent
import ..OCP: __is_variable_empty, __is_control_empty
import ..OCP: state_dimension, control_dimension, variable_dimension
import ..OCP: time_name, initial_time_name, final_time_name
import ..OCP: dimension, name, state_name, control_name, variable_name
import ..OCP: components, state_components, control_components, variable_components
import ..OCP: is_autonomous, has_lagrange_cost, has_mayer_cost, is_variable, is_control_free
import ..OCP: dim_path_constraints_nl, dim_boundary_constraints_nl
import ..OCP:
    dim_state_constraints_box, dim_control_constraints_box, dim_variable_constraints_box
import ..OCP: build

# Include display functions (split by responsibility)
include(joinpath(@__DIR__, "ansi.jl"))
include(joinpath(@__DIR__, "definition.jl"))
include(joinpath(@__DIR__, "mathematical.jl"))
include(joinpath(@__DIR__, "model.jl"))
include(joinpath(@__DIR__, "pre_model.jl"))

# -----------------------------
# RecipesBase.plot stub - to be extended by CTModelsPlots extension
function RecipesBase.plot(sol::AbstractSolution, description::Symbol...; kwargs...)
    throw(Exceptions.ExtensionError(:Plots; message="to plot solutions"))
end

# Note: Base.show methods are automatically exported by Julia
# No explicit export needed for Base.show extensions

end
