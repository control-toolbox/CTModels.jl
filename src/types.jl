# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractStateModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct StateModel <: AbstractStateModel
    dimension::Dimension
    name::String
    components::Vector{String}
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractControlModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct ControlModel <: AbstractControlModel
    dimension::Dimension
    name::String
    components::Vector{String}
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractOptimalControlModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct OptimalControlModel{
    ControlModelType <: AbstractControlModel,
    StateModelType <: AbstractStateModel,
} <: AbstractOptimalControlModel
    control::ControlModelType
    state::StateModelType
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
@with_kw mutable struct OptimalControlModelMutable <: AbstractOptimalControlModel
    control::Union{AbstractControlModel, Nothing} = nothing
    state::Union{AbstractStateModel, Nothing} = nothing
end
