"""
$(TYPEDSIGNATURES)

Set the objective of the optimal control problem.

# Arguments

- `ocp::PreModel`: the optimal control problem.
- `criterion::Symbol`: the type of criterion. Either :min or :max. Default is :min.
- `mayer::Union{Function, Nothing}`: the Mayer function (inplace). Default is nothing.
- `lagrange::Union{Function, Nothing}`: the Lagrange function (inplace). Default is nothing.

!!! note

    - The state, control and variable must be set before the objective.
    - The objective must not be set before.
    - At least one of the two functions must be given. Please provide a Mayer or a Lagrange function.

# Examples

```julia-repl
julia> function mayer(x0, xf, v)
           return x0[1] + xf[1] + v[1]
       end
juila> function lagrange(t, x, u, v)
           return x[1] + u[1] + v[1]
       end
julia> objective!(ocp, :min, mayer=mayer, lagrange=lagrange)
```
"""
function objective!(
    ocp::PreModel,
    criterion::Symbol=__criterion_type();
    mayer::Union{Function,Nothing}=nothing,
    lagrange::Union{Function,Nothing}=nothing,
)::Nothing

    # checkings: times, state, and control must be set before the objective
    @ensure __is_state_set(ocp) CTBase.UnauthorizedCall(
        "the state must be set before the objective."
    )
    @ensure __is_control_set(ocp) CTBase.UnauthorizedCall(
        "the control must be set before the objective."
    )
    @ensure __is_times_set(ocp) CTBase.UnauthorizedCall(
        "the times must be set before the objective."
    )

    # checkings: the objective must not already be set
    @ensure !__is_objective_set(ocp) CTBase.UnauthorizedCall(
        "the objective has already been set."
    )

    # checkings: at least one of the two functions must be given
    @ensure !(isnothing(mayer) && isnothing(lagrange)) CTBase.IncorrectArgument(
        "at least one of the two functions must be given. Please provide a Mayer or a Lagrange function.",
    )

    # set the objective
    if !isnothing(mayer) && isnothing(lagrange)
        ocp.objective = MayerObjectiveModel(mayer, criterion)
    elseif isnothing(mayer) && !isnothing(lagrange)
        ocp.objective = LagrangeObjectiveModel(lagrange, criterion)
    else
        ocp.objective = BolzaObjectiveModel(mayer, lagrange, criterion)
    end

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From MayerObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).
"""
function criterion(model::MayerObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Mayer function.
"""
function mayer(model::MayerObjectiveModel{M})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_mayer_cost(::MayerObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Return false.
"""
function has_lagrange_cost(::MayerObjectiveModel)::Bool
    return false
end

# From LagrangeObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).
"""
function criterion(model::LagrangeObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange function.
"""
function lagrange(model::LagrangeObjectiveModel{L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Return false.
"""
function has_mayer_cost(::LagrangeObjectiveModel)::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_lagrange_cost(::LagrangeObjectiveModel)::Bool
    return true
end

# From BolzaObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).
"""
function criterion(model::BolzaObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Mayer function.
"""
function mayer(model::BolzaObjectiveModel{M,<:Function})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange function.
"""
function lagrange(model::BolzaObjectiveModel{<:Function,L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_mayer_cost(::BolzaObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_lagrange_cost(::BolzaObjectiveModel)::Bool
    return true
end
