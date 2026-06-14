# ------------------------------------------------------------------------------
# Callable structs for dual-by-label (Famille D)
# ------------------------------------------------------------------------------

"""
    DualSlice{D,I} <: Function

Callable struct extracting a slice of a time-dependent dual vector:
`f(t) = duals(t)[idx]`.

`I = Int` gives a scalar; `I = Vector{Int}` gives a vector. The scalar/vector
distinction is encoded in the type parameter so the call method is fully
specialised (no runtime branch).

Replaces anonymous closures `t -> duals(t)[indices[1]]` and
`t -> duals(t)[indices]` produced by `dual(sol, model, label)`.
"""
struct DualSlice{D,I} <: Function
    duals::D
    idx::I
end

(f::DualSlice)(t) = f.duals(t)[f.idx]

function Base.show(io::IO, f::DualSlice)
    print(io, "DualSlice(", nameof(typeof(f.duals)), ", ", f.idx, ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::DualSlice{D,I}) where {D,I}
    print(io, "DualSlice")
    print(io, "\n  duals: ", nameof(typeof(f.duals)))
    print(io, "\n  idx:   ", f.idx)
end

# ------------------------------------------------------------------------------

"""
    BoxDualDiff{DL,DU,I} <: Function

Callable struct computing the net dual of a box constraint:
`f(t) = lb(t)[idx] - ub(t)[idx]`.

`I = Int` gives a scalar; `I = Vector{Int}` gives a vector.

Replaces anonymous closures `t -> duals_lb(t)[i] - duals_ub(t)[i]` (and the
vector variant) produced by `dual(sol, model, label)` for state and control
box constraints.
"""
struct BoxDualDiff{DL,DU,I} <: Function
    lb::DL
    ub::DU
    idx::I
end

(f::BoxDualDiff)(t) = f.lb(t)[f.idx] - f.ub(t)[f.idx]

function Base.show(io::IO, f::BoxDualDiff)
    print(io, "BoxDualDiff(", nameof(typeof(f.lb)), ", ", nameof(typeof(f.ub)), ", ", f.idx, ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::BoxDualDiff{DL,DU,I}) where {DL,DU,I}
    print(io, "BoxDualDiff")
    print(io, "\n  lb:  ", nameof(typeof(f.lb)))
    print(io, "\n  ub:  ", nameof(typeof(f.ub)))
    print(io, "\n  idx: ", f.idx)
end
