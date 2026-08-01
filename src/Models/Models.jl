"""
    Models

Immutable optimal control problem model type and all its accessor methods.

Provides `AbstractModel`, `struct Model` (parametric over time dependence and
component types), and all reader functions that operate on a built `Model`.

# Organisation

- **model.jl**: AbstractModel, Model struct, and all accessor functions ([`CTModels.Components.state`](@extref), [`CTModels.Components.control`](@extref), [`CTModels.Components.variable`](@extref), [`CTModels.Components.times`](@extref), [`CTModels.Components.objective`](@extref), [`CTModels.Models.constraints`](@extref), [`CTModels.Models.dynamics`](@extref), [`CTModels.Models.definition`](@extref))

# Public API

The following functions are exported and accessible as `CTModels.function_name()`:

- **Types**: [`CTModels.Models.AbstractModel`](@extref), [`CTModels.Models.Model`](@extref)
- **Time dependence predicates**: `is_autonomous`, `is_nonautonomous`
- **Variable / control presence predicates**: `is_variable`, `is_nonvariable`, `is_control_free`, `has_variable`, `has_control`, `has_abstract_definition`, `is_abstractly_defined`
- **Component field accessors**: [`CTModels.Components.state`](@extref), [`CTModels.Components.control`](@extref), [`CTModels.Components.variable`](@extref), [`CTModels.Components.times`](@extref), [`CTModels.Components.objective`](@extref), [`CTModels.Models.constraints`](@extref), [`CTModels.Models.dynamics`](@extref), [`CTModels.Models.definition`](@extref)
- **Named accessors on state/control/variable**: [`CTModels.Models.state_name`](@extref), [`CTModels.Models.state_components`](@extref), [`CTModels.Models.state_dimension`](@extref), [`CTModels.Models.control_name`](@extref), [`CTModels.Models.control_components`](@extref), [`CTModels.Models.control_dimension`](@extref), [`CTModels.Models.variable_name`](@extref), [`CTModels.Models.variable_components`](@extref), [`CTModels.Models.variable_dimension`](@extref)
- **ExaModels builder**: [`CTModels.Models.get_build_examodel`](@extref)
- **Constraints helpers**: [`CTModels.Models.isempty_constraints`](@extref), [`CTModels.Models.constraint`](@extref)

# Dependencies

Depends on `Components` for foundational types and low-level accessor functions.

See also: [`CTModels.Components`](@extref), [`CTModels.Building`](@extref), [`CTModels.Solutions`](@extref), [`CTModels.Init`](@extref).
"""
module Models

using CTBase: CTBase, Core, Exceptions, Traits
# Time/variable/control-dependence predicates are generic functions owned by
# CTBase.Traits; CTModels only provides the `Model` trait contract (see model.jl)
# and re-exports them.
using CTBase:
    is_autonomous,
    is_nonautonomous,
    is_variable,
    is_nonvariable,
    has_variable,
    is_control_free,
    has_control
using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

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
