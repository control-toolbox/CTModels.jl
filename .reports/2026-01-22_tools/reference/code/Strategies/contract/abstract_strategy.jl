# Strategies Module - abstract_strategy.jl

"""
    AbstractStrategy

Abstract type for all strategies.

All concrete strategies must implement:
- `symbol(::Type{<:AbstractStrategy})::Symbol` - Unique identifier
- `metadata(::Type{<:AbstractStrategy})::StrategyMetadata` - Strategy metadata
- `options(::AbstractStrategy)::StrategyOptions` - Configured options
- `MyStrategy(; kwargs...)` - Constructor using build_strategy_options()
"""
abstract type AbstractStrategy end

"""
    symbol(strategy_type::Type{<:AbstractStrategy})

Return the unique symbol identifying this strategy type.

# Example
```julia
symbol(ADNLPModeler) # => :adnlp
```
"""
function symbol end

"""
    symbol(strategy::AbstractStrategy)

Return the symbol for a strategy instance.
"""
symbol(strategy::AbstractStrategy) = symbol(typeof(strategy))

"""
    options(strategy::AbstractStrategy)

Return the current options of a strategy as a NamedTuple of OptionValues.

# Example
```julia
modeler = ADNLPModeler(backend=:sparse)
opts = options(modeler) # => StrategyOptions with backend=:sparse (:user), etc.
```
"""
function options end

"""
    metadata(strategy_type::Type{<:AbstractStrategy})

Return metadata about a strategy type.

# Example
```julia
meta = metadata(ADNLPModeler)
# => StrategyMetadata(
#        package_name="ADNLPModels",
#        description="NLP modeler using ADNLPModels",
#        option_names=(:backend, :show_time)
#    )
```
"""
function metadata end

# Default implementations that error if not overridden
function symbol(::Type{T}) where {T<:AbstractStrategy}
    throw(CTBase.NotImplemented("symbol(::Type{<:$T}) must be implemented"))
end

function metadata(::Type{T}) where {T<:AbstractStrategy}
    throw(CTBase.NotImplemented(
        "metadata(::Type{<:$T}) must be implemented. " *
        "Return a StrategyMetadata wrapping a NamedTuple of OptionSpecification."
    ))
end

function options(tool::T) where {T<:AbstractStrategy}
    if hasfield(T, :options)
        return getfield(tool, :options)
    else
        throw(CTBase.NotImplemented(
            "Strategy $T must either have an `options::StrategyOptions` field " *
            "or implement options(::$T)"
        ))
    end
end
