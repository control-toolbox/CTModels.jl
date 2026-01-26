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

# Errors
Throws `CTBase.UnauthorizedCall` if the time dependence has already been set.

# Example
```julia-repl
julia> ocp = PreModel(...)
julia> time_dependence!(ocp; autonomous=true)
```
"""
function time_dependence!(ocp::PreModel; autonomous::Bool)::Nothing
    @ensure !__is_autonomous_set(ocp) CTBase.UnauthorizedCall(
        "the time dependence has already been set."
    )
    ocp.autonomous = autonomous
    return nothing
end

"""
$(TYPEDSIGNATURES)

Check whether the system is autonomous.

# Arguments
- `ocp::PreModel`: The optimal control problem.

# Returns
- `Bool`: `true` if the system is autonomous (i.e., does not explicitly depend on time), `false` otherwise.

# Example
```julia-repl
julia> is_autonomous(ocp)  # returns true or false
```
"""
is_autonomous(ocp::PreModel) = ocp.autonomous
