"""
$(TYPEDSIGNATURES)

Set the objective of the optimal control problem.

# Arguments

- `ocp::PreModel`: the optimal control problem.
- `criterion::Symbol`: the type of criterion. Either :min, :max, :MIN, or :MAX (case-insensitive). Default is :min.
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
julia> function lagrange(t, x, u, v)
           return x[1] + u[1] + v[1]
       end
julia> objective!(ocp, :min, mayer=mayer, lagrange=lagrange)
```

# Throws

- `Exceptions.PreconditionError`: If state has not been set
- `Exceptions.PreconditionError`: If control has not been set
- `Exceptions.PreconditionError`: If times has not been set
- `Exceptions.PreconditionError`: If objective has already been set
- `Exceptions.IncorrectArgument`: If criterion is not :min, :max, :MIN, or :MAX
- `Exceptions.IncorrectArgument`: If neither mayer nor lagrange function is provided
"""
function objective!(
    ocp::PreModel,
    criterion::Symbol=__criterion_type();
    mayer::Union{Function,Nothing}=nothing,
    lagrange::Union{Function,Nothing}=nothing,
)::Nothing

    # checks: times, state, and control must be set before the objective
    @ensure __is_state_set(ocp) Exceptions.PreconditionError(
        "State must be set before objective",
        reason="state has not been defined yet",
        suggestion="Call state!(ocp, dimension) before objective!(ocp, ...)",
        context="objective! function - state validation"
    )
    @ensure __is_control_set(ocp) Exceptions.PreconditionError(
        "Control must be set before objective",
        reason="control has not been defined yet",
        suggestion="Call control!(ocp, dimension) before objective!(ocp, ...)",
        context="objective! function - control validation"
    )
    @ensure __is_times_set(ocp) Exceptions.PreconditionError(
        "Times must be set before objective",
        reason="time horizon has not been defined yet",
        suggestion="Call time!(ocp, t0, tf) before objective!(ocp, ...)",
        context="objective! function - times validation"
    )

    # checks: the objective must not already be set
    @ensure !__is_objective_set(ocp) Exceptions.PreconditionError(
        "Objective already set",
        reason="objective has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing objective definition",
        context="objective! function - duplicate definition check"
    )

    # NEW: Validate criterion (case-insensitive)
    @ensure criterion ∈ (:min, :max, :MIN, :MAX) Exceptions.IncorrectArgument(
        "Invalid optimization criterion",
        got=":$criterion",
        expected=":min, :max, :MIN, or :MAX",
        suggestion="Use objective!(ocp, :min, ...) for minimization or objective!(ocp, :max, ...) for maximization",
        context="objective!(ocp, criterion=:$criterion, ...) - validating criterion parameter"
    )

    # Normalize criterion to lowercase for consistency
    normalized_criterion = criterion in (:MIN, :MAX) ? 
        (criterion == :MIN ? :min : :max) : criterion

    # checks: at least one of the two functions must be given
    @ensure !(isnothing(mayer) && isnothing(lagrange)) Exceptions.IncorrectArgument(
        "Missing objective function",
        got="neither mayer nor lagrange provided",
        expected="at least one of mayer or lagrange function",
        suggestion="Provide mayer=function for terminal cost, lagrange=function for running cost, or both for Bolza problem",
        context="objective! function validation"
    )

    # set the objective
    if !isnothing(mayer) && isnothing(lagrange)
        ocp.objective = MayerObjectiveModel(mayer, normalized_criterion)
    elseif isnothing(mayer) && !isnothing(lagrange)
        ocp.objective = LagrangeObjectiveModel(lagrange, normalized_criterion)
    else
        ocp.objective = BolzaObjectiveModel(mayer, lagrange, normalized_criterion)
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

# ------------------------------------------------------------------------------ #
# ALIASES (for naming consistency)
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Alias for [`has_mayer_cost`](@ref). Check if the objective has a Mayer (terminal) cost defined.

# Example
```julia-repl
julia> is_mayer_cost_defined(obj)  # equivalent to has_mayer_cost(obj)
```

See also: [`has_mayer_cost`](@ref), [`is_lagrange_cost_defined`](@ref).
"""
const is_mayer_cost_defined = has_mayer_cost

"""
$(TYPEDSIGNATURES)

Alias for [`has_lagrange_cost`](@ref). Check if the objective has a Lagrange (integral) cost defined.

# Example
```julia-repl
julia> is_lagrange_cost_defined(obj)  # equivalent to has_lagrange_cost(obj)
```

See also: [`has_lagrange_cost`](@ref), [`is_mayer_cost_defined`](@ref).
"""
const is_lagrange_cost_defined = has_lagrange_cost
