"""
$(TYPEDSIGNATURES)

Set the objective of the optimal control problem.

# Arguments

- `ocp::PreModel`: the optimal control problem.
- `criterion::Symbol`: the type of criterion. Either :min, :max, :MIN, or :MAX (case-insensitive). Default is :min.
- `mayer::Union{Function, Nothing}`: the Mayer function (inplace). Default is nothing.
- `lagrange::Union{Function, Nothing}`: the Lagrange function (inplace). Default is nothing.

!!! note

    - The state and times must be set before the objective.
    - Control is **optional**: problems without control input (dimension 0) are fully supported.
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

    # checks: times and state must be set before the objective
    Core.@ensure __is_state_set(ocp) Exceptions.PreconditionError(
        "State must be set before objective",
        reason="state has not been defined yet",
        suggestion="Call state!(ocp, dimension) before objective!(ocp, ...)",
        context="objective! function - state validation",
    )
    Core.@ensure __is_times_set(ocp) Exceptions.PreconditionError(
        "Times must be set before objective",
        reason="time horizon has not been defined yet",
        suggestion="Call time!(ocp, t0, tf) before objective!(ocp, ...)",
        context="objective! function - times validation",
    )

    # checks: the objective must not already be set
    Core.@ensure !__is_objective_set(ocp) Exceptions.PreconditionError(
        "Objective already set",
        reason="objective has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing objective definition",
        context="objective! function - duplicate definition check",
    )

    # NEW: Validate criterion (case-insensitive)
    Core.@ensure criterion ∈ (:min, :max, :MIN, :MAX) Exceptions.IncorrectArgument(
        "Invalid optimization criterion",
        got=":$criterion",
        expected=":min, :max, :MIN, or :MAX",
        suggestion="Use objective!(ocp, :min, ...) for minimization or objective!(ocp, :max, ...) for maximization",
        context="objective!(ocp, criterion=:$criterion, ...) - validating criterion parameter",
    )

    # Normalize criterion to lowercase for consistency
    normalized_criterion =
        criterion in (:MIN, :MAX) ? (criterion == :MIN ? :min : :max) : criterion

    # checks: at least one of the two functions must be given
    Core.@ensure !(isnothing(mayer) && isnothing(lagrange)) Exceptions.IncorrectArgument(
        "Missing objective function",
        got="neither mayer nor lagrange provided",
        expected="at least one of mayer or lagrange function",
        suggestion="Provide mayer=function for terminal cost, lagrange=function for running cost, or both for Bolza problem",
        context="objective! function validation",
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

# Getters for MayerObjectiveModel/LagrangeObjectiveModel/BolzaObjectiveModel are now in
# src/Components/objective_accessors.jl.
