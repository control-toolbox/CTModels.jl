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

    # checkings: times, state and control and variable must be set before the objective
    !__is_state_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the state must be set before the objective."))
    !__is_control_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the control must be set before the objective."))
    !__is_times_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the times must be set before the objective."))

    # checkings: the objective must not be set before
    __is_objective_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the objective has already been set."))

    # checkings: at least one of the two functions must be given
    isnothing(mayer) &&
        isnothing(lagrange) &&
        throw(
            CTBase.IncorrectArgument(
                "at least one of the two functions must be given. Please provide a Mayer or a Lagrange function.",
            ),
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

Get the criterion (:min or :max) of the Mayer objective model.
"""
function criterion(model::MayerObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Get the Mayer function of the Mayer objective model.
"""
function mayer(model::MayerObjectiveModel{M})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Check if the Mayer objective model has a Mayer function. Return true.
"""
function has_mayer_cost(model::MayerObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Check if the Mayer objective model has a Lagrange function. Return false.
"""
function has_lagrange_cost(model::MayerObjectiveModel)::Bool
    return false
end

# From LagrangeObjectiveModel
"""
$(TYPEDSIGNATURES)

Get the criterion (:min or :max) of the Lagrange objective model.
"""
function criterion(model::LagrangeObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Get the Lagrange function of the Lagrange objective model.
"""
function lagrange(model::LagrangeObjectiveModel{L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Check if the Lagrange objective model has a Mayer function. Return false.
"""
function has_mayer_cost(model::LagrangeObjectiveModel)::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Check if the Lagrange objective model has a Lagrange function. Return true.
"""
function has_lagrange_cost(model::LagrangeObjectiveModel)::Bool
    return true
end

# From BolzaObjectiveModel
"""
$(TYPEDSIGNATURES)

Get the criterion (:min or :max) of the Bolza objective model.
"""
function criterion(model::BolzaObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Get the Mayer function of the Bolza objective model.
"""
function mayer(model::BolzaObjectiveModel{M,<:Function})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Get the Lagrange function of the Bolza objective model.
"""
function lagrange(model::BolzaObjectiveModel{<:Function,L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Check if the Bolza objective model has a Mayer function. Return true.
"""
function has_mayer_cost(model::BolzaObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Check if the Bolza objective model has a Lagrange function. Return true.
"""
function has_lagrange_cost(model::BolzaObjectiveModel)::Bool
    return true
end
