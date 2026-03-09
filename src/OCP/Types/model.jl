# ------------------------------------------------------------------------------ #
# Continuous-time OCP model types (Model, PreModel and consistency helpers)
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for optimal control problem models.

Subtypes represent either a fully built immutable model ([`Model`](@ref CTModels.OCP.Model)) or a
mutable model under construction (`PreModel`).

See also: [`Model`](@ref CTModels.OCP.Model), `PreModel`.
"""
abstract type AbstractModel end

"""
$(TYPEDEF)

Immutable optimal control problem model containing all problem components.

A `Model` is created from a `PreModel` once all required fields have been
set. It is parameterised by the time dependence type (`Autonomous` or `NonAutonomous`)
and the types of all its components.

# Fields

- `times::TimesModelType`: Initial and final time specification.
- `state::StateModelType`: State variable structure (name, components).
- `control::ControlModelType`: Control variable structure (name, components).
- `variable::VariableModelType`: Optimisation variable structure (may be empty).
- `dynamics::DynamicsModelType`: System dynamics function `(t, x, u, v) -> ẋ`.
- `objective::ObjectiveModelType`: Cost functional (Mayer, Lagrange, or Bolza).
- `constraints::ConstraintsModelType`: All problem constraints.
- `definition::Expr`: Original symbolic definition of the problem.
- `build_examodel::BuildExaModelType`: Optional ExaModels builder function.

# Example

```julia-repl
julia> using CTModels

julia> # Models are typically created via the @def macro or PreModel
julia> ocp = CTModels.Model  # Type reference
```
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

Return `true` since times are always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_times_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` since state is always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_state_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` since control is always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_control_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` since variable is always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_variable_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` since dynamics is always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_dynamics_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` since objective is always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_objective_set(ocp::Model)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` since definition is always set in a built [`Model`](@ref CTModels.OCP.Model).
"""
__is_definition_set(ocp::Model)::Bool = true

"""
$(TYPEDEF)

Mutable optimal control problem model under construction.

A `PreModel` is used to incrementally define an optimal control problem before
building it into an immutable [`Model`](@ref CTModels.OCP.Model). Fields can be set in any order
and the model is validated before building.

# Fields

- `times::Union{AbstractTimesModel,Nothing}`: Initial and final time specification.
- `state::Union{AbstractStateModel,Nothing}`: State variable structure.
- `control::Union{AbstractControlModel,Nothing}`: Control variable structure.
- `variable::AbstractVariableModel`: Optimisation variable (defaults to empty).
- `dynamics::Union{Function,Vector,Nothing}`: System dynamics (function or component-wise).
- `objective::Union{AbstractObjectiveModel,Nothing}`: Cost functional.
- `constraints::ConstraintsDictType`: Dictionary of constraints being built.
- `definition::Union{Expr,Nothing}`: Symbolic definition expression.
- `autonomous::Union{Bool,Nothing}`: Whether the system is autonomous.

# Example

```julia-repl
julia> using CTModels

julia> pre = CTModels.PreModel()
julia> # Set fields incrementally...
```
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

Return `true` if `x` is not `nothing`.
"""
__is_set(x) = !isnothing(x)

"""
$(TYPEDSIGNATURES)

Return `true` if the autonomous flag has been set in the `PreModel`.
"""
__is_autonomous_set(ocp::PreModel)::Bool = __is_set(ocp.autonomous)

"""
$(TYPEDSIGNATURES)

Return `true` if times have been set in the `PreModel`.
"""
__is_times_set(ocp::PreModel)::Bool = __is_set(ocp.times)

"""
$(TYPEDSIGNATURES)

Return `true` if state has been set in the `PreModel`.
"""
__is_state_set(ocp::PreModel)::Bool = __is_set(ocp.state)

"""
$(TYPEDSIGNATURES)

Return `true` if control has been set in the `PreModel`.
"""
__is_control_set(ocp::PreModel)::Bool = __is_set(ocp.control)

"""
$(TYPEDSIGNATURES)

Return `true` if `v` is an `EmptyVariableModel`.
"""
__is_variable_empty(v) = v isa EmptyVariableModel

"""
$(TYPEDSIGNATURES)

Return `true` if a non-empty variable has been set in the `PreModel`.
"""
__is_variable_set(ocp::PreModel)::Bool = !__is_variable_empty(ocp.variable)

"""
$(TYPEDSIGNATURES)

Return `true` if dynamics have been set in the `PreModel`.
"""
__is_dynamics_set(ocp::PreModel)::Bool = __is_set(ocp.dynamics)

"""
$(TYPEDSIGNATURES)

Return `true` if objective has been set in the `PreModel`.
"""
__is_objective_set(ocp::PreModel)::Bool = __is_set(ocp.objective)

"""
$(TYPEDSIGNATURES)

Return `true` if definition has been set in the `PreModel`.
"""
__is_definition_set(ocp::PreModel)::Bool = __is_set(ocp.definition)

"""
$(TYPEDSIGNATURES)

Return the state dimension of the `PreModel`.

Throws `Exceptions.PreconditionError` if state has not been set.
"""
function state_dimension(ocp::PreModel)::Dimension
    @ensure(
        __is_state_set(ocp),
        Exceptions.PreconditionError(
            "State must be set before accessing dimension",
            reason="state has not been defined yet",
            suggestion="Call state!(ocp, dimension) before accessing state_dimension",
            context="state_dimension - state validation",
        )
    )
    return length(ocp.state.components)
end

"""
$(TYPEDSIGNATURES)

Return `true` if dynamics cover all state components in the `PreModel`.

For component-wise dynamics, checks that all state indices are covered.
"""
function __is_dynamics_complete(ocp::PreModel)::Bool
    if isnothing(ocp.dynamics)
        return false
    elseif ocp.dynamics isa Function
        return true
    else # ocp.dynamics isa Vector{<:Tuple{<:AbstractRange{<:Int},<:Function}}
        @ensure(
            __is_state_set(ocp),
            Exceptions.PreconditionError(
                "State must be set before checking dynamics completeness",
                reason="state has not been defined yet",
                suggestion="Call state!(ocp, dimension) before defining dynamics",
                context="__is_dynamics_complete - state validation",
            )
        )
        n = state_dimension(ocp)
        covered = falses(n)
        for (range, _) in ocp.dynamics
            for i in range
                if 1 <= i <= n
                    covered[i] = true
                else
                    throw(
                        Exceptions.PreconditionError(
                            "Dynamics index out of bounds";
                            got="dynamics index $i for state of size $n",
                            expected="indices in range 1:$n",
                            suggestion="Check dynamics indices match state dimension",
                            context="__is_dynamics_complete - validating dynamics indices",
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
