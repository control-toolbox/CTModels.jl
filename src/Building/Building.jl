"""
    Building

Building module for CTModels — assembles [`CTModels.Building.PreModel`](@ref) (mutable problem under
construction), all component mutators, and the [`CTModels.Building.build`](@ref) / [`CTModels.Building.build_model`](@ref) functions
that convert a finished [`CTModels.Building.PreModel`](@ref) into an immutable [`CTModels.Models.Model`](@ref).

# Organisation

- **defaults.jl**: default names, labels, and criterion for mutators.
- **pre_model.jl**: [`CTModels.Building.PreModel`](@ref) struct and `__is_*` consistency helpers.
- **time_dependence.jl**: [`CTModels.Building.time_dependence!`](@ref) mutator.
- **name_validation.jl**: `__validate_name_uniqueness` and friends.
- **state.jl / control.jl / variable.jl / times.jl**: component mutators.
- **dynamics.jl / objective.jl / constraints.jl / definition.jl**: remaining mutators.
- **build.jl**: [`CTModels.Building.append_box_constraints!`](@ref), [`CTModels.Building.build`](@ref)([`CTModels.Components.ConstraintsDictType`](@ref)),
  [`CTModels.Building.build`](@ref)([`CTModels.Building.PreModel`](@ref)), [`CTModels.Building.build_model`](@ref).

See also: [`CTModels.Components`](@ref), [`CTModels.Models`](@ref).
"""
module Building

import CTBase.Core
import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import Parameters: @with_kw

using CTBase: CTBase
using MLStyle: MLStyle

# Foundational types and type aliases
using ..Components

# AbstractModel, Model, and their accessor methods
using ..Models

include(joinpath(@__DIR__, "defaults.jl"))
include(joinpath(@__DIR__, "pre_model.jl"))
include(joinpath(@__DIR__, "time_dependence.jl"))
include(joinpath(@__DIR__, "name_validation.jl"))
include(joinpath(@__DIR__, "state.jl"))
include(joinpath(@__DIR__, "control.jl"))
include(joinpath(@__DIR__, "variable.jl"))
include(joinpath(@__DIR__, "times.jl"))
include(joinpath(@__DIR__, "dynamics.jl"))
include(joinpath(@__DIR__, "objective.jl"))
include(joinpath(@__DIR__, "constraints.jl"))
include(joinpath(@__DIR__, "definition.jl"))
include(joinpath(@__DIR__, "constraint_composers.jl"))
include(joinpath(@__DIR__, "build.jl"))

# PreModel type
export PreModel

# Component mutators
export state!, control!, variable!
export time!, dynamics!, objective!, constraint!
export definition!, time_dependence!

# Build functions
export build, build_model
export append_box_constraints!

end
