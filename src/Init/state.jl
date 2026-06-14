# ------------------------------------------------------------------------------
# State Initial Guess
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the state function directly when provided as a function.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem (unused).
- `state::Function`: The state function `t -> x(t)`.

# Returns
- `Function`: The state function unchanged.

See also: [`CTModels.Init.initial_state`](@ref) for other input types.
"""
initial_state(::Models.AbstractModel, state::Function) = state

"""
$(TYPEDSIGNATURES)

Convert a scalar state value to a constant function for 1D state problems.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `state::Real`: The scalar state value.

# Returns
- `Function`: A constant function `t -> state`.

# Throws
- `Exceptions.IncorrectArgument`: If the state dimension is not 1.
"""
function initial_state(ocp::Models.AbstractModel, state::Real)
    dim = Models.state_dimension(ocp)
    if dim == 1
        return ConstantInTime(state)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Initial state dimension mismatch";
                got="scalar value",
                expected="vector of length $dim or function returning such vector",
                suggestion="Use a vector: state=[x1, x2, ..., x$dim] or a function: state=t->[...]",
                context="initial_state with scalar input",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Convert a state vector to a constant function.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `state::Vector{<:Real}`: The state vector.

# Returns
- `Function`: A constant function `t -> state`.

# Throws
- `Exceptions.IncorrectArgument`: If the vector length does not match the state dimension.
"""
function initial_state(ocp::Models.AbstractModel, state::Vector{<:Real})
    dim = Models.state_dimension(ocp)
    if length(state) != dim
        throw(
            Exceptions.IncorrectArgument(
                "Initial state dimension mismatch";
                got="vector of length $(length(state))",
                expected="vector of length $dim",
                suggestion="Provide a state vector with $dim elements: state=[x1, x2, ..., x$dim]",
                context="initial_state with vector input",
            ),
        )
    end
    return ConstantInTime(state)
end

"""
$(TYPEDSIGNATURES)

Return a default state initialisation function when no state is provided.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `::Nothing`: Indicates no state provided.

# Returns
- `Function`: A constant function yielding `0.1` (scalar) or `fill(0.1, dim)` (vector).
"""
function initial_state(ocp::Models.AbstractModel, ::Nothing)
    dim = Models.state_dimension(ocp)
    if dim == 1
        return ConstantInTime(0.1)
    else
        return ConstantInTime(fill(0.1, dim))
    end
end

"""
$(TYPEDSIGNATURES)

Handle time-grid state initialization with (time, data) tuple.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `state::Tuple`: A 2-tuple `(time, data)` for time-grid interpolation.

# Returns
- `Function`: An interpolated function `t -> x(t)`.

# Throws
- `Exceptions.IncorrectArgument`: If the tuple is not a 2-tuple.

See also: [`CTModels.Init._build_time_dependent_init`](@ref).
"""
function initial_state(ocp::Models.AbstractModel, state::Tuple)
    length(state) == 2 || throw(
        Exceptions.IncorrectArgument(
            "Time-grid state initialization must be a 2-tuple (time, data)";
            got="$(length(state))-tuple",
            expected="2-tuple (time, data)",
            suggestion="Use state=(time, data) format",
            context="initial_state with time-grid tuple",
        ),
    )

    T, data = state
    time = _format_time_grid(T)
    return _build_time_dependent_init(ocp, :state, data, time)
end

"""
$(TYPEDSIGNATURES)

Return the state trajectory from an initial guess.

# Arguments
- `init::AbstractInitialGuess`: The initial guess.

# Returns
- `Function`: The state function `t -> x(t)`.
"""
Models.state(init::AbstractInitialGuess) = init.state

"""
$(TYPEDSIGNATURES)

Return the state trajectory from a solution.

# Arguments
- `sol::Solutions.AbstractSolution`: The solution.

# Returns
- `Function`: The state function `t -> x(t)`.
"""
Models.state(sol::Solutions.AbstractSolution) = sol.state
