"""
$(TYPEDSIGNATURES)

Return the interpolation of `f` at `x`.
"""
function ctinterpolate(x, f) # default for interpolation of the initialization
    return Interpolations.linear_interpolation(x, f; extrapolation_bc=Interpolations.Line())
end

"""
$(TYPEDSIGNATURES)

Transforms `x` to a Vector{<:Vector{<:ctNumber}}.

**Note.** `dim` ∈ {1, 2} is the dimension along which the matrix is transformed.
"""
function matrix2vec(
    x::Matrix{<:ctNumber}, dim::Int=__matrix_dimension_stock()
)::Vector{<:Vector{<:ctNumber}}
    m, n = size(x)
    y = nothing
    if dim == 1
        y = [x[1, :]]
        for i in 2:m
            y = vcat(y, [x[i, :]])
        end
    else
        y = [x[:, 1]]
        for j in 2:n
            y = vcat(y, [x[:, j]])
        end
    end
    return y
end