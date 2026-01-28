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

Throws `CTBase.IncorrectArgument` if the control dimension is not 1.
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

Throws `CTBase.IncorrectArgument` if the vector length does not match the control dimension.
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

Return the control trajectory from an initial guess.
"""
control(init::AbstractOptimalControlInitialGuess) = init.control

"""
$(TYPEDSIGNATURES)

Return the control trajectory from a solution.
"""
control(sol::AbstractOptimalControlSolution) = sol.control
