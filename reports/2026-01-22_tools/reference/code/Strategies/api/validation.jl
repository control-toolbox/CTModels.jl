# ============================================================================ #
# Strategies Module - Validation API
# ============================================================================ #
# This file implements the contract validation utility.
# ============================================================================ #

module Strategies

"""
    validate_strategy_contract(strategy_type::Type{<:AbstractStrategy}) -> Bool

Verify that a strategy type correctly implements the required contract.

# Checks
1. `symbol(strategy_type)` returns a Symbol
2. `metadata(strategy_type)` returns a StrategyMetadata
3. Configuration from metadata can be used to build StrategyOptions
4. Default constructor `strategy_type(; kwargs...)` exists and works

# Returns
`true` if all checks pass, throws an error otherwise.

# Example
```julia
using Test
@test validate_strategy_contract(MyStrategy)
```
"""
function validate_strategy_contract(strategy_type::Type{T}) where {T<:AbstractStrategy}
    # 1. Symbol check
    s = try
        symbol(strategy_type)
    catch e
        error("symbol(::Type{<:$T}) failed: $e")
    end
    if !isa(s, Symbol)
        error("symbol(::Type{<:$T}) must return a Symbol, got $(typeof(s))")
    end

    # 2. Metadata check
    meta = try
        metadata(strategy_type)
    catch e
        error("metadata(::Type{<:$T}) failed: $e")
    end
    if !isa(meta, StrategyMetadata)
        error("metadata(::Type{<:$T}) must return a StrategyMetadata, got $(typeof(meta))")
    end

    # 3. Constructor and build_strategy_options check
    # Try creating an instance with default options
    instance = try
        strategy_type()
    catch e
        error("Default constructor $T() failed. Ensure $T(; kwargs...) is implemented and uses build_strategy_options: $e")
    end

    # 4. Instance options check
    opts = try
        options(instance)
    catch e
        error("options(:: $T) failed: $e")
    end
    if !isa(opts, StrategyOptions)
        error("options(:: $T) must return a StrategyOptions, got $(typeof(opts))")
    end

    return true
end

end # module Strategies
