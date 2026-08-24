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
    # Match the caller's buffer element type so the intermediate buffer can hold
    # e.g. ForwardDiff.Dual values when the constraint is differentiated through.
    r_ = zeros(eltype(r), f.n)
    f.cp[2](r_, t, x, u, v)
    r .= r_[f.indices]
    return nothing
end

"""
$(TYPEDSIGNATURES)

Print a compact one-line representation of a [`SubPathConstraint`](@extref).
"""
function Base.show(io::IO, f::SubPathConstraint)
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "SubPathConstraint",
        fmt.reset,
        "(n=",
        fmt.count,
        f.n,
        fmt.reset,
        ", indices=",
        fmt.value,
        f.indices,
        fmt.reset,
        ")",
    )
end

"""
$(TYPEDSIGNATURES)

Print a multi-line representation of a [`SubPathConstraint`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::SubPathConstraint{CP,I}) where {CP,I}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "SubPathConstraint", fmt.reset)
    print(io, "\n  ", fmt.label, "n:       ", fmt.reset, fmt.count, f.n, fmt.reset)
    return print(
        io, "\n  ", fmt.label, "indices: ", fmt.reset, fmt.value, f.indices, fmt.reset
    )
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
    # Match the caller's buffer element type so the intermediate buffer can hold
    # e.g. ForwardDiff.Dual values when the constraint is differentiated through.
    r_ = zeros(eltype(r), f.n)
    f.cp[2](r_, x0, xf, v)
    r .= r_[f.indices]
    return nothing
end

"""
$(TYPEDSIGNATURES)

Print a compact one-line representation of a [`SubBoundaryConstraint`](@extref).
"""
function Base.show(io::IO, f::SubBoundaryConstraint)
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "SubBoundaryConstraint",
        fmt.reset,
        "(n=",
        fmt.count,
        f.n,
        fmt.reset,
        ", indices=",
        fmt.value,
        f.indices,
        fmt.reset,
        ")",
    )
end

"""
$(TYPEDSIGNATURES)

Print a multi-line representation of a [`SubBoundaryConstraint`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::SubBoundaryConstraint{CP,I}) where {CP,I}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "SubBoundaryConstraint", fmt.reset)
    print(io, "\n  ", fmt.label, "n:       ", fmt.reset, fmt.count, f.n, fmt.reset)
    return print(
        io, "\n  ", fmt.label, "indices: ", fmt.reset, fmt.value, f.indices, fmt.reset
    )
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

"""
$(TYPEDSIGNATURES)

Print a compact one-line representation of a [`BoxProjection`](@extref).
"""
function Base.show(io::IO, f::BoxProjection{Slot,CIDX}) where {Slot,CIDX}
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "BoxProjection",
        fmt.reset,
        "{",
        fmt.keyword,
        ":",
        Slot,
        fmt.reset,
        "}(",
        fmt.value,
        f.cidx,
        fmt.reset,
        ")",
    )
end

"""
$(TYPEDSIGNATURES)

Print a multi-line representation of a [`BoxProjection`](@extref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", f::BoxProjection{Slot,CIDX}
) where {Slot,CIDX}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "BoxProjection", fmt.reset)
    print(io, "\n  ", fmt.label, "slot: ", fmt.reset, fmt.keyword, ":", Slot, fmt.reset)
    return print(io, "\n  ", fmt.label, "cidx: ", fmt.reset, fmt.value, f.cidx, fmt.reset)
end
