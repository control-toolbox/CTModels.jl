# ------------------------------------------------------------------------------ #
# Continuous-time OCP model types (Model, PreModel and consistency helpers)
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
