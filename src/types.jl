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
    TD<:TimeDependence,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    DynamicsModelType<:Function,
    ObjectiveModelType<:AbstractObjectiveModel,
    ConstraintsModelType<:AbstractConstraintsModel,
    BuildExaModelType<:Union{Function,Nothing},
} <: AbstractModel
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    dynamics::DynamicsModelType
    objective::ObjectiveModelType
    constraints::ConstraintsModelType
    definition::Expr
    build_examodel::BuildExaModelType

    function Model{TD}(  # TD must be specified explicitly
        times::AbstractTimesModel,
        state::AbstractStateModel,
        control::AbstractControlModel,
        variable::AbstractVariableModel,
        dynamics::Function,
        objective::AbstractObjectiveModel,
        constraints::AbstractConstraintsModel,
        definition::Expr,
        build_examodel::Union{Function,Nothing},
    ) where {TD<:TimeDependence}
        return new{
            TD,
            typeof(times),
            typeof(state),
            typeof(control),
            typeof(variable),
            typeof(dynamics),
            typeof(objective),
            typeof(constraints),
            typeof(build_examodel),
        }(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )
    end
end

"""
$(TYPEDSIGNATURES)

"""
__is_times_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

"""
__is_state_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

"""
__is_control_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

"""
__is_variable_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

"""
__is_dynamics_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

"""
__is_objective_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

"""
__is_definition_set(ocp::Model)::Bool = true

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
    dynamics::Union{Function,Vector{<:Tuple{<:AbstractRange{<:Int},<:Function}},Nothing} =
        nothing
    objective::Union{AbstractObjectiveModel,Nothing} = nothing
    constraints::ConstraintsDictType = ConstraintsDictType()
    definition::Union{Expr,Nothing} = nothing
    autonomous::Union{Bool,Nothing} = nothing
end

"""
$(TYPEDSIGNATURES)

"""
__is_set(x) = !isnothing(x)

"""
$(TYPEDSIGNATURES)

"""
__is_autonomous_set(ocp::PreModel)::Bool = __is_set(ocp.autonomous)

"""
$(TYPEDSIGNATURES)

"""
__is_times_set(ocp::PreModel)::Bool = __is_set(ocp.times)

"""
$(TYPEDSIGNATURES)

"""
__is_state_set(ocp::PreModel)::Bool = __is_set(ocp.state)

"""
$(TYPEDSIGNATURES)

"""
__is_control_set(ocp::PreModel)::Bool = __is_set(ocp.control)

"""
$(TYPEDSIGNATURES)

"""
__is_variable_empty(v) = v isa EmptyVariableModel

"""
$(TYPEDSIGNATURES)

"""
__is_variable_set(ocp::PreModel)::Bool = !__is_variable_empty(ocp.variable)

"""
$(TYPEDSIGNATURES)

"""
__is_dynamics_set(ocp::PreModel)::Bool = __is_set(ocp.dynamics)

"""
$(TYPEDSIGNATURES)

"""
__is_objective_set(ocp::PreModel)::Bool = __is_set(ocp.objective)

"""
$(TYPEDSIGNATURES)

"""
__is_definition_set(ocp::PreModel)::Bool = __is_set(ocp.definition)

"""
$(TYPEDSIGNATURES)

"""
function state_dimension(ocp::PreModel)::Dimension
    @ensure(__is_state_set(ocp), CTBase.UnauthorizedCall("the state must be set."))
    return length(ocp.state.components)
end

"""
$(TYPEDSIGNATURES)

"""
function __is_dynamics_complete(ocp::PreModel)::Bool
    if isnothing(ocp.dynamics)
        return false
    elseif ocp.dynamics isa Function
        return true
    else # ocp.dynamics isa Vector{<:Tuple{<:AbstractRange{<:Int},<:Function}}
        @ensure(__is_state_set(ocp), CTBase.UnauthorizedCall("the state must be set."))
        n = state_dimension(ocp)
        covered = falses(n)
        for (range, _) in ocp.dynamics
            for i in range
                if 1 <= i <= n
                    covered[i] = true
                else
                    throw(
                        CTBase.UnauthorizedCall(
                            "Dynamics index $i out of bounds for state of size $n."
                        ),
                    )
                end
            end
        end
        return all(covered)
    end
end

"""
$(TYPEDSIGNATURES)

Return true if all the required fields are set in the PreModel.
"""
function __is_consistent(ocp::PreModel)::Bool
    return __is_times_set(ocp) &&
           __is_state_set(ocp) &&
           __is_control_set(ocp) &&
           __is_dynamics_complete(ocp) &&
           __is_objective_set(ocp) &&
           __is_autonomous_set(ocp)
end

"""
$(TYPEDSIGNATURES)

Return true if the PreModel can be built into a Model.
"""
function __is_complete(ocp::PreModel)::Bool
    return __is_times_set(ocp) &&
           __is_state_set(ocp) &&
           __is_control_set(ocp) &&
           __is_dynamics_complete(ocp) &&
           __is_objective_set(ocp) &&
           __is_definition_set(ocp) &&
           __is_autonomous_set(ocp)
end

"""
$(TYPEDSIGNATURES)

Return true if nothing has been set.
"""
function __is_empty(ocp::PreModel)::Bool
    return !__is_times_set(ocp) &&
           !__is_state_set(ocp) &&
           !__is_control_set(ocp) &&
           !__is_dynamics_set(ocp) &&
           !__is_objective_set(ocp) &&
           !__is_definition_set(ocp) &&
           !__is_variable_set(ocp) &&
           !__is_autonomous_set(ocp) &&
           Base.isempty(ocp.constraints)
end

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
