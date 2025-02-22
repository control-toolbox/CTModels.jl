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

```@example
julia> function mayer(x0, xf, v)
           return x0[1] + xf[1] + v[1]
       end
juila> function lagrange(t, x, u, v)
           return x[1] + u[1] + v[1]
       end
julia> objective!(ocp, :min, mayer=mayer, lagrange=lagrange)
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
criterion(model::MayerObjectiveModel)::Symbol = model.criterion
(mayer(model::MayerObjectiveModel{M})::M) where {M<:Function} = model.mayer
function lagrange(model::MayerObjectiveModel)
    throw(
        CTBase.UnauthorizedCall(
            "a Mayer objective model does not have a Lagrange function."
        ),
    )
end
has_mayer_cost(model::MayerObjectiveModel)::Bool = true
has_lagrange_cost(model::MayerObjectiveModel)::Bool = false

# From LagrangeObjectiveModel
criterion(model::LagrangeObjectiveModel)::Symbol = model.criterion
function mayer(model::LagrangeObjectiveModel)
    throw(
        CTBase.UnauthorizedCall(
            "a Lagrange objective model does not have a Mayer function."
        ),
    )
end
(lagrange(model::LagrangeObjectiveModel{L})::L) where {L<:Function} = model.lagrange
has_mayer_cost(model::LagrangeObjectiveModel)::Bool = false
has_lagrange_cost(model::LagrangeObjectiveModel)::Bool = true

# From BolzaObjectiveModel
criterion(model::BolzaObjectiveModel)::Symbol = model.criterion
(mayer(model::BolzaObjectiveModel{M,L})::M) where {M<:Function,L<:Function} = model.mayer
(lagrange(model::BolzaObjectiveModel{M,L})::L) where {M<:Function,L<:Function} =
    model.lagrange
has_mayer_cost(model::BolzaObjectiveModel)::Bool = true
has_lagrange_cost(model::BolzaObjectiveModel)::Bool = true