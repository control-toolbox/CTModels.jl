# ============================================================================ #
# Strategies Module - StrategyMetadata
# ============================================================================ #
# This file defines the StrategyMetadata type wrapping option specifications.
# ============================================================================ #

module Strategies

using ..OptionSpecification

"""
    StrategyMetadata

Metadata about a strategy type, wrapping option specifications.

# Fields
- `specs::NamedTuple` - NamedTuple of OptionSpecification objects

# Example
```julia
metadata(::Type{<:MyStrategy}) = StrategyMetadata((
    max_iter = OptionSpecification(
        type = Int,
        default = 100,
        description = "Maximum iterations",
        validator = x -> x > 0
    ),
    tol = OptionSpecification(
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
))
```

# Indexability
StrategyMetadata can be indexed to get individual specifications:
```julia
meta = metadata(MyStrategy)
meta[:max_iter]  # Returns OptionSpecification(...)
keys(meta)       # Returns (:max_iter, :tol)
```
"""
struct StrategyMetadata
    specs::NamedTuple  # NamedTuple{Names, <:Tuple{Vararg{OptionSpecification}}}

    function StrategyMetadata(specs::NamedTuple)
        # Validate that all values are OptionSpecification
        for (key, spec) in pairs(specs)
            if !isa(spec, OptionSpecification)
                error("All values must be OptionSpecification, got $(typeof(spec)) for key $key")
            end
        end
        new(specs)
    end
end

# Indexability
Base.getindex(meta::StrategyMetadata, key::Symbol) = meta.specs[key]
Base.keys(meta::StrategyMetadata) = keys(meta.specs)
Base.values(meta::StrategyMetadata) = values(meta.specs)
Base.pairs(meta::StrategyMetadata) = pairs(meta.specs)
Base.iterate(meta::StrategyMetadata, state...) = iterate(meta.specs, state...)
Base.length(meta::StrategyMetadata) = length(meta.specs)

# Display
function Base.show(io::IO, ::MIME"text/plain", meta::StrategyMetadata)
    println(io, "StrategyMetadata with $(length(meta)) options:")
    for (key, spec) in pairs(meta.specs)
        println(io, "  $key :: $(spec.type)")
        println(io, "    default: $(spec.default)")
        println(io, "    description: $(spec.description)")
        if !isempty(spec.aliases)
            println(io, "    aliases: $(spec.aliases)")
        end
    end
end

end # module Strategies
