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
abstract type AbstractMayerModel end

"""
$(TYPEDEF)
"""
struct Mayer{TF<:Function, VN<:Val, VQ<:Val} <: AbstractMayerModel
    f::TF
    n_val::VN     # just to specialize the type
    q_val::VQ  # just to specialize the type
end

# constructor
Mayer(f::Function, n::Int, q::Int) = Mayer{typeof(f), Val{n}, Val{q}}(f, Val{n}(), Val{q}())

"""
$(TYPEDEF)
"""
abstract type AbstractLagrangeModel end

struct Lagrange{TF<:Function, VN<:Val, VM<:Val, VQ<:Val} <: AbstractLagrangeModel
    f::TF
    n_val::VN     # just to specialize the type
    m_val::VM   # just to specialize the type
    q_val::VQ  # just to specialize the type
end

# constructor
Lagrange(f::Function, n::Int, m::Int, q::Int) = 
    Lagrange{typeof(f), Val{n}, Val{m}, Val{q}}(f, Val{n}(), Val{m}(), Val{q}())

"""
$(TYPEDEF)
"""
abstract type AbstractObjectiveModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct MayerObjectiveModel{TM <: AbstractMayerModel} <: AbstractObjectiveModel
    mayer!::TM
    criterion::Symbol
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct LagrangeObjectiveModel{TL <: AbstractLagrangeModel} <: AbstractObjectiveModel
    lagrange!::TL
    criterion::Symbol
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct BolzaObjectiveModel{TM <: AbstractMayerModel, TL <: AbstractLagrangeModel} <: AbstractObjectiveModel
    mayer!::TM
    lagrange!::TL
    criterion::Symbol
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
    ObjectiveModelType <: AbstractObjectiveModel
} <: AbstractOptimalControlModel
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
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
__is_objective_set(ocp::OptimalControlModelMutable)::Bool = !isnothing(ocp.objective)