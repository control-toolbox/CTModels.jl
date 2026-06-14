# ------------------------------------------------------------------------------
# Control Initial Guess
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the control function directly when provided as a function.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem (unused).
- `control::Function`: The control function `t -> u(t)`.

# Returns
- `Function`: The control function unchanged.

See also: [`CTModels.Init.initial_control`](@ref) for other input types.
"""
initial_control(::Models.AbstractModel, control::Function) = control

"""
$(TYPEDSIGNATURES)

Convert a scalar control value to a constant function for 1D control problems.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `control::Real`: The scalar control value.

# Returns
- `Function`: A constant function `t -> control`.

# Throws
- `Exceptions.IncorrectArgument`: If the control dimension is not 1 or is 0.
"""
function initial_control(ocp::Models.AbstractModel, control::Real)
    dim = Models.control_dimension(ocp)
    if dim == 0
        throw(
            Exceptions.IncorrectArgument(
                "Initial control dimension mismatch";
                got="scalar value",
                expected="no control (dimension 0)",
                suggestion="Remove the control argument or set control=nothing",
                context="initial_control with scalar input for zero-dimensional control",
            ),
        )
    elseif dim == 1
        return ConstantInTime(control)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Initial control dimension mismatch";
                got="scalar value",
                expected="vector of length $dim or function returning such vector",
                suggestion="Use a vector: control=[u1, u2, ..., u$dim] or a function: control=t->[...]",
                context="initial_control with scalar input",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Convert a control vector to a constant function.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `control::Vector{<:Real}`: The control vector.

# Returns
- `Function`: A constant function `t -> control`.

# Throws
- `Exceptions.IncorrectArgument`: If the vector length does not match the control dimension.
"""
function initial_control(ocp::Models.AbstractModel, control::Vector{<:Real})
    dim = Models.control_dimension(ocp)
    if dim == 0 && !isempty(control)
        throw(
            Exceptions.IncorrectArgument(
                "Initial control dimension mismatch";
                got="vector of length $(length(control))",
                expected="no control (dimension 0)",
                suggestion="Remove the control argument or set control=nothing",
                context="initial_control with vector input for zero-dimensional control",
            ),
        )
    elseif length(control) != dim
        throw(
            Exceptions.IncorrectArgument(
                "Initial control dimension mismatch";
                got="vector of length $(length(control))",
                expected="vector of length $dim",
                suggestion="Provide a control vector with $dim elements: control=[u1, u2, ..., u$dim]",
                context="initial_control with vector input",
            ),
        )
    end
    return ConstantInTime(control)
end

"""
$(TYPEDSIGNATURES)

Return a default control initialisation function when no control is provided.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `::Nothing`: Indicates no control provided.

# Returns
- `Function`: A constant function yielding `Float64[]` (empty) if `dim == 0`,
  `0.1` (scalar) if `dim == 1`, or `fill(0.1, dim)` (vector) otherwise.
"""
function initial_control(ocp::Models.AbstractModel, ::Nothing)
    dim = Models.control_dimension(ocp)
    if dim == 0
        return ConstantInTime(Float64[])
    elseif dim == 1
        return ConstantInTime(0.1)
    else
        return ConstantInTime(fill(0.1, dim))
    end
end

"""
$(TYPEDSIGNATURES)

Handle time-grid control initialization with (time, data) tuple.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `control::Tuple`: A 2-tuple `(time, data)` for time-grid interpolation.

# Returns
- `Function`: An interpolated function `t -> u(t)`.

# Throws
- `Exceptions.IncorrectArgument`: If the tuple is not a 2-tuple.

See also: [`CTModels.Init._build_time_dependent_init`](@ref).
"""
function initial_control(ocp::Models.AbstractModel, control::Tuple)
    length(control) == 2 || throw(
        Exceptions.IncorrectArgument(
            "Time-grid control initialization must be a 2-tuple (time, data)";
            got="$(length(control))-tuple",
            expected="2-tuple (time, data)",
            suggestion="Use control=(time, data) format",
            context="initial_control with time-grid tuple",
        ),
    )

    T, data = control
    time = _format_time_grid(T)
    return _build_time_dependent_init(ocp, :control, data, time)
end

"""
$(TYPEDSIGNATURES)

Return the control trajectory from an initial guess.

# Arguments
- `init::AbstractInitialGuess`: The initial guess.

# Returns
- `Function`: The control function `t -> u(t)`.
"""
Models.control(init::AbstractInitialGuess) = init.control

"""
$(TYPEDSIGNATURES)

Return the control trajectory from a solution.

# Arguments
- `sol::Solutions.AbstractSolution`: The solution.

# Returns
- `Function`: The control function `t -> u(t)`.
"""
Models.control(sol::Solutions.AbstractSolution) = sol.control
