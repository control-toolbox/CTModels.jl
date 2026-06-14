"""
    Components

Foundational component types and accessors for optimal control problems.

Provides type aliases, abstract and concrete component types (state, control,
variable, time, objective, constraints, definitions), and their accessors.

All downstream modules (`Models`, `OCP`, `Display`, `Serialization`, `Init`) depend on
this module. It has no sibling dependencies.

# Organisation

- **aliases.jl**: Type aliases ([`CTModels.Components.Dimension`](@ref), [`CTModels.Components.ctNumber`](@ref), [`CTModels.Components.Time`](@ref), etc.)
- **types.jl**: Abstract and concrete component types ([`CTModels.Components.StateModel`](@ref), [`CTModels.Components.ControlModel`](@ref), etc.)
- **accessors.jl**: Accessor methods for state, control, variable, and definition models
- **times_accessors.jl**: Accessor methods for time models ([`CTModels.Components.TimesModel`](@ref))
- **objective_accessors.jl**: Accessor methods for objective models ([`CTModels.Components.MayerObjectiveModel`](@ref), etc.)
- **constraints_accessors.jl**: Accessor methods for constraints models ([`CTModels.Components.ConstraintsModel`](@ref))

# Dependencies

External: `OrderedCollections` (for [`CTModels.Components.ConstraintsDictType`](@ref)), `CTBase`.

See also: [`CTModels.Building`](@ref), [`CTModels.Models`](@ref).
"""
module Components

import CTBase.Core
import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using OrderedCollections: OrderedCollections

include(joinpath(@__DIR__, "functors.jl"))
include(joinpath(@__DIR__, "aliases.jl"))
include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "accessors.jl"))
include(joinpath(@__DIR__, "times_accessors.jl"))
include(joinpath(@__DIR__, "objective_accessors.jl"))
include(joinpath(@__DIR__, "constraints_accessors.jl"))

# Type aliases
export Dimension, ctNumber, Time, ctVector, Times, TimesDisc, ConstraintsDictType

# Time dependence
export TimeDependence, Autonomous, NonAutonomous

# State
export AbstractStateModel, StateModel, StateModelSolution

# Control
export AbstractControlModel, ControlModel, ControlModelSolution, EmptyControlModel

# Variable
export AbstractVariableModel, VariableModel, VariableModelSolution, EmptyVariableModel

# Time models
export AbstractTimeModel, FixedTimeModel, FreeTimeModel
export AbstractTimesModel, TimesModel

# Objective
export AbstractObjectiveModel
export MayerObjectiveModel, LagrangeObjectiveModel, BolzaObjectiveModel

# Constraints
export AbstractConstraintsModel, ConstraintsModel

# Definition
export AbstractDefinition, EmptyDefinition, Definition

# Component accessor functions (name/dim/value/etc.)
export name, components, dimension, value, interpolation, expression

# Time model accessors
export index, initial, final
export time_name, initial_time_name, final_time_name
export initial_time, final_time
export has_fixed_initial_time, has_free_initial_time
export has_fixed_final_time, has_free_final_time
export is_initial_time_fixed, is_initial_time_free
export is_final_time_fixed, is_final_time_free

# Objective model accessors
export criterion, mayer, lagrange
export has_mayer_cost, has_lagrange_cost
export is_mayer_cost_defined, is_lagrange_cost_defined

# Constraints model accessors
export path_constraints_nl, boundary_constraints_nl
export state_constraints_box, control_constraints_box, variable_constraints_box
export dim_path_constraints_nl, dim_boundary_constraints_nl
export dim_state_constraints_box, dim_control_constraints_box, dim_variable_constraints_box

end # module Components
