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
abstract type AbstractMayerFunctionModel end

"""
$(TYPEDEF)
"""
struct Mayer{TF<:Function} <: AbstractMayerFunctionModel
    f::TF
end

function (F::Mayer{<:Function})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing
    F.f(r, x0, xf, v)
    return nothing
end

"""
$(TYPEDEF)
"""
abstract type AbstractLagrangeFunctionModel end

struct Lagrange{TF<:Function} <: AbstractLagrangeFunctionModel
    f::TF
end

function (F::Lagrange{<:Function})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing 
    F.f(r, t, x, u, v)
    return nothing
end

"""
$(TYPEDEF)
"""
abstract type AbstractObjectiveModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct MayerObjectiveModel{TM <: AbstractMayerFunctionModel} <: AbstractObjectiveModel
    mayer!::TM
    criterion::Symbol
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct LagrangeObjectiveModel{TL <: AbstractLagrangeFunctionModel} <: AbstractObjectiveModel
    lagrange!::TL
    criterion::Symbol
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct BolzaObjectiveModel{
        TM <: AbstractMayerFunctionModel, 
        TL <: AbstractLagrangeFunctionModel} <: AbstractObjectiveModel
    mayer!::TM
    lagrange!::TL
    criterion::Symbol
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractDynamics end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct Dynamics{TF<:Function} <: AbstractDynamics
    f::TF
end

function (F::Dynamics{<:Function})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x, u, v)
    return nothing
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
    DynamicsModelType <: AbstractDynamics,
    ObjectiveModelType <: AbstractObjectiveModel,
} <: AbstractOptimalControlModel
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    dynamics::DynamicsModelType
    objective::ObjectiveModelType
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
@with_kw mutable struct OptimalControlModelMutable <: AbstractOptimalControlModel
    times::Union{AbstractTimesModel, Nothing} = nothing
    state::Union{AbstractStateModel, Nothing} = nothing
    control::Union{AbstractControlModel, Nothing} = nothing
    variable::AbstractVariableModel = EmptyVariableModel()
    dynamics::Union{AbstractDynamics, Nothing} = nothing
    objective::Union{AbstractObjectiveModel, Nothing} = nothing
end

"""
$(TYPEDSIGNATURES)

"""
__is_times_set(ocp::OptimalControlModelMutable)::Bool = !isnothing(ocp.times)

"""
$(TYPEDSIGNATURES)

"""
__is_state_set(ocp::OptimalControlModelMutable)::Bool = !isnothing(ocp.state)

"""
$(TYPEDSIGNATURES)

"""
__is_control_set(ocp::OptimalControlModelMutable)::Bool = !isnothing(ocp.control)

"""
$(TYPEDSIGNATURES)

"""
__is_variable_set(ocp::OptimalControlModelMutable)::Bool = !(ocp.variable isa EmptyVariableModel)

"""
$(TYPEDSIGNATURES)

"""
__is_dynamics_set(ocp::OptimalControlModelMutable)::Bool = !isnothing(ocp.dynamics)

"""
$(TYPEDSIGNATURES)

"""
__is_objective_set(ocp::OptimalControlModelMutable)::Bool = !isnothing(ocp.objective)