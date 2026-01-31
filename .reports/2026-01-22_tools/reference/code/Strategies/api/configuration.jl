# ============================================================================ #
# Strategies Module - Configuration API
# ============================================================================ #
# This file implements configuration methods for building strategy options.
# ============================================================================ #

module Strategies

"""
    build_strategy_options(strategy_type::Type{<:AbstractStrategy}; kwargs...)

Build StrategyOptions from user kwargs and defaults.

# Algorithm
1. Start with all default values from metadata
2. Override with user-provided values
3. Resolve aliases to primary names
4. Validate types
5. Run custom validators
6. Track sources (:user or :default)

# Example
```julia
options = build_strategy_options(MyStrategy; max_iter=200)
# => StrategyOptions(
#      values=(max_iter=200, tol=1e-6),
#      sources=(max_iter=:user, tol=:default)
#    )
```

# Errors
- Unknown option or alias
- Type mismatch
- Validation failure
"""
function build_strategy_options(
    strategy_type::Type{<:AbstractStrategy};
    kwargs...
)
    meta = metadata(strategy_type)
    
    # Start with defaults
    values = Dict{Symbol, Any}()
    sources = Dict{Symbol, Symbol}()
    
    for (key, spec) in pairs(meta.specs)
        values[key] = spec.default
        sources[key] = :default
    end
    
    # Override with user values
    for (key, value) in pairs(kwargs)
        # Resolve alias to primary key
        actual_key = resolve_alias(meta, key)
        if actual_key === nothing
            available = collect(keys(meta.specs))
            error("Unknown option: $key. Available options: $available")
        end
        
        # Get specification
        spec = meta[actual_key]
        
        # Validate type
        if !isa(value, spec.type)
            error("Option $actual_key expects type $(spec.type), got $(typeof(value))")
        end
        
        # Validate with custom validator
        if spec.validator !== nothing
            if !spec.validator(value)
                error("Validation failed for option $actual_key with value $value")
            end
        end
        
        # Store value and source
        values[actual_key] = value
        sources[actual_key] = :user
    end
    
    return StrategyOptions(NamedTuple(values), NamedTuple(sources))
end

"""
    option_value(strategy::AbstractStrategy, key::Symbol)

Get the current value of an option.

# Example
```julia
strategy = MyStrategy(max_iter=200)
option_value(strategy, :max_iter)  # => 200
```
"""
function option_value(strategy::AbstractStrategy, key::Symbol)
    opts = options(strategy)
    return opts.values[key]
end

"""
    option_source(strategy::AbstractStrategy, key::Symbol)

Get the source of an option value (:user or :default).

# Example
```julia
strategy = MyStrategy(max_iter=200)
option_source(strategy, :max_iter)  # => :user
option_source(strategy, :tol)       # => :default
```
"""
function option_source(strategy::AbstractStrategy, key::Symbol)
    opts = options(strategy)
    return opts.sources[key]
end

"""
    resolve_alias(meta::StrategyMetadata, key::Symbol)

Resolve an alias to its primary key name.

Returns the primary key if found, `nothing` otherwise.

# Example
```julia
# If :init is an alias for :initial_guess
resolve_alias(meta, :init)  # => :initial_guess
resolve_alias(meta, :initial_guess)  # => :initial_guess
resolve_alias(meta, :unknown)  # => nothing
```
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

end # module Strategies
