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
