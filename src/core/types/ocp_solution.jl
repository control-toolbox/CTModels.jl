# ------------------------------------------------------------------------------ #
# Continuous-time OCP solution-related types
# (time grids, solver infos, dual variables, Solution)
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
    value::T
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)
"""
struct EmptyTimeGridModel <: AbstractTimeGridModel end

is_empty(model::EmptyTimeGridModel)::Bool = true
is_empty(model::TimeGridModel)::Bool = false

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
    status::Symbol # the status criterion
    message::String # the message corresponding to the status criterion
    successful::Bool # whether or not the method has finished successfully: CN1, stagnation vs iterations max
    constraints_violation::Float64 # the constraints violation
    infos::TI # additional information
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
    PC_Dual<:Union{Function,Nothing},
    BC_Dual<:Union{ctVector,Nothing},
    SC_LB_Dual<:Union{Function,Nothing},
    SC_UB_Dual<:Union{Function,Nothing},
    CC_LB_Dual<:Union{Function,Nothing},
    CC_UB_Dual<:Union{Function,Nothing},
    VC_LB_Dual<:Union{ctVector,Nothing},
    VC_UB_Dual<:Union{ctVector,Nothing},
} <: AbstractDualModel
    path_constraints_dual::PC_Dual
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
    ModelType<:AbstractModel,
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
    model::ModelType
end

"""
$(TYPEDSIGNATURES)

Check if the time grid is empty from the solution.
"""
is_empty_time_grid(sol::Solution)::Bool = is_empty(sol.time_grid)
