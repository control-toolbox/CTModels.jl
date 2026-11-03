# ------------------------------------------------------------------------------
# Helpers and callable struct for block+component trajectory merging (Famille C)
# ------------------------------------------------------------------------------

# Dispatched helpers — replace `isa AbstractVector` checks with Julia dispatch so
# the compiler can specialise statically when the return type of `base` is known.

# For dim == 1: normalise any base value to a length-1 vector (no length check).
"""
$(TYPEDSIGNATURES)

Normalise a scalar or vector base value to a `Vector` of length 1 for dim-1 components.

Dispatched overloads replace `isa AbstractVector` runtime checks with static dispatch,
letting the compiler specialise on the return type of the base trajectory.

# Arguments
- `v`: raw output of a base trajectory function for a 1-dimensional component.

# Returns
- `Vector`: a length-1 vector containing or wrapping `v`.

See also: [`CTModels.Init._coerce_base`](@extref)
"""
_wrap_1d(v::AbstractVector) = copy(v)
_wrap_1d(v) = [v]

# For dim > 1: check that `v` has the expected length, then collect.
# The scalar overload always throws because a scalar cannot fill a dim>1 vector.
"""
$(TYPEDSIGNATURES)

Validate and collect the base trajectory output for a component with `dim > 1`.

Throws if `v` is not an `AbstractVector` of the expected length, or if `v` is a scalar.

# Arguments
- `v`: raw output of the base trajectory function.
- `dim::Int`: expected component dimension.
- `role::Symbol`: component role (e.g. `:state`, `:control`) used in the error message.

# Returns
- `Vector`: a freshly collected copy of `v`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if `v` is a scalar or has incorrect length.

See also: [`CTModels.Init._wrap_1d`](@extref)
"""
function _coerce_base(v::AbstractVector, dim::Int, role::Symbol)
    if length(v) != dim
        throw(
            Exceptions.IncorrectArgument(
                "Block-level $role initialization has incompatible dimension";
                got="vector of length $(length(v))",
                expected="vector of length $dim",
                suggestion="Ensure the $role function returns the correct dimension",
                context="block-level $role initialization",
            ),
        )
    end
    return collect(v)
end

function _coerce_base(_, dim::Int, role::Symbol)
    return throw(
        Exceptions.IncorrectArgument(
            "Block-level $role initialization has incompatible dimension";
            got="scalar",
            expected="vector of length $dim",
            suggestion="Ensure the $role function returns the correct dimension",
            context="block-level $role initialization",
        ),
    )
end

# Per-component override application — `val::AbstractVector` must hold exactly one
# value, any other shape is rejected; the scalar overload assigns directly.
"""
$(TYPEDSIGNATURES)

Assign a component override value `val` to `vec[i]` after shape validation.

Dispatched overloads replace `isa AbstractVector` runtime checks with static dispatch:
a length-1 vector unwraps to `only(val)`, anything longer throws, and a scalar
assigns directly.

# Arguments
- `vec`: Output vector being filled (modified in-place).
- `i::Int`: Component index.
- `val`: Raw output of the component override function.
- `role::Symbol`: Component role (e.g. `:state`, `:control`) used in the error message.

# Returns
- `Nothing`

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if `val` is a vector of length other than 1.

See also: [`CTModels.Init._wrap_1d`](@extref), [`CTModels.Init._coerce_base`](@extref)
"""
function _set_component!(vec, i::Int, val::AbstractVector, role::Symbol)
    if length(val) != 1
        throw(
            Exceptions.IncorrectArgument(
                "Component-level initialization must return scalar or length-1 vector";
                got="vector of length $(length(val)) for $role component $i",
                expected="scalar or length-1 vector",
                suggestion="Ensure the function for component $i returns a single value",
                context="component-level $role initialization",
            ),
        )
    end
    vec[i] = only(val)
    return nothing
end

function _set_component!(vec, i::Int, val, role::Symbol)
    vec[i] = val
    return nothing
end

# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

Callable struct merging a block-level trajectory `base` with sparse component-level
overrides `comps`: `f(t)` evaluates `base(t)`, normalises to a vector, applies each
component override, and returns a scalar (`dim == 1`) or a vector.

