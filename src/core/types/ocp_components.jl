# ------------------------------------------------------------------------------ #
# Continuous-time OCP component types
# (time dependence, state/control/variable models, time models, objectives, constraints)
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type TimeDependence end

"""
$(TYPEDEF)
"""
abstract type Autonomous<:TimeDependence end

"""
$(TYPEDEF)
"""
abstract type NonAutonomous<:TimeDependence end

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
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct StateModelSolution{TS<:Function} <: AbstractStateModel
    name::String
    components::Vector{String}
    value::TS
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
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct ControlModelSolution{TS<:Function} <: AbstractControlModel
    name::String
    components::Vector{String}
    value::TS
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
struct VariableModel <: AbstractVariableModel
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct EmptyVariableModel <: AbstractVariableModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct VariableModelSolution{TS<:Union{ctNumber,ctVector}} <: AbstractVariableModel
    name::String
    components::Vector{String}
    value::TS
end

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
struct FixedTimeModel{T<:Time} <: AbstractTimeModel
    time::T
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
struct TimesModel{TI<:AbstractTimeModel,TF<:AbstractTimeModel} <: AbstractTimesModel
    initial::TI
    final::TF
    time_name::String
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractObjectiveModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct MayerObjectiveModel{TM<:Function} <: AbstractObjectiveModel
    mayer::TM
    criterion::Symbol
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct LagrangeObjectiveModel{TL<:Function} <: AbstractObjectiveModel
    lagrange::TL
    criterion::Symbol
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct BolzaObjectiveModel{TM<:Function,TL<:Function} <: AbstractObjectiveModel
    mayer::TM
    lagrange::TL
    criterion::Symbol
end

# ------------------------------------------------------------------------------ #
# Constraints
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractConstraintsModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct ConstraintsModel{TP<:Tuple,TB<:Tuple,TS<:Tuple,TC<:Tuple,TV<:Tuple} <:
       AbstractConstraintsModel
    path_nl::TP
    boundary_nl::TB
    state_box::TS
    control_box::TC
    variable_box::TV
end
