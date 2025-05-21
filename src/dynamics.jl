"""
$(TYPEDSIGNATURES)

Set the dynamics function of a `PreModel` for an optimal control problem.

This function registers the system dynamics in the `PreModel` structure. It must be called only after the state, control, and time specifications have been set. The dynamics can only be set once.

# Arguments
- `ocp::PreModel`: A `PreModel` instance representing an unfinalized optimal control problem.
- `f::Function`: A function specifying the system dynamics, typically of the form `f(r, t, x, u, v)`.

# Throws
- `CTBase.UnauthorizedCall` if:
  - The state, control, or times have not been set before calling this function.
  - The dynamics function has already been set.

# Example
```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2)
julia> control!(ocp, 1)
julia> times!(ocp, (0.0, 1.0))

julia> dynamics!(ocp, (r, t, x, u, v) -> r .= [x[2], -x[1] + u[1]])
```
"""
function dynamics!(ocp::PreModel, f::Function)::Nothing

    # checkings: times, state and control must be set before the dynamics
    !__is_state_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the state must be set before the dynamics."))
    !__is_control_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the control must be set before the dynamics."))
    !__is_times_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the times must be set before the dynamics."))

    # checkings: the dynamics must not be set before
    __is_dynamics_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the dynamics has already been set."))

    # set the dynamics
    ocp.dynamics = f

    return nothing
end