`base::F` is a concrete type parameter, replacing the former `base_fun::Function`
abstract capture. `comps::P` is a concrete `Tuple` of `(index, f)` pairs in index
order — the concrete tuple type `P` carries every override's function type in its
parameters, so the `@generated` call method dispatches each `f(t)` statically (issue
#498; same pattern as [`CTModels.Building.CompositeDynamics`](@extref)). Iterating a
`Dict{Int,Function}` instead dispatched dynamically and boxed every return value.

Component index bounds are validated at construction, not at call time, so the call
method stays allocation-free beyond what `base` and the component functions allocate.

Replaces the anonymous closure `t -> begin … end` (57 lines) produced inside
[`CTModels.Init._build_block_with_components`](@extref) in `builders.jl`.

# Fields
- `base::F`: Block-level trajectory function.
- `comps::P`: Concrete `Tuple` of `(index::Int, f::Function)` override pairs,
  sorted by index.
- `dim::Int`: Total dimension.
- `role::Symbol`: Component role (`:state` or `:control`).

# Examples

```julia
using CTModels: Init

base = t -> [0.0, 0.0]
comps = Dict{Int,Function}(2 => t -> sin(t))
f = MergedTrajectory(base, comps, 2, :state)
f(0.5)   # returns [0.0, sin(0.5)]
```
"""
struct MergedTrajectory{F,P<:Tuple} <: Function
    base::F
    comps::P       # concrete tuple of (index::Int, f) pairs
    dim::Int
    role::Symbol

    function MergedTrajectory{F,P}(
        base::F, comps::P, dim::Int, role::Symbol
    ) where {F,P<:Tuple}
        prev = 0
        for (i, _) in comps
            if !(1 <= i <= dim)
                throw(
                    Exceptions.IncorrectArgument(
                        "Component index out of bounds";
                        got="index $i for $role",
                        expected="index between 1 and $dim",
                        suggestion="Use a valid component index in range 1:$dim",
                        context="component-level $role initialization",
                    ),
                )
            end
            if i <= prev
                throw(
                    Exceptions.IncorrectArgument(
                        "Component overrides must be sorted by strictly increasing index";
                        got="index $i after index $prev for $role",
                        expected="strictly increasing component indices",
                        suggestion="Sort the overrides by index and give each component at most one override",
                        context="component-level $role initialization",
                    ),
                )
            end
            prev = i
        end
        return new(base, comps, dim, role)
    end
end

function MergedTrajectory(base::F, comps::P, dim::Int, role::Symbol) where {F,P<:Tuple}
    return MergedTrajectory{F,P}(base, comps, dim, role)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTModels.Init.MergedTrajectory`](@extref) from a `Dict{Int,<:Function}`
override map: the pairs are sorted by component index and linearised into a concrete
`Tuple` — `tuple(pairs...)` preserves each override's concrete function type inside
`P`, what makes the calls in the generated call method statically dispatched.

See also: [`CTModels.Init.MergedTrajectory`](@extref)
"""
function MergedTrajectory(
    base::F, comps::AbstractDict{Int,<:Function}, dim::Int, role::Symbol
) where {F}
    pairs = tuple(((i, fi) for (i, fi) in sort!(collect(comps); by=first))...)
    return MergedTrajectory{F,typeof(pairs)}(base, pairs, dim, role)
end

"""
$(TYPEDSIGNATURES)

Call method for merged trajectory: evaluates base trajectory and applies component overrides.

Component index bounds are validated once at construction. The dimension of the base
trajectory and the scalar/vector shape of each component override are validated here
(at call time), since they depend on the functions' return values.

The method is `@generated`: the emitted body is a flat sequence of calls, one per
override, each dispatched on its concrete function type — so each override's return
type is inferred per element and the [`CTModels.Init._set_component!`](@extref) shape
check resolves statically. A plain `for` over the heterogeneous `comps` tuple leaves
runtime dispatch on the call path (issue #498).

# Arguments
- `f::CTModels.Init.MergedTrajectory`: The merged trajectory.
- `t`: Time.

# Returns
- `Real` or `Vector`: Scalar or vector depending on dimension.
"""
@generated function (f::MergedTrajectory{F,P})(t) where {F,P}
    calls = [
        :(_set_component!(vec, f.comps[$k][1], f.comps[$k][2](t), f.role)) for
        k in 1:fieldcount(P)
    ]
    return quote
        base_val = f.base(t)
        vec = f.dim == 1 ? _wrap_1d(base_val) : _coerce_base(base_val, f.dim, f.role)
        $(calls...)
        return f.dim == 1 ? vec[1] : vec
    end
end

"""
$(TYPEDSIGNATURES)

Compact string representation of [`CTModels.Init.MergedTrajectory`](@extref).
"""
function Base.show(io::IO, f::MergedTrajectory{F,P}) where {F,P}
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "MergedTrajectory",
        fmt.reset,
        "(dim=",
        fmt.count,
        f.dim,
        fmt.reset,
        ", role=",
        fmt.keyword,
        ":",
        f.role,
        fmt.reset,
        ", ncomps=",
        fmt.count,
        length(f.comps),
        fmt.reset,
        ")",
    )
end

"""
$(TYPEDSIGNATURES)

Detailed string representation of [`CTModels.Init.MergedTrajectory`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::MergedTrajectory{F,P}) where {F,P}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "MergedTrajectory", fmt.reset)
    print(io, "\n  ", fmt.label, "role:   ", fmt.reset, fmt.keyword, ":", f.role, fmt.reset)
    print(io, "\n  ", fmt.label, "dim:    ", fmt.reset, fmt.count, f.dim, fmt.reset)
    return print(
        io, "\n  ", fmt.label, "ncomps: ", fmt.reset, fmt.count, length(f.comps), fmt.reset
    )
end
