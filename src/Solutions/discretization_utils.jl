# Utility functions for discretizing functions on time grids
# Used for serialization (JSON, JLD2) and solution reconstruction

"""
$(TYPEDSIGNATURES)

Discretize a function on a time grid.

Evaluates `f` at each point in `T` and collects the results into a matrix.
If `dim` is -1, the output dimension is auto-detected from the first evaluation of `f`.

# Arguments
- `f::Function`: Function to discretize (can return a scalar or a vector).
- `T::AbstractVector`: Time grid.
- `dim::Int`: Expected dimension of the result. If -1, auto-detected from first evaluation.

# Returns
- `Matrix{Float64}`: n×dim matrix where n = length(T).

# Examples
```julia
# Scalar function
f_scalar = t -> 2.0 * t
result = _discretize_function(f_scalar, [0.0, 0.5, 1.0], 1)
# result = [0.0; 1.0; 2.0]

# Vector function
f_vec = t -> [t, 2*t]
result = _discretize_function(f_vec, [0.0, 0.5, 1.0], 2)
# result = [0.0 0.0; 0.5 1.0; 1.0 2.0]

# Auto-detect dimension
result = _discretize_function(f_vec, [0.0, 0.5, 1.0])
# result = [0.0 0.0; 0.5 1.0; 1.0 2.0]
```

See also: [`CTModels.Solutions._discretize_dual`](@extref).
"""
function _discretize_function(f::Function, T::AbstractVector, dim::Int=-1)::Matrix{Float64}
    n = length(T)

    # Auto-detect dimension if necessary
    if dim == -1
        first_val = f(T[1])
        dim = first_val isa Number ? 1 : length(first_val)
    end

    result = Matrix{Float64}(undef, n, dim)
    for (i, t) in enumerate(T)
        val = f(t)
        if dim == 1
            result[i, 1] = val isa Number ? val : val[1]
        else
            result[i, :] = val
        end
    end
    return result
end

"""
$(TYPEDSIGNATURES)

Discretize a function on a `TimeGridModel` by extracting the underlying time grid.

See also: [`CTModels.Solutions._discretize_function`](@extref).
"""
function _discretize_function(f::Function, T::TimeGridModel, dim::Int=-1)::Matrix{Float64}
    return _discretize_function(f, T.value, dim)
end

"""
$(TYPEDSIGNATURES)

Discretize a dual function, returning `nothing` if the input is `nothing`.

# Arguments
- `dual_func::Union{Function,Nothing}`: Dual function or `nothing`.
- `T`: Time grid.
- `dim::Int`: Dimension (auto-detected if -1).

# Returns
- `Matrix{Float64}` if `dual_func` is a function.
- `nothing` if `dual_func` is `nothing`.

See also: [`CTModels.Solutions._discretize_function`](@extref).
"""
function _discretize_dual(dual_func::Union{Function,Nothing}, T, dim::Int=-1)
    return isnothing(dual_func) ? nothing : _discretize_function(dual_func, T, dim)
end

"""
$(TYPEDSIGNATURES)

Normalize a time-independent solution field (currently only `variable`) to a
`Vector{Float64}` for serialization.

`Components.variable(sol)` follows the "1-D is a scalar" convention: it returns a bare
`Number` when `variable_dimension(ocp) == 1`, and a `Vector{Float64}` otherwise. Unlike
`state`/`control`/`costate`, this field is not run through `_discretize_function` (it is
time-independent), so without this normalization a scalar would leak into the serialized
data untouched.

See also: [`CTModels.Solutions._discretize_all_components`](@extref).
"""
_as_vector(v::ctNumber)::Vector{Float64} = [Float64(v)]
_as_vector(v::ctVector)::Vector{Float64} = Vector{Float64}(v)
