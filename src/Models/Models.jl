"""
    Models

Immutable optimal control problem model type and all its accessor methods.

Provides `AbstractModel`, `struct Model` (parametric over time dependence and
component types), and all reader functions that operate on a built `Model`.

Depends on `Components` for foundational types and low-level accessor functions.
"""
module Models

import CTBase.Core
import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using ..Components

include(joinpath(@__DIR__, "model.jl"))

# Types
export AbstractModel, Model

# Time dependence predicates
export is_autonomous, is_nonautonomous

# Variable / control presence predicates
export is_variable, is_nonvariable, is_control_free
export has_variable, has_control
export has_abstract_definition, is_abstractly_defined

# Component field accessors (return sub-model structs)
export state, control, variable, times, objective, constraints, dynamics, definition

# Named accessors on state/control/variable
export state_name, state_components, state_dimension
export control_name, control_components, control_dimension
export variable_name, variable_components, variable_dimension

# ExaModels builder
export get_build_examodel

# Constraints helpers
export isempty_constraints
export constraint

end # module Models
