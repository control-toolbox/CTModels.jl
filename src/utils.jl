"""
$(TYPEDSIGNATURES)

Return the interpolation of `f` at `x`.
"""
function ctinterpolate(x, f) # default for interpolation of the initialization
    return Interpolations.linear_interpolation(x, f; extrapolation_bc=Interpolations.Line())
end

"""
$(TYPEDSIGNATURES)

Transforms `A` to a Vector{<:Vector{<:ctNumber}}.

**Note.** `dim` ∈ {1, 2} is the dimension along which the matrix is transformed.
"""
function matrix2vec(
    A::Matrix{<:ctNumber}, dim::Int=__matrix_dimension_storage()
)::Vector{<:Vector{<:ctNumber}}
    return dim==1 ? [A[i, :] for i in 1:size(A, 1)] : [A[:, i] for i in 1:size(A, 2)]
end
