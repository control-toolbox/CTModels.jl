# ------------------------------------------------------------------------------
# State Initial Guess
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the state function directly when provided as a function.
"""
initial_state(::AbstractOptimalControlProblem, state::Function) = state

"""
$(TYPEDSIGNATURES)

Convert a scalar state value to a constant function for 1D state problems.

Throws `CTBase.IncorrectArgument` if the state dimension is not 1.
"""
function initial_state(ocp::AbstractOptimalControlProblem, state::Real)
    dim = state_dimension(ocp)
    if dim == 1
        return t -> state
    else
        throw(Exceptions.IncorrectArgument(
            "Initial state dimension mismatch",
            got="scalar value",
            expected="vector of length $dim or function returning such vector",
            suggestion="Use a vector: state=[x1, x2, ..., x$dim] or a function: state=t->[...]",
            context="initial_state with scalar input"
        ))
    end
end

"""
$(TYPEDSIGNATURES)

Convert a state vector to a constant function.

Throws `CTBase.IncorrectArgument` if the vector length does not match the state dimension.
"""
function initial_state(ocp::AbstractOptimalControlProblem, state::Vector{<:Real})
    dim = state_dimension(ocp)
    if length(state) != dim
        throw(Exceptions.IncorrectArgument(
            "Initial state dimension mismatch",
            got="vector of length $(length(state))",
            expected="vector of length $dim",
            suggestion="Provide a state vector with $dim elements: state=[x1, x2, ..., x$dim]",
            context="initial_state with vector input"
        ))
    end
    return t -> state
end

"""
$(TYPEDSIGNATURES)

Return a default state initialisation function when no state is provided.

Returns a constant function yielding `0.1` (scalar) or `fill(0.1, dim)` (vector).
"""
function initial_state(ocp::AbstractOptimalControlProblem, ::Nothing)
    dim = state_dimension(ocp)
    if dim == 1
        return t -> 0.1
    else
        return t -> fill(0.1, dim)
    end
end

"""
$(TYPEDSIGNATURES)

Handle time-grid state initialization with (time, data) tuple.

Interpolates the provided data over the time grid to create a callable function.
"""
function initial_state(ocp::AbstractOptimalControlProblem, state::Tuple)
    length(state) == 2 || throw(Exceptions.IncorrectArgument(
        "Time-grid state initialization must be a 2-tuple (time, data)",
        got="$(length(state))-tuple",
        expected="2-tuple (time, data)",
        suggestion="Use state=(time, data) format",
        context="initial_state with time-grid tuple"
    ))
    
    T, data = state
    time = _format_time_grid(T)
    return _build_time_dependent_init(ocp, :state, data, time)
end

"""
$(TYPEDSIGNATURES)

Return the state trajectory from an initial guess.
"""
state(init::AbstractOptimalControlInitialGuess) = init.state

"""
$(TYPEDSIGNATURES)

Return the state trajectory from a solution.
"""
state(sol::AbstractOptimalControlSolution) = sol.state
