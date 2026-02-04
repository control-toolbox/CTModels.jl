# Example: Simple Strategy

This example demonstrates the minimal code required to implement a strategy with no options.

```@example simple_strategy
using CTModels.Strategies

# 1. Define the strategy type
struct NoOptionStrategy <: AbstractStrategy
    options::StrategyOptions
end

# 2. Implement ID
Strategies.id(::Type{NoOptionStrategy}) = :no_opt

# 3. Implement Metadata (Empty)
Strategies.metadata(::Type{NoOptionStrategy}) = StrategyMetadata()

# 4. Implement Constructor
function NoOptionStrategy(; kwargs...)
    options = Strategies.build_strategy_options(NoOptionStrategy; kwargs...)
    return NoOptionStrategy(options)
end

# Usage
s = NoOptionStrategy()
println("Strategy created: ", Strategies.id(s))
```
