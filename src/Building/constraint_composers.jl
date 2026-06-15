# ------------------------------------------------------------------------------
# Callable structs for composite nonlinear constraint assembly (Famille F)
# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

In-place callable struct concatenating `n` nonlinear constraints into a single
composite constraint. `Sig = :path` selects the call method `(val, t, x, u, v)`;
`Sig = :boundary` selects `(val, x0, xf, v)`. Both the signature and the concrete
tuple type `CS` are encoded in type parameters, so each call method is fully
specialised with no runtime branch.

Storing `n`, `dims`, and `funs` as fields (Pattern 7) eliminates the capture-by-reference
fragility present in the previous `make_boundary_cons_nl` closure (where
`constraints_number` and `constraints_dimensions` were outside the `let` block).

Replaces the anonymous closures `path_cons_nl!` and `boundary_cons_nl!` produced
inside [`CTModels.Building.build`](@ref) in `build.jl`.

# Fields
- `n::Int`: Number of individual constraints.
- `dims::Vector{Int}`: Dimension of each individual constraint.
- `funs::CS`: Concrete tuple of the N constraint functions.

# Examples

```julia
using CTModels.Building

f1!(r, t, x, u, v) = (r[1] = x[1] + u[1])
f2!(r, t, x, u, v) = (r[1] = x[2])
fc = CompositeConstraint{:path}(2, [1, 1], (f1!, f2!))
val = zeros(2)
fc(val, 0.0, [1.0, 2.0], [3.0], nothing)
# val == [4.0, 2.0]
```
"""
struct CompositeConstraint{Sig,CS} <: Function
    n::Int            # number of individual constraints
    dims::Vector{Int} # dimension of each individual constraint
    funs::CS          # concrete tuple of the N functions
end

function CompositeConstraint{Sig}(n, dims, funs) where {Sig}
    return CompositeConstraint{Sig,typeof(funs)}(n, copy(dims), funs)
end

"""
$(TYPEDSIGNATURES)

Call method for path constraints: evaluates all individual constraints and concatenates results.

# Arguments
- `f::CompositeConstraint{:path}`: The composite constraint.
- `val`: Pre-allocated output vector (modified in-place).
- `t`: Time.
- `x`: State vector.
- `u`: Control vector.
- `v`: Variable vector.

# Returns
- `Nothing`
"""
function (f::CompositeConstraint{:path})(val, t, x, u, v)
    j = 1
    for i in 1:f.n
        li = f.dims[i]
        f.funs[i](@view(val[j:(j + li - 1)]), t, x, u, v)
        j += li
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Call method for boundary constraints: evaluates all individual constraints and concatenates results.

# Arguments
- `f::CompositeConstraint{:boundary}`: The composite constraint.
- `val`: Pre-allocated output vector (modified in-place).
- `x0`: Initial state.
- `xf`: Final state.
- `v`: Variable vector.

# Returns
- `Nothing`
"""
function (f::CompositeConstraint{:boundary})(val, x0, xf, v)
    j = 1
    for i in 1:f.n
        li = f.dims[i]
        f.funs[i](@view(val[j:(j + li - 1)]), x0, xf, v)
        j += li
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Compact string representation of [`CTModels.Building.CompositeConstraint`](@ref).
"""
function Base.show(io::IO, f::CompositeConstraint{Sig,CS}) where {Sig,CS}
    return print(io, "CompositeConstraint{:", Sig, "}(n=", f.n, ", dims=", f.dims, ")")
end

"""
$(TYPEDSIGNATURES)

Detailed string representation of [`CTModels.Building.CompositeConstraint`](@ref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", f::CompositeConstraint{Sig,CS}
) where {Sig,CS}
    print(io, "CompositeConstraint")
    print(io, "\n  sig:  :", Sig)
    print(io, "\n  n:    ", f.n)
    return print(io, "\n  dims: ", f.dims)
end
