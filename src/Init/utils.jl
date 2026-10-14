# ------------------------------------------------------------------------------
# Initial Guess Utilities
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Normalise time grid data to a vector format.

# Arguments
- `time_data`: The time grid data (vector, array, or `nothing`).

# Returns
- `Union{Nothing, AbstractVector}`: The normalised time grid as a vector, or `nothing`.

# Throws
- `Exceptions.IncorrectArgument`: If the time grid type is invalid.
"""
function _format_time_grid(time_data)
    if time_data === nothing
        return nothing
    elseif time_data isa AbstractVector
        return time_data
    elseif time_data isa AbstractArray
        return vec(time_data)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid time grid type for initial guess";
                got="$(typeof(time_data))",
                expected="Vector or Array",
                suggestion="Provide a vector or array for the time grid",
                context="time grid formatting",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Convert matrix data to vector-of-vectors format for time-grid interpolation.

# Arguments
- `data`: The data to format (matrix or other format).

# Returns
- `Union{AbstractVector, Any}`: The formatted data as vector-of-vectors, or the original data.
"""
function _format_init_data_for_grid(data)
    if data isa AbstractMatrix
        return Core.matrix2vec(data, 1)
    else
        return data
    end
end

"""
$(TYPEDSIGNATURES)

Return a trajectory that yields a scalar when the component is one-dimensional.

A validated one-dimensional trajectory returns either a scalar or a length-1 vector. The
second case is wrapped so that it returns the scalar, following the rule that a
one-dimensional state or control is a `Number`. Trajectories of any other dimension, and
trajectories that already return a scalar, are returned unchanged.

# Arguments
- `f::Function`: The validated trajectory `t -> x(t)`.
- `dim::Int`: The dimension of the component.

# Returns
- `Function`: The trajectory, or a scalar-returning wrapper around it.

See also: [`CTModels.Components.CoercedTrajectory`](@extref).
"""
function _scalar_trajectory(f::Function, dim::Int)
    dim == 1 || return f
    f isa Components.ConstantInTime{<:Real} && return f
    f isa Components.CoercedTrajectory{<:Any,typeof(only)} && return f
    f isa Components.ConstantInTime && return Components.ConstantInTime(only(f.value))
    return Components.CoercedTrajectory(f, only)
end

"""
$(TYPEDSIGNATURES)

Return the variable as a scalar when it is one-dimensional.

# Arguments
- `v`: The validated variable value (scalar or vector).
- `dim::Int`: The variable dimension.

# Returns
- The scalar `only(v)` when `dim == 1` and `v` is a vector, `v` otherwise.
"""
_scalar_value(v, dim::Int) = (dim == 1 && v isa AbstractVector) ? only(v) : v

"""
$(TYPEDSIGNATURES)

Normalise the one-dimensional components of a validated initial guess to scalars.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `init::AbstractInitialGuess`: The validated initial guess.

# Returns
- `AbstractInitialGuess`: `init` itself when nothing needs converting, otherwise a new
  `InitialGuess` whose one-dimensional components are scalars.
"""
_normalize_scalar_components(::Models.AbstractModel, init::AbstractInitialGuess) = init

function _normalize_scalar_components(ocp::Models.AbstractModel, init::InitialGuess)
    x = _scalar_trajectory(init.state, Models.state_dimension(ocp))
    u = _scalar_trajectory(init.control, Models.control_dimension(ocp))
    v = _scalar_value(init.variable, Models.variable_dimension(ocp))
    unchanged = x === init.state && u === init.control && v === init.variable
    return unchanged ? init : InitialGuess(x, u, v)
end
