# ============================================================================ #
# Strategies Module - StrategyMetadata
# ============================================================================ #
# This file defines the StrategyMetadata type wrapping option specifications.
# ============================================================================ #

"""
$(TYPEDEF)

Metadata about a strategy type, wrapping option definitions.

This type serves as a container for `OptionDefinition` objects that define
the contract for a strategy's configuration options. It provides a convenient
interface for accessing and managing option definitions through standard
Julia collection interfaces.

# Fields
- `specs::Dict{Symbol, OptionDefinition}`: Dictionary mapping option names to their definitions.

# Notes
- This type is internal to the Strategies module and not exported.
- Option names must be unique within a StrategyMetadata instance.
- The constructor validates that all option names are unique.
- Supports standard collection interfaces: `getindex`, `keys`, `values`, `pairs`, `iterate`, `length`.

# Example
```julia-repl
julia> using CTModels.Strategies

julia> meta = StrategyMetadata(
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
           )
       )
StrategyMetadata with 2 options

julia> meta[:max_iter].name
:max_iter

julia> collect(keys(meta))
[:max_iter, :tol]
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
        println(io, "  $def")
    end
end
