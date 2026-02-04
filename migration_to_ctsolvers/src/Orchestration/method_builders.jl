# ============================================================================
# Method-based strategy builders and introspection wrappers
# ============================================================================

using ..Strategies
using DocStringExtensions

# ----------------------------------------------------------------------------
# Strategy Construction from Method
# ----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Build a strategy from a method tuple and options.

This is a convenience wrapper around `Strategies.build_strategy_from_method`
that allows callers to use the Orchestration namespace without explicitly
importing the Strategies module.

The function extracts the appropriate strategy ID from the method tuple for
the given family, then constructs the strategy with the provided options.

# Arguments
- `method::Tuple{Vararg{Symbol}}`: Tuple of strategy IDs (e.g.,
  `(:collocation, :adnlp, :ipopt)`)
- `family::Type{<:Strategies.AbstractStrategy}`: Abstract family type to
  search for
- `registry::Strategies.StrategyRegistry`: Strategy registry
- `kwargs...`: Options to pass to the strategy constructor

# Returns
- Concrete strategy instance of the appropriate type

# Throws

- `Exceptions.IncorrectArgument`: If the family is not found in the method or
  registry

# Example
```julia-repl
julia> method = (:collocation, :adnlp, :ipopt)

julia> modeler = build_strategy_from_method(
           method, 
           AbstractOptimizationModeler, 
           registry; 
           backend=:sparse
       )
ADNLPModeler(options=StrategyOptions{...})
```

See also: [`Strategies.build_strategy_from_method`](@ref),
[`option_names_from_method`](@ref)
"""
function build_strategy_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:Strategies.AbstractStrategy},
    registry::Strategies.StrategyRegistry;
    kwargs...
)
    return Strategies.build_strategy_from_method(
        method, family, registry; kwargs...
    )
end

# ----------------------------------------------------------------------------
# Option Name Extraction from Method
# ----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Get option names for a strategy family from a method tuple.

This is a convenience wrapper around `Strategies.option_names_from_method`
that combines ID extraction with option introspection.

# Arguments
- `method::Tuple{Vararg{Symbol}}`: Tuple of strategy IDs
- `family::Type{<:Strategies.AbstractStrategy}`: Abstract family type to
  search for
- `registry::Strategies.StrategyRegistry`: Strategy registry

# Returns
- `Tuple{Vararg{Symbol}}`: Tuple of option names for the identified strategy

# Throws

- `Exceptions.IncorrectArgument`: If the family is not found in the method or
  registry

# Example
```julia-repl
julia> method = (:collocation, :adnlp, :ipopt)

julia> option_names_from_method(method, AbstractOptimizationModeler, registry)
(:backend, :show_time)
```

See also: [`Strategies.option_names_from_method`](@ref),
[`build_strategy_from_method`](@ref)
"""
function option_names_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:Strategies.AbstractStrategy},
    registry::Strategies.StrategyRegistry
)
    return Strategies.option_names_from_method(method, family, registry)
end