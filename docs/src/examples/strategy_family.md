# Example: Strategy Family

This example demonstrates how to create a family of strategies and a registry.

```@example family
using CTModels.Strategies

# 1. abstract Family
abstract type AbstractDiscretizer <: AbstractStrategy end

# 2. Concrete Members
struct Collocation <: AbstractDiscretizer
    options::StrategyOptions
end
Strategies.id(::Type{Collocation}) = :collocation
Strategies.metadata(::Type{Collocation}) = StrategyMetadata(
    OptionDefinition(name=:points, type=Int, default=100)
)
Collocation(;kw...) = Collocation(Strategies.build_strategy_options(Collocation; kw...))

struct Shooting <: AbstractDiscretizer
    options::StrategyOptions
end
Strategies.id(::Type{Shooting}) = :shooting
Strategies.metadata(::Type{Shooting}) = StrategyMetadata(
    OptionDefinition(name=:step, type=Float64, default=0.1)
)
Shooting(;kw...) = Shooting(Strategies.build_strategy_options(Shooting; kw...))

# 3. Registry
const DISC_REGISTRY = Strategies.create_registry(
    AbstractDiscretizer => (Collocation, Shooting)
)

# 4. Usage
# Build based on ID
d1 = Strategies.build_strategy(:collocation, AbstractDiscretizer, DISC_REGISTRY; points=50)
d2 = Strategies.build_strategy(:shooting, AbstractDiscretizer, DISC_REGISTRY; step=0.01)

println("Discretizer 1: ", Strategies.id(d1), ", points=", Strategies.option_value(d1, :points))
println("Discretizer 2: ", Strategies.id(d2), ", step=", Strategies.option_value(d2, :step))
```
