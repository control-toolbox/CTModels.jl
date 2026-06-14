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
    print(io, "ConstantInTime(", f.value, ")")
end

function Base.show(io::IO, ::MIME"text/plain", f::ConstantInTime{V}) where {V}
    print(io, "ConstantInTime")
    print(io, "\n  value: ", f.value)
    print(io, "\n  type:  ", V)
end
