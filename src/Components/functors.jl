# ------------------------------------------------------------------------------
# Callable structs for time-function representations (Famille A — constants)
# ------------------------------------------------------------------------------

"""
    ConstantInTime{V} <: Function

A callable struct representing a constant function of time: `f(t) = value` for all `t`.

Replaces anonymous closures `t -> value` to gain named type, type stability,
value capture (no `deepcopy` needed), and testability.

Satisfies `<: Function` so it can be stored in containers parameterised by `F <: Function`
(e.g. `InitialGuess{X<:Function, U<:Function, V}`).

# Examples

```julia
f = ConstantInTime(1.0)
f(0.5)   # returns 1.0

g = ConstantInTime([1.0, 2.0])
g(3.7)   # returns [1.0, 2.0]
```
"""
struct ConstantInTime{V} <: Function
    value::V
end

(f::ConstantInTime)(::Real) = f.value

function Base.show(io::IO, f::ConstantInTime)
    return print(io, "ConstantInTime(", f.value, ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::ConstantInTime{V}) where {V}
    print(io, "ConstantInTime")
    print(io, "\n  value: ", f.value)
    return print(io, "\n  type:  ", V)
end

# ------------------------------------------------------------------------------
# CoercedTrajectory — Famille C (décorateurs de trajectoire)
# ------------------------------------------------------------------------------

"""
    CoercedTrajectory{F,C} <: Function

A callable struct decorating a time function `inner` with a coercion `coerce`:
`f(t) = coerce(inner(t))`.

Replaces anonymous closures `t -> func(t)[1]` (`coerce = only`, scalar extraction)
and `t -> func(t)` (`coerce = identity`, pass-through). Since `C` is a concrete
singleton type (`typeof(only)` or `typeof(identity)`), the call method is fully
specialised — no type instability.

Satisfies `<: Function` so it can be stored in containers parameterised by
`F <: Function` (e.g. `StateModelSolution{TS<:Function}`).

# Examples

```julia
f = CoercedTrajectory(t -> [2t], only)
f(0.5)   # returns 1.0  (scalar extraction, validates length == 1)

g = CoercedTrajectory(t -> [t, 2t], identity)
g(0.5)   # returns [0.5, 1.0]
```
"""
struct CoercedTrajectory{F,C<:Union{typeof(only),typeof(identity)}} <: Function
    inner::F
    coerce::C
end

(f::CoercedTrajectory)(t) = f.coerce(f.inner(t))

function Base.show(io::IO, f::CoercedTrajectory)
    return print(io, "CoercedTrajectory(", nameof(f.coerce), ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::CoercedTrajectory{F,C}) where {F,C}
    print(io, "CoercedTrajectory")
    print(io, "\n  inner:  ", nameof(typeof(f.inner)))
    return print(io, "\n  coerce: ", nameof(f.coerce))
end
