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
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "DualSlice",
        fmt.reset,
        "(",
        fmt.type,
        nameof(typeof(f.duals)),
        fmt.reset,
        ", ",
        fmt.value,
        f.idx,
        fmt.reset,
        ")",
    )
end

function Base.show(io::IO, ::MIME"text/plain", f::DualSlice{D,I}) where {D,I}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "DualSlice", fmt.reset)
    print(
        io,
        "\n  ",
        fmt.label,
        "duals: ",
        fmt.reset,
        fmt.type,
        nameof(typeof(f.duals)),
        fmt.reset,
    )
    return print(io, "\n  ", fmt.label, "idx:   ", fmt.reset, fmt.value, f.idx, fmt.reset)
end

# ------------------------------------------------------------------------------

"""
    BoxDualDiff{DL,DU,I,C} <: Function

Callable struct computing the dual of a box constraint from the multipliers of its lower
and upper bounds: `f(t) = cl .* lb(t)[idx] .+ cu .* ub(t)[idx]`.

`I = Int` gives a scalar; `I = Vector{Int}` gives a vector, with one coefficient per
component in `cl` and `cu`. The coefficients follow the sign convention of the ecosystem
(ct-conventions `SGN2`, `SGN3`), see [`CTModels.Solutions.dual`](@extref): `(1, 0)` for a
component with a lower bound only (the dual is `zL ≥ 0`), `(0, 1)` for an upper bound only
(`zU ≥ 0`), `(-1, 1)` for two finite bounds or a fixed component (the signed `zU − zL`).
The three-argument constructor gives `(1, -1)`, the net `lb(t)[idx] − ub(t)[idx]`.

Replaces anonymous closures `t -> duals_lb(t)[i] - duals_ub(t)[i]` (and the
vector variant) produced by `dual(sol, model, label)` for state and control
box constraints.
"""
struct BoxDualDiff{DL,DU,I,C} <: Function
    lb::DL
    ub::DU
    idx::I
    cl::C
    cu::C
end

BoxDualDiff(lb, ub, idx::Int) = BoxDualDiff(lb, ub, idx, 1.0, -1.0)
function BoxDualDiff(lb, ub, idx::Vector{Int})
    return BoxDualDiff(lb, ub, idx, ones(length(idx)), -ones(length(idx)))
end

(f::BoxDualDiff)(t) = f.cl .* f.lb(t)[f.idx] .+ f.cu .* f.ub(t)[f.idx]

function Base.show(io::IO, f::BoxDualDiff)
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "BoxDualDiff",
        fmt.reset,
        "(",
        fmt.type,
        nameof(typeof(f.lb)),
        fmt.reset,
        ", ",
        fmt.type,
        nameof(typeof(f.ub)),
        fmt.reset,
        ", ",
        fmt.value,
        f.idx,
        fmt.reset,
        ")",
    )
end

function Base.show(io::IO, ::MIME"text/plain", f::BoxDualDiff{DL,DU,I}) where {DL,DU,I}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "BoxDualDiff", fmt.reset)
    print(
        io, "\n  ", fmt.label, "lb:  ", fmt.reset, fmt.type, nameof(typeof(f.lb)), fmt.reset
    )
    print(
        io, "\n  ", fmt.label, "ub:  ", fmt.reset, fmt.type, nameof(typeof(f.ub)), fmt.reset
    )
    return print(io, "\n  ", fmt.label, "idx: ", fmt.reset, fmt.value, f.idx, fmt.reset)
end
