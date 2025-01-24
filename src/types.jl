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
    solution::TS
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
    solution::TS
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
struct VariableModelSolution{TS<:ctVector} <: AbstractVariableModel
    name::String
    components::Vector{String}
    solution::TS
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
struct ConstraintsModel{
    TP<:Tuple,TB<:Tuple,TS<:Tuple,TC<:Tuple,TV<:Tuple,TC_ALL<:ConstraintsDictType
} <: AbstractConstraintsModel
    path_nl::TP
    boundary_nl::TB
    state_box::TS
    control_box::TC
    variable_box::TV
    dict::TC_ALL
end

# ------------------------------------------------------------------------------ #
# Model
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
    ConstraintsModelType<:AbstractConstraintsModel,
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

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractTimeGridModel end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct TimeGridModel{T<:TimesDisc} <: AbstractTimeGridModel
    grid::T
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct EmptyTimeGridModel <: AbstractTimeGridModel end

# ------------------------------------------------------------------------------ #
# Solver infos
"""
$(TYPEDEF)
"""
abstract type AbstractSolverInfos end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct SolverInfos{TI<:Dict{Symbol,Any}} <: AbstractSolverInfos
    iterations::Int # number of iterations
    stopping::Symbol # the stopping criterion
    message::String # the message corresponding to the stopping criterion
    success::Bool # whether or not the method has finished successfully: CN1, stagnation vs iterations max
    constraints_violation::Float64 # the constraints violation
    infos::TI # additional informations
end

# ------------------------------------------------------------------------------ #
# Constraints and dual variables for the solutions
"""
$(TYPEDEF)
"""
abstract type AbstractDualModel end

"""

$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct DualModel{
    PC<:Function,
    PC_Dual<:Function,
    BC<:ctVector,
    BC_Dual<:ctVector,
    SC_LB_Dual<:Function,
    SC_UB_Dual<:Function,
    CC_LB_Dual<:Function,
    CC_UB_Dual<:Function,
    VC_LB_Dual<:ctVector,
    VC_UB_Dual<:ctVector,
} <: AbstractDualModel
    path_constraints::PC
    path_constraints_dual::PC_Dual
    boundary_constraints::BC
    boundary_constraints_dual::BC_Dual
    state_constraints_lb_dual::SC_LB_Dual
    state_constraints_ub_dual::SC_UB_Dual
    control_constraints_lb_dual::CC_LB_Dual
    control_constraints_ub_dual::CC_UB_Dual
    variable_constraints_lb_dual::VC_LB_Dual
    variable_constraints_ub_dual::VC_UB_Dual
end

# ------------------------------------------------------------------------------ #
# Solution
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)
"""
abstract type AbstractSolution end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct Solution{
    TimeGridModelType<:AbstractTimeGridModel,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    CostateModelType<:Function,
    ObjectiveValueType<:ctNumber,
    DualModelType<:AbstractDualModel,
    SolverInfosType<:AbstractSolverInfos,
} <: AbstractSolution
    time_grid::TimeGridModelType
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    costate::CostateModelType
    objective::ObjectiveValueType
    dual::DualModelType
    solver_infos::SolverInfosType
end
