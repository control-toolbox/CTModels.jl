"""
$(TYPEDSIGNATURES)

Set the full dynamics of the optimal control problem `ocp` using the in-place function `f`.

The dynamics have the signature `f!(r, t, x, u, v)` where `r` is the output buffer (filled
in-place), `t` is the time, `x` the state, `u` the control (or `nothing` for control-free
problems), and `v` the optimisation variable.

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `f::Function`: In-place function `f!(r, t, x, u, v)` defining the complete dynamics.

# Returns
- `Nothing`

# Throws
- `Exceptions.PreconditionError`: If state has not been set yet.
- `Exceptions.PreconditionError`: If times have not been set yet.
- `Exceptions.PreconditionError`: If dynamics have already been set.

See also: [`CTModels.Building.objective!`](@extref), [`CTModels.Building.time_dependence!`](@extref).
"""
function dynamics!(ocp::PreModel, f::Function)::Nothing
    Core.@ensure __is_state_set(ocp) Exceptions.PreconditionError(
        "State must be set before defining dynamics",
        reason="state has not been defined yet",
        suggestion="Call state!(ocp, dimension) before dynamics!",
        context="dynamics! function - state validation",
    )
    Core.@ensure __is_times_set(ocp) Exceptions.PreconditionError(
        "Times must be set before defining dynamics",
        reason="time horizon has not been defined yet",
        suggestion="Call times!(ocp, t0, tf) or times!(ocp, N) before dynamics!",
        context="dynamics! function - times validation",
    )
    Core.@ensure !__is_dynamics_set(ocp) Exceptions.PreconditionError(
        "Dynamics already set",
        reason="dynamics have already been defined for this OCP",
        suggestion="Create a new OCP instance or use partial_dynamics! for additional dynamics",
        context="dynamics! function - duplicate definition check",
    )

    # set the dynamics
    ocp.dynamics = f

    return nothing
end

"""
$(TYPEDSIGNATURES)

Add a partial dynamics function for a range of state indices in `ocp`.

The partial right-hand side fills `r[1:length(rg)]` (local buffer view). Ranges must tile
`1:n` without overlap; completeness is verified by [`CTModels.Building.build`](@extref) via
[`CTModels.Building.__is_dynamics_complete`](@extref).

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `rg::AbstractRange{<:Int}`: State index range covered by `f`.
- `f::Function`: In-place function `f!(r, t, x, u, v)` updating `r[1:length(rg)]`.

# Returns
- `Nothing`

# Throws
- `Exceptions.PreconditionError`: If state or times have not been set yet.
- `Exceptions.PreconditionError`: If complete dynamics have already been set.
- `Exceptions.PreconditionError`: If `rg` overlaps with an existing dynamics range.
- `Exceptions.IncorrectArgument`: If any index in `rg` is out of bounds.

See also: [`CTModels.Building.dynamics!`](@extref), [`CTModels.Building.objective!`](@extref).
"""
function dynamics!(ocp::PreModel, rg::AbstractRange{<:Int}, f::Function)::Nothing
    Core.@ensure __is_state_set(ocp) Exceptions.PreconditionError(
        "State must be set before defining partial dynamics",
        reason="state has not been defined yet",
        suggestion="Call state!(ocp, dimension) before partial dynamics!",
        context="partial_dynamics! function - state validation",
    )
    Core.@ensure __is_times_set(ocp) Exceptions.PreconditionError(
        "Times must be set before defining partial dynamics",
        reason="time horizon has not been defined yet",
        suggestion="Call times!(ocp, t0, tf) or times!(ocp, N) before partial dynamics!",
        context="partial_dynamics! function - times validation",
    )
    Core.@ensure !__is_dynamics_complete(ocp) Exceptions.PreconditionError(
        "Complete dynamics already set",
        reason="dynamics have already been completely defined for this OCP",
        suggestion="Use partial_dynamics! before setting complete dynamics, or create a new OCP instance",
        context="partial_dynamics! function - complete dynamics check",
    )

    # Check indices in rg are within valid state index bounds
    for i in rg
        if i < 1 || i > state_dimension(ocp)
            throw(
                Exceptions.IncorrectArgument(
                    "Dynamics index out of bounds";
                    got="index=$i",
                    expected="index in range [1, $(state_dimension(ocp))]",
                    suggestion="Use indices in 1:$(state_dimension(ocp)), e.g., dynamics!(ocp, 1:2, f)",
                    context="dynamics! index validation",
                ),
            )
        end
    end

    # initialize dynamics container if needed
    if isnothing(ocp.dynamics)
        ocp.dynamics = Vector{Tuple{UnitRange{Int},Function}}()
    elseif ocp.dynamics isa Function
        throw(
            Exceptions.PreconditionError(
                "Cannot add partial dynamics to complete dynamics";
                reason="dynamics already defined as a single function",
                suggestion="Use partial_dynamics! calls instead of dynamics! function, or create a new OCP instance",
                context="partial_dynamics! function - dynamics type conflict",
            ),
        )
    end

    # check that indices in rg are not already covered
    for (existing_range, _) in ocp.dynamics
        for i in rg
            if i in existing_range
                throw(
                    Exceptions.PreconditionError(
                        "Dynamics range overlap";
                        reason="index $i in range already has assigned dynamics",
                        suggestion="Use a non-overlapping range or remove existing dynamics first",
                        context="partial_dynamics! function - range overlap check",
                    ),
                )
            end
        end
    end

    # push the new partial dynamics
    push!(ocp.dynamics, (rg, f))

    return nothing
