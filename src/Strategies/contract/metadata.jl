# ============================================================================ #
# Strategies Module - StrategyMetadata
# ============================================================================ #
# This file defines the StrategyMetadata type wrapping option specifications.
# ============================================================================ #

"""
    StrategyMetadata

Metadata about a strategy type, wrapping option definitions.

# Fields
- `specs::NamedTuple` - NamedTuple of OptionDefinition objects

# Example
```julia
metadata(::Type{<:MyStrategy}) = StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum iterations",
        aliases = (:max, :maxiter),
        validator = x -> x > 0
    ),
    OptionDefinition(
        name = :tol,
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
)
```

# Indexability
StrategyMetadata can be indexed to get individual definitions:
```julia
meta = metadata(MyStrategy)
meta[:max_iter]  # Returns OptionDefinition(...)
keys(meta)       # Returns (:max_iter, :tol)
```
"""
struct StrategyMetadata
    specs::Dict{Symbol, OptionDefinition}
    
    function StrategyMetadata(defs::OptionDefinition...)
        # Convert to Dict using names
        specs_dict = Dict{Symbol, OptionDefinition}()
        
        for def in defs
            if haskey(specs_dict, def.name)
                error("Duplicate option name: $(def.name)")
            end
            specs_dict[def.name] = def
        end
        
        new(specs_dict)
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
    for (key, def) in pairs(meta.specs)
        println(io, "  $key :: $(def.type)")
        println(io, "    default: $(def.default)")
        println(io, "    description: $(def.description)")
        if !isempty(def.aliases)
            println(io, "    aliases: $(def.aliases)")
        end
    end
end
