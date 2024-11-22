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
struct StateModel{N} <: AbstractStateModel
    name::String
    components::SVector{N, String}
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
struct ControlModel{M} <: AbstractControlModel
    name::String
    components::SVector{M, String}
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractVariableModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct VariableModel{Q} <: AbstractVariableModel
    name::String
    components::SVector{Q, String}
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct EmptyVariableModel <: AbstractVariableModel end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractTimeModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct FixedTimeModel <: AbstractTimeModel
    time::Time
    name::String
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct FreeTimeModel <: AbstractTimeModel
    index::Int
    name::String
end

"""
$(TYPEDEF)
"""
abstract type AbstractTimesModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct TimesModel{TI <: AbstractTimeModel, TF <: AbstractTimeModel} <: AbstractTimesModel
    initial::TI
    final::TF
    time_name::String
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
    TimesModelType <: AbstractTimesModel,
    StateModelType <: AbstractStateModel,
    ControlModelType <: AbstractControlModel,
    VariableModelType <: AbstractVariableModel,
} <: AbstractOptimalControlModel
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
@with_kw mutable struct OptimalControlModelMutable <: AbstractOptimalControlModel
    times::Union{AbstractTimesModel, Missing} = missing
    state::Union{AbstractStateModel, Missing} = missing
    control::Union{AbstractControlModel, Missing} = missing
    variable::Union{AbstractVariableModel, Nothing} = nothing
end
