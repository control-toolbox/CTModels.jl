# ============================================================================ #
# Strategies Module - StrategyOptions
# ============================================================================ #
# This file defines the StrategyOptions type for configured strategy options.
# ============================================================================ #

module Strategies

"""
    StrategyOptions

Wrapper for strategy option values and their sources.

# Fields
- `values::NamedTuple` - Current option values
- `sources::NamedTuple` - Source of each value (`:user` or `:default`)

# Example
```julia
options = StrategyOptions(
    (max_iter=200, tol=1e-6),
    (max_iter=:user, tol=:default)
)

options[:max_iter]  # => 200
options.values      # => (max_iter=200, tol=1e-6)
options.sources     # => (max_iter=:user, tol=:default)
```

# Indexability
StrategyOptions can be indexed like a NamedTuple:
```julia
opts[:max_iter]  # Get value
keys(opts)       # Get all keys
values(opts)     # Get all values
pairs(opts)      # Get key-value pairs
```
"""
struct StrategyOptions
    values::NamedTuple
    sources::NamedTuple
    
    function StrategyOptions(values::NamedTuple, sources::NamedTuple)
        # Validate that keys match
        if keys(values) != keys(sources)
            error("Keys mismatch between values and sources")
        end
        
        # Validate that sources are :user or :default
        for source in values(sources)
            if source ∉ (:user, :default)
                error("Source must be :user or :default, got :$source")
            end
        end
        
        new(values, sources)
    end
end

# Indexability - returns value (not source)
Base.getindex(opts::StrategyOptions, key::Symbol) = opts.values[key]
Base.keys(opts::StrategyOptions) = keys(opts.values)
Base.values(opts::StrategyOptions) = values(opts.values)
Base.pairs(opts::StrategyOptions) = pairs(opts.values)
Base.iterate(opts::StrategyOptions, state...) = iterate(opts.values, state...)

# Display
function Base.show(io::IO, ::MIME"text/plain", opts::StrategyOptions)
    println(io, "StrategyOptions:")
    for (key, value) in pairs(opts.values)
        source = opts.sources[key]
        source_str = source == :user ? "user" : "default"
        println(io, "  $key = $value  [$source_str]")
    end
end

end # module Strategies
