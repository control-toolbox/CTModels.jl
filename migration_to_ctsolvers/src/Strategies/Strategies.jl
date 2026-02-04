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

using CTBase: CTBase, Exceptions
using DocStringExtensions
using ..CTModels.Options

# ==============================================================================
# Include submodules
# ==============================================================================

include(joinpath(@__DIR__, "contract", "abstract_strategy.jl"))
include(joinpath(@__DIR__, "contract", "metadata.jl"))
include(joinpath(@__DIR__, "contract", "strategy_options.jl"))

include(joinpath(@__DIR__, "api", "registry.jl"))
include(joinpath(@__DIR__, "api", "introspection.jl"))
include(joinpath(@__DIR__, "api", "builders.jl"))
include(joinpath(@__DIR__, "api", "configuration.jl"))
include(joinpath(@__DIR__, "api", "utilities.jl"))
include(joinpath(@__DIR__, "api", "validation.jl"))

# ==============================================================================
# Public API
# ==============================================================================

# Core types
export AbstractStrategy, StrategyRegistry, StrategyMetadata, StrategyOptions, OptionDefinition

# Type-level contract methods
export id, metadata

# Instance-level contract methods
export options

# Registry functions
export create_registry, strategy_ids, type_from_id

# Introspection functions
export option_names, option_type, option_description, option_default, option_defaults
export option_value, option_source
export is_user, is_default, is_computed

# Builder functions
export build_strategy, build_strategy_from_method
export extract_id_from_method, option_names_from_method

# Configuration functions
export build_strategy_options, resolve_alias

# Utility functions
export filter_options, suggest_options

# Validation functions
export validate_strategy_contract

end # module Strategies
