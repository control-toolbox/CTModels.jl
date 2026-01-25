# Example: Integration

This example demonstrates how strategies might be integrated into a larger system (like a `solve` function).

```@example integration
using CTModels.Strategies

# Mock Registry and Family from previous examples
abstract type IntegrationSolver <: AbstractStrategy end

struct BasicSolver <: IntegrationSolver
    options::StrategyOptions
end
Strategies.id(::Type{BasicSolver}) = :basic
Strategies.metadata(::Type{BasicSolver}) = StrategyMetadata(
    OptionDefinition(name=:verbose, type=Bool, default=false)
)
BasicSolver(;kw...) = BasicSolver(Strategies.build_strategy_options(BasicSolver; kw...))

const REGISTRY = Strategies.create_registry(
    IntegrationSolver => (BasicSolver,)
)

# Mock Solve Function
function solve(problem; method=:basic, kwargs...)
    # 1. Identify the strategy type from the method ID
    # In a real app, 'method' might need disambiguation if multiple families exist
    strategy_id = method
    
    # 2. Build the strategy instance using the registry
    # We pass 'kwargs' down to the strategy constructor
    strategy = Strategies.build_strategy(
        strategy_id, 
        IntegrationSolver, 
        REGISTRY; 
        kwargs...
    )
    
    # 3. Use the strategy
    println("Solving with ", Strategies.id(strategy))
    if Strategies.option_value(strategy, :verbose)
        println("... verbose output ...")
    end
    
    return "Solution"
end

# User calls solve
solve("my_problem", method=:basic, verbose=true)
```
