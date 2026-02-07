# ============================================================================ #
# Orchestration Module - Method-Based Strategy Builders
# ============================================================================ #
# This file provides high-level functions for building strategies from method
# descriptions, combining routing and strategy construction.
# ============================================================================ #

module Orchestration

using ..Options
using ..Strategies

# ---------------------------------------------------------------------------- #
# Method-Based Strategy Construction
# ---------------------------------------------------------------------------- #

"""
    build_strategies_from_method(
        description::Tuple{Vararg{Symbol}},
        kwargs::NamedTuple,
        registry::StrategyRegistry
    ) -> Vector{AbstractStrategy}

Build strategies from a method description and options.

This is the main orchestration function that:
1. Routes options to separate strategy options from action options
2. Extracts option names required by the method
3. Builds each strategy in the method using the routed options

# Arguments
- `description`: Tuple of strategy names (e.g., `(:direct, :shooting)`)
- `kwargs`: All keyword arguments (action + strategy options mixed)
- `registry`: Strategy registry

# Returns
- Vector of constructed strategy instances

# Example
```julia
# User calls: solve(ocp, (:direct, :shooting), init=:warm, display=true, tol=1e-6)
# where tol is an action option, init and display are strategy options

strategies = build_strategies_from_method(
    (:direct, :shooting),
    (init=:warm, display=true, tol=1e-6),
    registry
)
# Returns: [DirectStrategy(...), ShootingStrategy(...)]
# Action option 'tol' is filtered out automatically
```

# Implementation Notes
- Uses `route_all_options` to separate action and strategy options
- Uses `Strategies.build_strategy_from_method` for each strategy
- Automatically handles option routing and validation
"""
function build_strategies_from_method(
    description::Tuple{Vararg{Symbol}},
    kwargs::NamedTuple,
    registry::StrategyRegistry
)::Vector{AbstractStrategy}
    
    # Route options first
    _, strategy_options = route_all_options(kwargs, registry)
    
    # Build each strategy in the method
    strategies = AbstractStrategy[]
    for strategy_name in description
        strategy = Strategies.build_strategy_from_method(
            strategy_name,
            strategy_options,
            registry
        )
        push!(strategies, strategy)
    end
    
    return strategies
end

# ---------------------------------------------------------------------------- #
# Option Name Extraction for Methods
# ---------------------------------------------------------------------------- #

"""
    option_names_from_method(
        description::Tuple{Vararg{Symbol}},
        registry::StrategyRegistry
    ) -> Set{Symbol}

Get all option names required by a method description.

# Arguments
- `description`: Tuple of strategy names
- `registry`: Strategy registry

# Returns
- Set of all option names used by strategies in the method

# Example
```julia
names = option_names_from_method((:direct, :shooting), registry)
# Returns: Set([:init, :display, :max_iter, :tol, ...])
```

# Use Case
This is useful for:
- Validating that all required options are provided
- Generating documentation for method options
- Implementing tab completion for method options
"""
function option_names_from_method(
    description::Tuple{Vararg{Symbol}},
    registry::StrategyRegistry
)::Set{Symbol}
    
    option_names = Set{Symbol}()
    for strategy_name in description
        strategy_option_names = Strategies.option_names_from_method(
            strategy_name,
            registry
        )
        union!(option_names, strategy_option_names)
    end
    
    return option_names
end

end # module Orchestration
