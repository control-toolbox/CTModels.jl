"""
    Models

Immutable optimal control problem model type and all its accessor methods.

Provides `AbstractModel`, `struct Model` (parametric over time dependence and
component types), and all reader functions that operate on a built `Model`.

# Organisation

- **model.jl**: AbstractModel, Model struct, and all accessor functions ([`CTModels.Models.state`](@ref), [`CTModels.Models.control`](@ref), [`CTModels.Models.variable`](@ref), [`CTModels.Models.times`](@ref), [`CTModels.Models.objective`](@ref), [`CTModels.Models.constraints`](@ref), [`CTModels.Models.dynamics`](@ref), [`CTModels.Models.definition`](@ref))

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- **Types**: [`CTModels.Models.AbstractModel`](@ref), [`CTModels.Models.Model`](@ref)
- **Time dependence predicates**: [`is_autonomous`](@ref), [`is_nonautonomous`](@ref)
- **Variable / control presence predicates**: [`is_variable`](@ref), [`is_nonvariable`](@ref), [`is_control_free`](@ref), [`has_variable`](@ref), [`has_control`](@ref), [`has_abstract_definition`](@ref), [`is_abstractly_defined`](@ref)
- **Component field accessors**: [`state`](@ref), [`control`](@ref), [`variable`](@ref), [`times`](@ref), [`objective`](@ref), [`constraints`](@ref), [`dynamics`](@ref), [`definition`](@ref)
- **Named accessors on state/control/variable**: [`state_name`](@ref), [`state_components`](@ref), [`state_dimension`](@ref), [`control_name`](@ref), [`control_components`](@ref), [`control_dimension`](@ref), [`variable_name`](@ref), [`variable_components`](@ref), [`variable_dimension`](@ref)
- **ExaModels builder**: [`get_build_examodel`](@ref)
- **Constraints helpers**: [`isempty_constraints`](@ref), [`constraint`](@ref)

# Dependencies

Depends on `Components` for foundational types and low-level accessor functions.

See also: [`CTModels.Components`](@ref), [`CTModels.Building`](@ref), [`CTModels.Solutions`](@ref), [`CTModels.Init`](@ref).
"""
module Models

import CTBase.Core
import CTBase.Exceptions
import CTBase.Traits
# Time/variable/control-dependence predicates are generic functions owned by
# CTBase.Traits; CTModels only provides the `Model` trait contract (see model.jl)
# and re-exports them.
import CTBase.Traits:
    is_autonomous,
    is_nonautonomous,
    is_variable,
    is_nonvariable,
    has_variable,
    is_control_free,
    has_control
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using ..Components

include(joinpath(@__DIR__, "constraint_functors.jl"))
include(joinpath(@__DIR__, "model.jl"))

# Types
export AbstractModel, Model

# Time dependence predicates
export is_autonomous, is_nonautonomous

# Variable / control presence predicates
export is_variable, is_nonvariable, is_control_free
export has_variable, has_control
export has_abstract_definition, is_abstractly_defined

# Component field accessors (return sub-model structs) — state/control/variable/times/objective owned by Components
export constraints, dynamics, definition

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
