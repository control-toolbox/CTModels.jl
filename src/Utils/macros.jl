"""
    @ensure condition exception

Throws the provided `exception` if `condition` is false.

# Usage
```julia-repl
julia> @ensure x > 0 CTBase.IncorrectArgument("x must be positive")
```

# Arguments
- `condition`: A Boolean expression to test.
- `exception`: An instance of an exception to throw if `condition` is false.

# Throws
- The provided `exception` if the condition is not satisfied.
"""
macro ensure(cond, exc)
    return esc(:(
        if !($cond)
            throw($exc)
        end
    ))
end
