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

"""
$(TYPEDEF)

The duals given by label, as one function of time on the stacked layout of the model:
`f(t)` is a vector with one entry per row (stacked path constraint) or per component (box
multipliers), the rows of a given label filled by its function, and `fill` in the other
rows: `NaN` for the path duals (the labels not given are unknown), `0` for the box
multipliers (a component bounded by no label).

Each part is a pair `(rows, g)`: `rows` the rows of the label (see
[`CTModels.Models.constraint_rows`](@extref)), `g` its dual `t -> value` (a scalar for a
one-row label, a vector otherwise).

# Fields
- `dim::Int`: The number of rows.
- `parts::P`: The parts, a tuple of `(rows, g)` pairs.
- `fill::Float64`: The value of the rows covered by no part.
"""
struct StackedDuals{P<:Tuple} <: Function
    dim::Int
    parts::P
    fill::Float64
end

"""
$(TYPEDSIGNATURES)

The stacked path duals: the rows of the labels not given are `NaN` (unknown).
"""
StackedDuals(dim::Int, parts::Tuple) = StackedDuals(dim, parts, NaN)

"""
$(TYPEDSIGNATURES)

Evaluate the stacked duals at time `t`.

The method is `@generated`: the emitted body is a flat sequence of calls, one per part,
each dispatched on the concrete type of its function (as for
[`CTModels.Building.CompositeDynamics`](@extref)). A plain `for` over the heterogeneous
`parts` tuple would dispatch at runtime on the hot path.
"""
@generated function (f::StackedDuals{P})(t) where {P}
    calls = [:(out[f.parts[$i][1]] .= f.parts[$i][2](t)) for i in 1:fieldcount(P)]
    return quote
        out = fill(f.fill, f.dim)
        $(calls...)
        return out
    end
end

"""
$(TYPEDEF)

One side of the box multipliers of a box label given by its signed dual: `f(t)` is the
lower-bound multiplier `zL` (`S = :lower`) or the upper-bound multiplier `zU` (`S =
:upper`) of each component of the label, split from the signed dual `dual(t)` with the
coefficients `(cl, cu)` of the components (see [`CTModels.Solutions._split_lower`](@extref),
[`CTModels.Solutions._split_upper`](@extref)).

# Fields
- `dual::F`: The signed dual of the label, `t -> value` (a scalar for one component).
- `cl::Vector{Float64}`, `cu::Vector{Float64}`: The coefficients of the components.
"""
struct BoxDualSplit{S,F} <: Function
    dual::F
    cl::Vector{Float64}
    cu::Vector{Float64}
end

BoxDualSplit{S}(dual::F, cl, cu) where {S,F} = BoxDualSplit{S,F}(dual, cl, cu)

(f::BoxDualSplit{:lower})(t) = _split_lower.(f.dual(t), f.cl, f.cu)
(f::BoxDualSplit{:upper})(t) = _split_upper.(f.dual(t), f.cl, f.cu)