end

"""
$(TYPEDSIGNATURES)

Convenience wrapper: add partial dynamics for a single state index `i`.

Equivalent to `CTModels.Building.dynamics!(ocp, i:i, f)`.

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `i::Integer`: State index covered by `f`.
- `f::Function`: In-place function `f!(r, t, x, u, v)` updating `r[1]`.

# Returns
- `Nothing`

# Throws
- `Exceptions.PreconditionError`: If state, times, or dynamics preconditions are violated.
- `Exceptions.IncorrectArgument`: If `i` is out of bounds.

See also: [`CTModels.Building.dynamics!`](@extref) (range-based version).
"""
function dynamics!(ocp::PreModel, i::Integer, f::Function)::Nothing
    return dynamics!(ocp, i:i, f)
end

# ------------------------------------------------------------------------------
# Callable struct for composite dynamics assembly
# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

In-place callable struct assembling partial dynamics — each declared over a disjoint
state range — into a single `dyn!(val, t, x, u, v)` function.

The concrete tuple type `P` carries every `(range, f!)` pair in its type parameters,
so the call method resolves each part statically: no runtime dispatch, no boxed
`@view`. Evaluating the composite costs exactly the equivalent monolithic dynamics —
the dynamics runs once per solver step, so this is a hot-path invariant
(ct-conventions `PERF1`; issue #496). Storing the parts in a field rather than closing
over them follows the same pattern as [`CTModels.Building.CompositeConstraint`](@extref).

# Fields
- `parts::P`: Concrete `Tuple` of `(range, f!)` pairs in declaration order; each `f!`
  writes `view(val, range)` with signature `f!(r, t, x, u, v)`.

# Examples

```julia
using CTModels: Building

f1!(r, t, x, u, v) = (r[1] = x[2])
f2!(r, t, x, u, v) = (r[1] = u[1])
dyn = Building.CompositeDynamics(((1:1, f1!), (2:2, f2!)))
val = zeros(2)
dyn(val, 0.0, [1.0, 2.0], [3.0], Float64[])
# val == [2.0, 3.0]
```
"""
struct CompositeDynamics{P<:Tuple} <: Function
    parts::P
end

"""
$(TYPEDSIGNATURES)

Apply each partial dynamics to its assigned slice of `val`, in declaration order.

The method is `@generated`: the emitted body is a flat sequence of calls, one per part,
each dispatched on its concrete function type and writing a statically resolved `@view`.
A plain `for` over the heterogeneous `parts` tuple leaves runtime dispatch on the hot
path — each `@view` then boxes (issue #496) — and a recursive `first`/`Base.tail`
traversal silently falls back to dynamic calls beyond the compiler's recursion limit.

# Arguments
- `f::CompositeDynamics`: The composite dynamics.
- `val`: Pre-allocated output vector (modified in-place).
- `t`: Time.
- `x`: State.
- `u`: Control (`nothing` for control-free problems).
- `v`: Optimisation variable.

# Returns
- `Nothing`
"""
@generated function (f::CompositeDynamics{P})(val, t, x, u, v) where {P}
    calls = [
        :(f.parts[$i][2](@view(val[f.parts[$i][1]]), t, x, u, v)) for i in 1:fieldcount(P)
    ]
    return quote
        $(calls...)
        return nothing
    end
end

"""
$(TYPEDSIGNATURES)

Compact string representation of [`CTModels.Building.CompositeDynamics`](@extref).
"""
function Base.show(io::IO, f::CompositeDynamics{P}) where {P}
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "CompositeDynamics",
        fmt.reset,
        "(n=",
        fmt.count,
        length(f.parts),
        fmt.reset,
        ", ranges=",
        fmt.value,
        [p[1] for p in f.parts],
        fmt.reset,
        ")",
    )
end

"""
$(TYPEDSIGNATURES)

Detailed string representation of [`CTModels.Building.CompositeDynamics`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::CompositeDynamics{P}) where {P}
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "CompositeDynamics", fmt.reset)
    print(
        io, "\n  ", fmt.label, "n:      ", fmt.reset, fmt.count, length(f.parts), fmt.reset
    )
    return print(
        io,
        "\n  ",
        fmt.label,
        "ranges: ",
        fmt.reset,
        fmt.value,
        [p[1] for p in f.parts],
        fmt.reset,
    )
end

"""
$(TYPEDSIGNATURES)

Build a single combined in-place dynamics function from ordered partial parts.

Used internally by [`CTModels.Building.build`](@extref) after all partial dynamics calls
have been collected. `tuple(parts...)` preserves each part's concrete `(range, f!)` type
inside the result's type parameter — what makes the calls in
[`CTModels.Building.CompositeDynamics`](@extref) statically dispatched.

# Arguments
- `parts::Vector{<:Tuple{<:AbstractRange{<:Int},<:Function}}`: Ordered vector of
  `(range, f!)` pairs; each `f!(r, t, x, u, v)` fills `r` = `view(val, range)`.

# Returns
- `CompositeDynamics`: Combined `dyn!(val, t, x, u, v)` applying all parts in order,
  with the same allocation cost as a monolithic dynamics (issue #496).
"""
function __build_dynamics_from_parts(
    parts::Vector{<:Tuple{<:AbstractRange{<:Int},<:Function}}
)::CompositeDynamics
    return CompositeDynamics(tuple(parts...))
end
