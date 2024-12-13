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
"""
$(TYPEDEF)
"""
abstract type AbstractModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct Model{
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    DynamicsModelType<:Function,
    ObjectiveModelType<:AbstractObjectiveModel,
    ConstraintsModelType<:ConstraintsDictType,
} <: AbstractModel
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    dynamics::DynamicsModelType
    objective::ObjectiveModelType
    constraints::ConstraintsModelType
    definition::Expr
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
@with_kw mutable struct PreModel <: AbstractModel
    times::Union{AbstractTimesModel,Nothing} = nothing
    state::Union{AbstractStateModel,Nothing} = nothing
    control::Union{AbstractControlModel,Nothing} = nothing
    variable::AbstractVariableModel = EmptyVariableModel()
    dynamics::Union{Function,Nothing} = nothing
    objective::Union{AbstractObjectiveModel,Nothing} = nothing
    constraints::ConstraintsDictType = ConstraintsDictType()
    definition::Union{Expr,Nothing} = nothing
end

"""
$(TYPEDSIGNATURES)

"""
__is_times_set(ocp::PreModel)::Bool = !isnothing(ocp.times)

"""
$(TYPEDSIGNATURES)

"""
__is_state_set(ocp::PreModel)::Bool = !isnothing(ocp.state)

"""
$(TYPEDSIGNATURES)

"""
__is_control_set(ocp::PreModel)::Bool = !isnothing(ocp.control)

"""
$(TYPEDSIGNATURES)

"""
__is_variable_set(ocp::PreModel)::Bool = !(ocp.variable isa EmptyVariableModel)

"""
$(TYPEDSIGNATURES)

"""
__is_dynamics_set(ocp::PreModel)::Bool = !isnothing(ocp.dynamics)

"""
$(TYPEDSIGNATURES)

"""
__is_objective_set(ocp::PreModel)::Bool = !isnothing(ocp.objective)

"""
$(TYPEDSIGNATURES)

"""
__is_definition_set(ocp::PreModel)::Bool = !isnothing(ocp.definition)
