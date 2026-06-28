"""
$(TYPEDSIGNATURES)

Set the time dependence of the optimal control problem `ocp`.

Must be called exactly once, after declaring the spaces and dynamics but before
calling [`CTModels.Building.build`](@ref).

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `autonomous::Bool`: `true` for an autonomous system ``\\dot{x}=f(x,u,v)``,
  `false` for a non-autonomous system ``\\dot{x}=f(t,x,u,v)``.

# Returns
- `Nothing`

# Throws
- `Exceptions.PreconditionError`: If time dependence has already been set.

# Examples
```julia-repl
julia> using CTModels

julia> ocp = CTModels.PreModel(); CTModels.time_dependence!(ocp; autonomous=true);
```

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
