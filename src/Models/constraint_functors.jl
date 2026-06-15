# ------------------------------------------------------------------------------
# Callable structs for constraint-by-label (Famille E)
# ------------------------------------------------------------------------------

"""
    SubPathConstraint{CP,I} <: Function

In-place callable struct extracting a sub-vector of a nonlinear path constraint:
evaluates the full path constraint vector then copies `r .= r_[indices]`.

`I = Int` or `I = Vector{Int}`. Intended to be wrapped by `Core.to_out_of_place`.

Replaces the anonymous in-place closure produced inside `constraint(model, label)`:
`fc! = (r, t, x, u, v) -> begin r_ = zeros(...); cp[2](r_, t, x, u, v); r .= r_[indices] end`.
"""
struct SubPathConstraint{CP,I} <: Function
    cp::CP
    n::Int      # length(cp[1]) — computed once at construction
    indices::I
end

function (f::SubPathConstraint)(r, t, x, u, v)
    r_ = zeros(f.n)
    f.cp[2](r_, t, x, u, v)
    r .= r_[f.indices]
    return nothing
end

function Base.show(io::IO, f::SubPathConstraint)
    return print(io, "SubPathConstraint(n=", f.n, ", indices=", f.indices, ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::SubPathConstraint{CP,I}) where {CP,I}
    print(io, "SubPathConstraint")
    print(io, "\n  n:       ", f.n)
    return print(io, "\n  indices: ", f.indices)
end

# ------------------------------------------------------------------------------

"""
    SubBoundaryConstraint{CP,I} <: Function

In-place callable struct extracting a sub-vector of a nonlinear boundary constraint:
evaluates the full boundary constraint vector then copies `r .= r_[indices]`.

`I = Int` or `I = Vector{Int}`. Intended to be wrapped by `Core.to_out_of_place`.

Replaces the anonymous in-place closure produced inside `constraint(model, label)`:
`fc! = (r, x0, xf, v) -> begin r_ = zeros(...); cp[2](r_, x0, xf, v); r .= r_[indices] end`.
"""
struct SubBoundaryConstraint{CP,I} <: Function
    cp::CP
    n::Int      # length(cp[1]) — computed once at construction
    indices::I
end

function (f::SubBoundaryConstraint)(r, x0, xf, v)
    r_ = zeros(f.n)
    f.cp[2](r_, x0, xf, v)
    r .= r_[f.indices]
    return nothing
end

function Base.show(io::IO, f::SubBoundaryConstraint)
    return print(io, "SubBoundaryConstraint(n=", f.n, ", indices=", f.indices, ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::SubBoundaryConstraint{CP,I}) where {CP,I}
    print(io, "SubBoundaryConstraint")
    print(io, "\n  n:       ", f.n)
    return print(io, "\n  indices: ", f.indices)
end

# ------------------------------------------------------------------------------

"""
    BoxProjection{Slot,CIDX} <: Function

Callable struct projecting a box constraint onto selected components.

`Slot ∈ (:state, :control, :variable)` selects which argument is projected;
`CIDX = Int` gives a scalar, `CIDX = Vector{Int}` gives a vector.
Both the slot and the scalar/vector distinction are encoded in type parameters
so the call method is fully specialised (no runtime branch).

Replaces three anonymous closures in `constraint(model, label)`:
- `(_, x, _, _) -> x[cidxs]` (state box)
- `(_, _, u, _) -> u[cidxs]` (control box)
- `(_, _, v)    -> v[cidxs]` (variable box, arity 3)
"""
struct BoxProjection{Slot,CIDX} <: Function
    cidx::CIDX
end

BoxProjection{Slot}(cidx) where {Slot} = BoxProjection{Slot,typeof(cidx)}(cidx)

(f::BoxProjection{:state})(_, x, _, _) = x[f.cidx]
(f::BoxProjection{:control})(_, _, u, _) = u[f.cidx]
(f::BoxProjection{:variable})(_, _, v) = v[f.cidx]

function Base.show(io::IO, f::BoxProjection{Slot,CIDX}) where {Slot,CIDX}
    return print(io, "BoxProjection{:", Slot, "}(", f.cidx, ")")
end

function Base.show(
    io::IO, ::MIME"text/plain", f::BoxProjection{Slot,CIDX}
) where {Slot,CIDX}
    print(io, "BoxProjection")
    print(io, "\n  slot: :", Slot)
    return print(io, "\n  cidx: ", f.cidx)
end
