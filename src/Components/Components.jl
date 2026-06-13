"""
    Components

Foundational component types and accessors for optimal control problems.

Provides type aliases, abstract and concrete component types (state, control,
variable, time, objective, constraints, definitions), and their basic accessors
(`name`, `components`, `dimension`, `value`, `interpolation`, `expression`).

All downstream modules (`OCP`, `Display`, `Serialization`, `Init`) depend on
this module. It has no sibling dependencies.

# Dependencies

External: `OrderedCollections` (for `ConstraintsDictType`).
"""
module Components

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using OrderedCollections: OrderedCollections

include(joinpath(@__DIR__, "aliases.jl"))
include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "accessors.jl"))

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

# Accessor functions
export name, components, dimension, value, interpolation, expression

end # module Components
