# ------------------------------------------------------------------------------
# Variable Initial Guess
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return a scalar variable value for 1D variable problems.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `variable::Real`: The scalar variable value.

# Returns
- `Real`: The variable value.

# Throws
- `Exceptions.IncorrectArgument`: If the variable dimension is not 1 or is 0.
"""
function initial_variable(ocp::Models.AbstractModel, variable::Real)
    dim = Models.variable_dimension(ocp)
    if dim == 0
        throw(
            Exceptions.IncorrectArgument(
                "Initial variable dimension mismatch";
                got="scalar value",
                expected="no variable (dimension 0)",
                suggestion="Remove the variable argument or set variable=nothing",
                context="initial_variable with scalar input for zero-dimensional variable",
            ),
        )
    elseif dim == 1
        return variable
    else
        throw(
            Exceptions.IncorrectArgument(
                "Initial variable dimension mismatch";
                got="scalar value",
                expected="vector of length $dim",
                suggestion="Use a vector: variable=[v1, v2, ..., v$dim]",
                context="initial_variable with scalar input",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Return a variable vector.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `variable::Vector{<:Real}`: The variable vector.

# Returns
- `Vector{<:Real}`: The variable vector unchanged.

# Throws
- `Exceptions.IncorrectArgument`: If the vector length does not match the variable dimension.
"""
function initial_variable(ocp::Models.AbstractModel, variable::Vector{<:Real})
    dim = Models.variable_dimension(ocp)
    base_val = variable
    if length(base_val) != dim
        throw(
            Exceptions.IncorrectArgument(
                "Initial variable dimension mismatch";
                got="vector of length $(length(base_val))",
                expected="vector of length $dim",
                suggestion="Provide a variable vector with $dim elements matching the variable dimension",
                context="initial_variable component-level initialization",
            ),
        )
    end
    return variable
end

"""
$(TYPEDSIGNATURES)

Return a default variable initialisation when no variable is provided.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `::Nothing`: Indicates no variable provided.

# Returns
- `Union{Vector{<:Real}, Real}`: An empty vector if `dim == 0`, `0.1` if `dim == 1`, or `fill(0.1, dim)` otherwise.
"""
function initial_variable(ocp::Models.AbstractModel, ::Nothing)
    dim = Models.variable_dimension(ocp)
    if dim == 0
        return Float64[]
    elseif dim == 1
        return 0.1
    else
        return fill(0.1, dim)
    end
end

"""
$(TYPEDSIGNATURES)

Handle time-grid variable initialization with (time, data) tuple.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `variable::Tuple`: A 2-tuple `(time, data)` for time-grid interpolation.

# Returns
- `Function`: An interpolated function `t -> v(t)`.

# Throws
- `Exceptions.IncorrectArgument`: If the tuple is not a 2-tuple.

See also: [`CTModels.Init._build_time_dependent_init`](@ref).
"""
function initial_variable(ocp::Models.AbstractModel, variable::Tuple)
    length(variable) == 2 || throw(
        Exceptions.IncorrectArgument(
            "Time-grid variable initialization must be a 2-tuple (time, data)";
            got="$(length(variable))-tuple",
            expected="2-tuple (time, data)",
            suggestion="Use variable=(time, data) format",
            context="initial_variable with time-grid tuple",
        ),
    )

    T, data = variable
    time = _format_time_grid(T)
    return _build_time_dependent_init(ocp, :variable, data, time)
end

"""
$(TYPEDSIGNATURES)

Return the variable value from an initial guess.

# Arguments
- `init::AbstractInitialGuess`: The initial guess.

# Returns
- `Union{Real, Vector{<:Real}}`: The variable value (scalar or vector).
"""
Models.variable(init::AbstractInitialGuess) = init.variable
