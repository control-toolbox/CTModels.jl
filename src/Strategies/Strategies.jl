"""
Strategy management and registry for CTModels.

This module provides:
- Abstract strategy contract and interface
- Strategy registry for explicit dependency management
- Strategy building and validation utilities
- Metadata management for strategy families

The Strategies module depends on Options for option handling
but provides higher-level strategy management capabilities.
"""
module Strategies

using CTBase: CTBase
using DocStringExtensions
using ..CTModels.Options

# ==============================================================================
# Include submodules
# ==============================================================================

include(joinpath(@__DIR__, "contract", "abstract_strategy.jl"))
include(joinpath(@__DIR__, "contract", "strategy_registry.jl"))
include(joinpath(@__DIR__, "contract", "metadata.jl"))
include(joinpath(@__DIR__, "contract", "option_specification.jl"))
include(joinpath(@__DIR__, "contract", "strategy_options.jl"))

include(joinpath(@__DIR__, "api", "builders.jl"))
include(joinpath(@__DIR__, "api", "configuration.jl"))
include(joinpath(@__DIR__, "api", "introspection.jl"))
include(joinpath(@__DIR__, "api", "registry.jl"))
include(joinpath(@__DIR__, "api", "utilities.jl"))
include(joinpath(@__DIR__, "api", "validation.jl"))

# ==============================================================================
# Public API
# ==============================================================================

export AbstractStrategy, StrategyRegistry, 
       build_strategy, build_strategy_from_id,
       configure_strategy, introspect_strategy,
       register_strategy!, lookup_strategy,
       validate_strategy, validate_strategy_contract,
       strategy_metadata, strategy_options,
       strategy_utilities

end # module Strategies
