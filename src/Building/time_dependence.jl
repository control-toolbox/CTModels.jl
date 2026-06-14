"""
$(TYPEDSIGNATURES)

Set the time dependence of the optimal control problem `ocp`.

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `autonomous::Bool`: Indicates whether the system is autonomous (`true`) or time-dependent (`false`).

# Preconditions
- The time dependence must not have been set previously.

# Behavior
This function sets the `autonomous` field of the model to indicate whether the system's dynamics
explicitly depend on time. It can only be called once.

# Throws
- `Exceptions.PreconditionError`: If the time dependence has already been set.

# Example
```julia-repl
julia> using CTModels

julia> ocp = PreModel(); time_dependence!(ocp; autonomous=true)
```

# Returns
- `Nothing`

See also: [`CTModels.Building.time!`](@ref), [`CTModels.Building.dynamics!`](@ref).
"""
function time_dependence!(ocp::PreModel; autonomous::Bool)::Nothing
    Core.@ensure !__is_autonomous_set(ocp) Exceptions.PreconditionError(
        "Time dependence already set",
        reason="time dependence has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing time dependence definition",
        context="time_dependence! function - duplicate definition check",
    )
    ocp.autonomous = autonomous
    return nothing
end
