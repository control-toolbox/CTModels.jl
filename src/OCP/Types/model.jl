# ------------------------------------------------------------------------------ #
# PreModel and consistency helpers
# (AbstractModel and struct Model are now in src/Models/model.jl)
# ------------------------------------------------------------------------------ #

"""
$(TYPEDEF)

Mutable optimal control problem model under construction.

A `PreModel` is used to incrementally define an optimal control problem before
building it into an immutable [`Model`](@ref CTModels.OCP.Model). Fields can be set in any order
and the model is validated before building.

# Fields

- `times::Union{AbstractTimesModel,Nothing}`: Initial and final time specification.
- `state::Union{AbstractStateModel,Nothing}`: State variable structure.
- `control::AbstractControlModel`: Control variable structure (defaults to `EmptyControlModel()`, i.e. no control).
- `variable::AbstractVariableModel`: Optimisation variable (defaults to empty).
- `dynamics::Union{Function,Vector,Nothing}`: System dynamics (function or component-wise).
- `objective::Union{AbstractObjectiveModel,Nothing}`: Cost functional.
- `constraints::ConstraintsDictType`: Dictionary of constraints being built.
- `definition::AbstractDefinition`: Symbolic definition; defaults to
  [`EmptyDefinition`](@ref) and becomes a [`Definition`](@ref) when
  [`definition!`](@ref) is called with a real expression.
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
    control::AbstractControlModel = EmptyControlModel()
    variable::AbstractVariableModel = EmptyVariableModel()
    dynamics::Union{Function,Vector{<:Tuple{<:AbstractRange{<:Int},<:Function}},Nothing} =
        nothing
    objective::Union{AbstractObjectiveModel,Nothing} = nothing
    constraints::ConstraintsDictType = ConstraintsDictType()
    definition::AbstractDefinition = EmptyDefinition()
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

Return `true` if `c` is an `EmptyControlModel`.
"""
__is_control_empty(c) = c isa EmptyControlModel

"""
$(TYPEDSIGNATURES)

Return `true` if the control field of the `PreModel` is an `EmptyControlModel`.
"""
__is_control_empty(ocp::PreModel)::Bool = __is_control_empty(ocp.control)

"""
$(TYPEDSIGNATURES)

Return `true` if `v` is an `EmptyVariableModel`.
"""
__is_variable_empty(v) = v isa EmptyVariableModel

"""
$(TYPEDSIGNATURES)

Return `true` if the variable field of the `PreModel` is an `EmptyVariableModel`.
"""
__is_variable_empty(ocp::PreModel)::Bool = __is_variable_empty(ocp.variable)

"""
$(TYPEDSIGNATURES)

Return `true` if `d` is an [`EmptyDefinition`](@ref).
"""
__is_definition_empty(d) = d isa EmptyDefinition

"""
$(TYPEDSIGNATURES)

Return `true` if the definition field of the `PreModel` is an [`EmptyDefinition`](@ref).
"""
__is_definition_empty(ocp::PreModel)::Bool = __is_definition_empty(ocp.definition)

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

Return the state dimension of the `PreModel`.

# Throws

- `Exceptions.PreconditionError`: if the state has not been set yet.
"""
function Models.state_dimension(ocp::PreModel)::Dimension
    Core.@ensure(
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
        Core.@ensure(
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
           __is_dynamics_complete(ocp) &&
           __is_objective_set(ocp) &&
           __is_autonomous_set(ocp)
end

"""
$(TYPEDSIGNATURES)

Return true if nothing has been set.
"""
function __is_empty(ocp::PreModel)::Bool
    return !__is_times_set(ocp) &&
           !__is_state_set(ocp) &&
           !__is_dynamics_set(ocp) &&
           !__is_objective_set(ocp) &&
           !__is_autonomous_set(ocp) &&
           __is_control_empty(ocp) &&
           __is_variable_empty(ocp) &&
           __is_definition_empty(ocp) &&
           Base.isempty(ocp.constraints)
end
