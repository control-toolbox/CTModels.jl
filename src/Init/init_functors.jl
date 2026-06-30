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

See also: [`CTModels.Init._coerce_base`](@ref)
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

See also: [`CTModels.Init._wrap_1d`](@ref)
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

# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

Callable struct merging a block-level trajectory `base` with sparse component-level
overrides `comps`: `f(t)` evaluates `base(t)`, normalises to a vector, applies each
component override, and returns a scalar (`dim == 1`) or a vector.

`base::F` is a concrete type parameter, replacing the former `base_fun::Function`
abstract capture. `comps::C` stores the `Dict{Int,Function}` override map.

Component index bounds are validated at construction, not at call time, so the call
method stays allocation-free beyond what `base` and the component functions allocate.

Replaces the anonymous closure `t -> begin … end` (57 lines) produced inside
[`CTModels.Init._build_block_with_components`](@ref) in `builders.jl`.

# Fields
- `base::F`: Block-level trajectory function.
- `comps::C`: Component-level override map (`Dict{Int,Function}`).
- `dim::Int`: Total dimension.
- `role::Symbol`: Component role (`:state` or `:control`).

# Examples

```julia
using CTModels.Init

base = t -> [0.0, 0.0]
comps = Dict{Int,Function}(2 => t -> sin(t))
f = MergedTrajectory(base, comps, 2, :state)
f(0.5)   # returns [0.0, sin(0.5)]
```
"""
struct MergedTrajectory{F,C} <: Function
    base::F
    comps::C       # Dict{Int,Function}
    dim::Int
    role::Symbol

    function MergedTrajectory{F,C}(base::F, comps::C, dim::Int, role::Symbol) where {F,C}
        for i in keys(comps)
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
        end
        return new(base, comps, dim, role)
    end
end

function MergedTrajectory(base::F, comps::C, dim::Int, role::Symbol) where {F,C}
    return MergedTrajectory{F,C}(base, comps, dim, role)
end

"""
$(TYPEDSIGNATURES)

Call method for merged trajectory: evaluates base trajectory and applies component overrides.

Component index bounds are validated once at construction. The dimension of the base
trajectory and the scalar/vector shape of each component override are validated here
(at call time), since they depend on the functions' return values.

# Arguments
- `f::CTModels.Init.MergedTrajectory`: The merged trajectory.
- `t`: Time.

# Returns
- `Real` or `Vector`: Scalar or vector depending on dimension.
"""
function (f::MergedTrajectory)(t)
    base_val = f.base(t)
    vec = f.dim == 1 ? _wrap_1d(base_val) : _coerce_base(base_val, f.dim, f.role)
    for (i, fi) in f.comps
        val = fi(t)
        if val isa AbstractVector
            if length(val) != 1
                throw(
                    Exceptions.IncorrectArgument(
                        "Component-level initialization must return scalar or length-1 vector";
                        got="vector of length $(length(val)) for $(f.role) component $i",
                        expected="scalar or length-1 vector",
                        suggestion="Ensure the function for component $i returns a single value",
                        context="component-level $(f.role) initialization",
                    ),
                )
            end
            vec[i] = only(val)
        else
            vec[i] = val
        end
    end
    return f.dim == 1 ? vec[1] : vec
end

"""
$(TYPEDSIGNATURES)

Compact string representation of [`CTModels.Init.MergedTrajectory`](@ref).
"""
function Base.show(io::IO, f::MergedTrajectory{F,C}) where {F,C}
    return print(
        io,
        "MergedTrajectory(dim=",
        f.dim,
        ", role=:",
        f.role,
        ", ncomps=",
        length(f.comps),
        ")",
    )
end

"""
$(TYPEDSIGNATURES)

Detailed string representation of [`CTModels.Init.MergedTrajectory`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::MergedTrajectory{F,C}) where {F,C}
    print(io, "MergedTrajectory")
    print(io, "\n  role:   :", f.role)
    print(io, "\n  dim:    ", f.dim)
    return print(io, "\n  ncomps: ", length(f.comps))
end
