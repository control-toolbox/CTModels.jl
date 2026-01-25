# Example: Strategy with Options

This example demonstrates a strategy with multiple options, including aliases and validators.

```@example strategy_options
using CTModels.Strategies

# 1. Define type
struct SolverWithOptions <: AbstractStrategy
    options::StrategyOptions
end

Strategies.id(::Type{SolverWithOptions}) = :solver_with_options

# 2. Define Metadata
Strategies.metadata(::Type{SolverWithOptions}) = StrategyMetadata(
    OptionDefinition(
        name = :tol, 
        type = Float64, 
        default = 1e-6, 
        description = "Tolerance",
        aliases = (:tolerance, :epsilon),
        validator = x -> x > 0
    ),
    OptionDefinition(
        name = :max_iter, 
        type = Int, 
        default = 100,
        aliases = (:N,),
        validator = x -> x > 0
    )
)

# 3. Constructor
function SolverWithOptions(; kwargs...)
    options = Strategies.build_strategy_options(SolverWithOptions; kwargs...)
    return SolverWithOptions(options)
end

# Usage
# Using aliases
s = SolverWithOptions(epsilon=1e-8, N=500)

println("Tolerance: ", Strategies.option_value(s, :tol))
println("Max Iter: ", Strategies.option_value(s, :max_iter))
```
