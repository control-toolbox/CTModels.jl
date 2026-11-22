# ------------------------------------------------------------------------------
# Callable structs returned by constraint(model, label)
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Element type of the buffer an out-of-place constraint functor allocates: `Float64`,
widened with the element types of the numeric arguments (scalars and arrays) so that
the buffer can hold e.g. `ForwardDiff.Dual` values under differentiation. Non-numeric
arguments (e.g. `nothing`) are neutral.
"""
_buffer_eltype(args...) = promote_type(Float64, _arg_eltype(args...))

"""
$(TYPEDSIGNATURES)

Promoted element type of the numeric arguments (scalars and arrays); `Union{}`, neutral
under `promote_type`, when there is none. Used by
[`CTModels.Models._buffer_eltype`](@extref).
"""
_arg_eltype() = Union{}
_arg_eltype(x::Number, rest...) = promote_type(typeof(x), _arg_eltype(rest...))
_arg_eltype(x::AbstractArray, rest...) = promote_type(eltype(x), _arg_eltype(rest...))
_arg_eltype(_, rest...) = _arg_eltype(rest...)

# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

Out-of-place callable struct evaluating the rows `indices` of the stacked nonlinear path
constraint `f!(r, t, x, u, v)` of a model: `(t, x, u, v) -> r[indices]`, where `r` is the
full stacked vector of length `n`.

`I = Int` returns a scalar, `I = Vector{Int}` a vector: the shape is encoded in the type,
so the call has no runtime branch.

Returned by [`CTModels.Models.constraint`](@extref) for a `:path` label.

# Fields
- `f!::F`: The stacked in-place path constraint of the model.
- `n::Int`: Length of the stacked constraint vector.
- `indices::I`: Rows of the label in the stacked vector.

# Example
```julia-repl
julia> using CTModels: Models

julia> f!(r, t, x, u, v) = (r[1] = t; r[2] = x[1] + u; nothing);

julia> c = Models.SubPathConstraint(f!, 2, 2)
SubPathConstraint
  n:       2
  indices: 2

julia> c(0.0, [1.0, 2.0], 3.0, nothing)
4.0
```

See also: [`CTModels.Models.SubBoundaryConstraint`](@extref), [`CTModels.Building.CompositeConstraint`](@extref).
"""
struct SubPathConstraint{F,I} <: Function
    f!::F
    n::Int
    indices::I
end

"""
$(TYPEDSIGNATURES)

Evaluate the stacked path constraint at `(t, x, u, v)` and return its rows `f.indices`:
a scalar when `I = Int`, a vector otherwise.

# Arguments
- `f::SubPathConstraint`: The functor.
- `t`: Time.
- `x`: State.
- `u`: Control.
- `v`: Variable.

# Returns
- The rows of the constraint, with the element type of the arguments, at least `Float64`.
"""
function (f::SubPathConstraint)(t, x, u, v)
    r = zeros(_buffer_eltype(t, x, u, v), f.n)
    f.f!(r, t, x, u, v)
    return r[f.indices]
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
function Base.show(io::IO, ::MIME"text/plain", f::SubPathConstraint{F,I}) where {F,I}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "SubPathConstraint", fmt.reset)
    print(io, "\n  ", fmt.label, "n:       ", fmt.reset, fmt.count, f.n, fmt.reset)
    return print(
        io, "\n  ", fmt.label, "indices: ", fmt.reset, fmt.value, f.indices, fmt.reset
    )
end

# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

Out-of-place callable struct evaluating the rows `indices` of the stacked nonlinear
boundary constraint `f!(r, x0, xf, v)` of a model: `(x0, xf, v) -> r[indices]`, where `r`
is the full stacked vector of length `n`.

`I = Int` returns a scalar, `I = Vector{Int}` a vector: the shape is encoded in the type,
so the call has no runtime branch.

Returned by [`CTModels.Models.constraint`](@extref) for a `:boundary` label.

# Fields
- `f!::F`: The stacked in-place boundary constraint of the model.
- `n::Int`: Length of the stacked constraint vector.
- `indices::I`: Rows of the label in the stacked vector.

# Example
```julia-repl
julia> using CTModels: Models

julia> f!(r, x0, xf, v) = (r[1] = x0[1]; r[2] = xf[1]; nothing);

julia> c = Models.SubBoundaryConstraint(f!, 2, [1, 2])
SubBoundaryConstraint
  n:       2
  indices: [1, 2]

julia> c([0.0, 1.0], [2.0, 3.0], nothing)
2-element Vector{Float64}:
 0.0
 2.0
```

See also: [`CTModels.Models.SubPathConstraint`](@extref), [`CTModels.Building.CompositeConstraint`](@extref).
"""
struct SubBoundaryConstraint{F,I} <: Function
    f!::F
    n::Int
    indices::I
end

"""
$(TYPEDSIGNATURES)

Evaluate the stacked boundary constraint at `(x0, xf, v)` and return its rows
`f.indices`: a scalar when `I = Int`, a vector otherwise.

# Arguments
- `f::SubBoundaryConstraint`: The functor.
- `x0`: Initial state.
- `xf`: Final state.
- `v`: Variable.

# Returns
- The rows of the constraint, with the element type of the arguments, at least `Float64`.
"""
function (f::SubBoundaryConstraint)(x0, xf, v)
    r = zeros(_buffer_eltype(x0, xf, v), f.n)
    f.f!(r, x0, xf, v)
    return r[f.indices]
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
function Base.show(io::IO, ::MIME"text/plain", f::SubBoundaryConstraint{F,I}) where {F,I}
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
