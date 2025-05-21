"""
$(TYPEDSIGNATURES)


Return a linear interpolation function for the data `f` defined at points `x`.

This function creates a one-dimensional linear interpolant using the 
[`Interpolations.jl`](https://github.com/JuliaMath/Interpolations.jl) package, with linear extrapolation beyond the bounds of `x`.

# Arguments
- `x`: A vector of points at which the values `f` are defined.
- `f`: A vector of values to interpolate.

# Returns
A callable interpolation object that can be evaluated at new points.

# Example
```julia-repl
julia> x = 0:0.5:2
julia> f = [0.0, 1.0, 0.0, -1.0, 0.0]
julia> interp = ctinterpolate(x, f)
julia> interp(1.2)
```
"""
function ctinterpolate(x, f) # default for interpolation of the initialization
    return Interpolations.linear_interpolation(x, f; extrapolation_bc=Interpolations.Line())
end

"""
$(TYPEDSIGNATURES)

Transform a matrix into a vector of vectors along the specified dimension.

Each row or column of the matrix `A` is extracted and stored as an individual vector, depending on `dim`.

# Arguments
- `A`: A matrix of elements of type `<:ctNumber`.
- `dim`: The dimension along which to split the matrix (`1` for rows, `2` for columns). Defaults to `1`.

# Returns
A `Vector` of `Vector`s extracted from the rows or columns of `A`.

# Note
This is useful when data needs to be represented as a sequence of state or control vectors in optimal control problems.

# Example
```julia-repl
julia> A = [1 2 3; 4 5 6]
julia> matrix2vec(A, 1)  # splits into rows: [[1, 2, 3], [4, 5, 6]]
julia> matrix2vec(A, 2)  # splits into columns: [[1, 4], [2, 5], [3, 6]]
```
"""
function matrix2vec(
    A::Matrix{<:ctNumber}, dim::Int=__matrix_dimension_storage()
)::Vector{<:Vector{<:ctNumber}}
    return dim==1 ? [A[i, :] for i in 1:size(A, 1)] : [A[:, i] for i in 1:size(A, 2)]
end

"""
$(TYPEDSIGNATURES)

Convert an in-place function `f!` to an out-of-place function `f`.

The resulting function `f` returns a vector of type `T` and length `n` by first allocating memory and then calling `f!` to fill it.

# Arguments
- `f!`: An in-place function of the form `f!(result, args...)`.
- `n`: The length of the output vector.
- `T`: The element type of the output vector (default is `Float64`).

# Returns
An out-of-place function `f(args...; kwargs...)` that returns the result as a vector or scalar, depending on `n`.

# Example
```julia-repl
julia> f!(r, x) = (r[1] = sin(x); r[2] = cos(x))
julia> f = to_out_of_place(f!, 2)
julia> f(π/4)  # returns approximately [0.707, 0.707]
```
"""
function to_out_of_place(f!, n; T=Float64)
    function f(args...; kwargs...)
        r = zeros(T, n)
        f!(r, args...; kwargs...)
        return n == 1 ? r[1] : r
        #return r # everything is now a vector
    end
    return isnothing(f!) ? nothing : f
end
