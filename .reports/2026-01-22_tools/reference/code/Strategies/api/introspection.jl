# ============================================================================ #
# Strategies Module - Introspection API
# ============================================================================ #
# This file implements introspection methods for strategies.
# ============================================================================ #

module Strategies

"""
    option_names(strategy)
    option_names(strategy_type::Type{<:AbstractStrategy})

Get all option names for a strategy.

# Example
```julia
option_names(MyStrategy)  # => (:max_iter, :tol)
option_names(strategy)    # => (:max_iter, :tol)
```
"""
option_names(strategy::AbstractStrategy) = Tuple(keys(metadata(typeof(strategy)).specs))
option_names(strategy_type::Type{<:AbstractStrategy}) = Tuple(keys(metadata(strategy_type).specs))

"""
    option_type(strategy, key::Symbol)
    option_type(strategy_type::Type{<:AbstractStrategy}, key::Symbol)

Get the type of an option.

# Example
```julia
option_type(MyStrategy, :max_iter)  # => Int
```
"""
function option_type(strategy::AbstractStrategy, key::Symbol)
    meta = metadata(typeof(strategy))
    return meta[key].type
end

function option_type(strategy_type::Type{<:AbstractStrategy}, key::Symbol)
    meta = metadata(strategy_type)
    return meta[key].type
end

"""
    option_description(strategy, key::Symbol)
    option_description(strategy_type::Type{<:AbstractStrategy}, key::Symbol)

Get the description of an option.

# Example
```julia
option_description(MyStrategy, :max_iter)  # => "Maximum iterations"
```
"""
function option_description(strategy::AbstractStrategy, key::Symbol)
    meta = metadata(typeof(strategy))
    return meta[key].description
end

function option_description(strategy_type::Type{<:AbstractStrategy}, key::Symbol)
    meta = metadata(strategy_type)
    return meta[key].description
end

"""
    option_default(strategy, key::Symbol)
    option_default(strategy_type::Type{<:AbstractStrategy}, key::Symbol)

Get the default value of an option.

# Example
```julia
option_default(MyStrategy, :max_iter)  # => 100
```
"""
function option_default(strategy::AbstractStrategy, key::Symbol)
    meta = metadata(typeof(strategy))
    return meta[key].default
end

function option_default(strategy_type::Type{<:AbstractStrategy}, key::Symbol)
    meta = metadata(strategy_type)
    return meta[key].default
end

"""
    option_defaults(strategy_type::Type{<:AbstractStrategy})

Get all default values as a NamedTuple.

# Example
```julia
option_defaults(MyStrategy)  # => (max_iter=100, tol=1e-6)
```
"""
function option_defaults(strategy_type::Type{<:AbstractStrategy})
    meta = metadata(strategy_type)
    defaults = NamedTuple(
        key => spec.default
        for (key, spec) in pairs(meta.specs)
    )
    return defaults
end

"""
    package_name(strategy)
    package_name(strategy_type::Type{<:AbstractStrategy})

Get the package name for a strategy (if available in metadata).

# Example
```julia
package_name(ADNLPModeler)  # => "ADNLPModels"
```

# Note
This is a helper function. The actual package name should be stored
in the strategy's metadata or implemented as a separate method.
"""
function package_name end

"""
    description(strategy)
    description(strategy_type::Type{<:AbstractStrategy})

Get a human-readable description of the strategy.

# Note
This is a helper function that could extract description from metadata
or be implemented separately by strategies.
"""
function description end

end # module Strategies
