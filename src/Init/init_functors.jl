# ------------------------------------------------------------------------------
# Helpers and callable struct for block+component trajectory merging (Famille C)
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Coerce block-level base value to a vector of the correct dimension.

# Arguments
- `base_val`: The base value from the block-level trajectory.
- `dim::Int`: Expected dimension.
- `role::Symbol`: Component role (`:state` or `:control`).

# Returns
- `Vector`: Coerced vector of correct dimension.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If dimension is incompatible.
"""
function _coerce_base(base_val, dim::Int, role::Symbol)
    if dim == 1
        if base_val isa AbstractVector
            return copy(base_val)
        else
            return [base_val]
        end
    else
        if (base_val isa AbstractVector && length(base_val) != dim) ||
            (!(base_val isa AbstractVector) && dim != 1)
            throw(
                Exceptions.IncorrectArgument(
                    "Block-level $role initialization has incompatible dimension";
                    got="$(base_val isa AbstractVector ? "vector of length $(length(base_val))" : "scalar")",
                    expected="$(dim == 1 ? "scalar or length-1 vector" : "vector of length $dim")",
                    suggestion="Ensure the $role function returns the correct dimension",
                    context="block-level $role initialization",
                ),
            )
        end
        return collect(base_val)
    end
end

"""
$(TYPEDSIGNATURES)

Extract scalar value from component-level initialization result.

# Arguments
- `val`: The component value.
- `role::Symbol`: Component role (`:state` or `:control`).
- `i::Int`: Component index.

# Returns
- `Real`: Scalar value.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If value is not scalar or length-1 vector.
"""
function _component_scalar(val, role::Symbol, i::Int)
    if val isa AbstractVector
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
        return val[1]
    else
        return val
    end
end

"""
$(TYPEDSIGNATURES)

Validate that component index is within bounds.

# Arguments
- `i::Int`: Component index to check.
- `dim::Int`: Total dimension.
- `role::Symbol`: Component role (`:state` or `:control`).

# Returns
- `Nothing`

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If index is out of bounds.
"""
function _check_component_index(i::Int, dim::Int, role::Symbol)
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
    return nothing
end

# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

Callable struct merging a block-level trajectory `base` with sparse component-level
overrides `comps`: `f(t)` evaluates `base(t)`, normalises to a vector, applies each
component override, and returns a scalar (`dim == 1`) or a vector.

Dimension validation and component validation are delegated to helper functions
([`CTModels.Init._coerce_base`](@ref), [`CTModels.Init._component_scalar`](@ref), [`CTModels.Init._check_component_index`](@ref)) — SRP/DRY refactor.

`base::F` is a concrete type parameter, replacing the former `base_fun::Function`
abstract capture. `comps::C` stores the `Dict{Int,Function}` override map.

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
    comps::C       # Dict{Int,Function} — limit noted in plan
    dim::Int
    role::Symbol
end

"""
$(TYPEDSIGNATURES)

Call method for merged trajectory: evaluates base trajectory and applies component overrides.

# Arguments
- `f::CTModels.Init.MergedTrajectory`: The merged trajectory.
- `t`: Time.

# Returns
- `Real` or `Vector`: Scalar or vector depending on dimension.
"""
function (f::MergedTrajectory)(t)
    vec = _coerce_base(f.base(t), f.dim, f.role)
    for (i, fi) in f.comps
        _check_component_index(i, f.dim, f.role)
        vec[i] = _component_scalar(fi(t), f.role, i)
    end
    return f.dim == 1 ? vec[1] : vec
end

"""
$(TYPEDSIGNATURES)

Compact string representation of [`CTModels.Init.MergedTrajectory`](@ref).
"""
function Base.show(io::IO, f::MergedTrajectory{F,C}) where {F,C}
    print(io, "MergedTrajectory(dim=", f.dim, ", role=:", f.role, ", ncomps=", length(f.comps), ")")
end

"""
$(TYPEDSIGNATURES)

Detailed string representation of [`CTModels.Init.MergedTrajectory`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::MergedTrajectory{F,C}) where {F,C}
    print(io, "MergedTrajectory")
    print(io, "\n  role:   :", f.role)
    print(io, "\n  dim:    ", f.dim)
    print(io, "\n  ncomps: ", length(f.comps))
end
