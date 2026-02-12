# ------------------------------------------------------------------------------
# Control Initial Guess
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the control function directly when provided as a function.
"""
initial_control(::AbstractOptimalControlProblem, control::Function) = control

"""
$(TYPEDSIGNATURES)

Convert a scalar control value to a constant function for 1D control problems.

Throws `Exceptions.IncorrectArgument` if the control dimension is not 1.
"""
function initial_control(ocp::AbstractOptimalControlProblem, control::Real)
    dim = control_dimension(ocp)
    if dim == 1
        return t -> control
    else
        throw(Exceptions.IncorrectArgument(
            "Initial control dimension mismatch",
            got="scalar value",
            expected="vector of length $dim or function returning such vector",
            suggestion="Use a vector: control=[u1, u2, ..., u$dim] or a function: control=t->[...]",
            context="initial_control with scalar input"
        ))
    end
end

"""
$(TYPEDSIGNATURES)

Convert a control vector to a constant function.

Throws `Exceptions.IncorrectArgument` if the vector length does not match the control dimension.
"""
function initial_control(ocp::AbstractOptimalControlProblem, control::Vector{<:Real})
    dim = control_dimension(ocp)
    if length(control) != dim
        throw(Exceptions.IncorrectArgument(
            "Initial control dimension mismatch",
            got="vector of length $(length(control))",
            expected="vector of length $dim",
            suggestion="Provide a control vector with $dim elements: control=[u1, u2, ..., u$dim]",
            context="initial_control with vector input"
        ))
    end
    return t -> control
end

"""
$(TYPEDSIGNATURES)

Return a default control initialisation function when no control is provided.

Returns a constant function yielding `0.1` (scalar) or `fill(0.1, dim)` (vector).
"""
function initial_control(ocp::AbstractOptimalControlProblem, ::Nothing)
    dim = control_dimension(ocp)
    if dim == 1
        return t -> 0.1
    else
        return t -> fill(0.1, dim)
    end
end

"""
$(TYPEDSIGNATURES)

Handle time-grid control initialization with (time, data) tuple.

Interpolates the provided data over the time grid to create a callable function.
"""
function initial_control(ocp::AbstractOptimalControlProblem, control::Tuple)
    length(control) == 2 || throw(Exceptions.IncorrectArgument(
        "Time-grid control initialization must be a 2-tuple (time, data)",
        got="$(length(control))-tuple",
        expected="2-tuple (time, data)",
        suggestion="Use control=(time, data) format",
        context="initial_control with time-grid tuple"
    ))
    
    T, data = control
    time = _format_time_grid(T)
    return _build_time_dependent_init(ocp, :control, data, time)
end

"""
$(TYPEDSIGNATURES)

Return the control trajectory from an initial guess.
"""
control(init::AbstractInitialGuess) = init.control

"""
$(TYPEDSIGNATURES)

Return the control trajectory from a solution.
"""
control(sol::AbstractOptimalControlSolution) = sol.control
