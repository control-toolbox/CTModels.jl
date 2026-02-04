# ============================================================================
# Strategy configuration and setup
# ============================================================================

using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Build StrategyOptions from user kwargs and strategy metadata.

This function creates a StrategyOptions instance by:
1. Extracting options from kwargs using the Options API
2. Converting the extracted Dict to NamedTuple
3. Wrapping in StrategyOptions

The Options.extract_options function handles:
- Alias resolution to primary names
- Type validation
- Custom validators
- Default values
- Provenance tracking (:user, :default)

# Arguments
- `strategy_type::Type{<:AbstractStrategy}`: The strategy type to build options for
- `kwargs...`: User-provided option values

# Returns
- `StrategyOptions`: Validated options with provenance tracking

# Throws

- `Exceptions.IncorrectArgument`: If an unknown option is provided
- `Exceptions.IncorrectArgument`: If type validation fails
- `Exceptions.IncorrectArgument`: If custom validation fails

# Example
```julia-repl
julia> opts = build_strategy_options(MyStrategy; max_iter=200)
StrategyOptions(...)

julia> opts[:max_iter]
200
```

See also: [`StrategyOptions`](@ref), [`metadata`](@ref), [`Options.extract_options`](@ref)
"""
function build_strategy_options(
    strategy_type::Type{<:AbstractStrategy};
    kwargs...
)
    meta = metadata(strategy_type)
    defs = collect(values(meta.specs))
    
    # Use Options.extract_options for validation and extraction
    extracted, _ = Options.extract_options((; kwargs...), defs)
    
    # Convert Dict to NamedTuple
    nt = (; (k => v for (k, v) in extracted)...)
    
    return StrategyOptions(nt)
end

"""
$(TYPEDSIGNATURES)

Resolve an alias to its primary key name.

Searches through strategy metadata to find if a given key is either:
1. A primary option name
2. An alias for a primary option name

# Arguments
- `meta::StrategyMetadata`: Strategy metadata to search in
- `key::Symbol`: Key to resolve (can be primary name or alias)

# Returns
- `Union{Symbol, Nothing}`: Primary key if found, `nothing` otherwise

# Example
```julia-repl
julia> meta = metadata(MyStrategy)
julia> resolve_alias(meta, :max_iter)  # Primary name
:max_iter

julia> resolve_alias(meta, :max)  # Alias
:max_iter

julia> resolve_alias(meta, :unknown)  # Not found
nothing
```

See also: [`StrategyMetadata`](@ref), [`OptionDefinition`](@ref)
"""
function resolve_alias(meta::StrategyMetadata, key::Symbol)
    # Check if key is a primary name
    if haskey(meta.specs, key)
        return key
    end
    
    # Check if key is an alias
    for (primary_key, spec) in pairs(meta.specs)
        if key in spec.aliases
            return primary_key
        end
    end
    
    return nothing
end
