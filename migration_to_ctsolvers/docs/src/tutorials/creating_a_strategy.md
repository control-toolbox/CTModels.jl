# Tutorial: Creating Your First Strategy

In this tutorial, we will walk through the process of creating a new strategy from scratch. We will build a hypothetical `SimpleSolver` strategy that has a few configurable options.

## Prerequisites

You should have `CTModels` installed and be familiar with basic Julia struct definitions.

## Step 1: Define the Strategy Type

First, we define a concrete struct for our strategy. It must subtype `AbstractStrategy` and must have a field to store the options.

```julia
using CTModels.Strategies

struct SimpleSolver <: AbstractStrategy
    options::StrategyOptions
end
```

## Step 2: Implement the ID Method

Every strategy needs a unique identifier (ID). This is used to refer to the strategy in registries and error messages.

```julia
Strategies.id(::Type{SimpleSolver}) = :simple
```

## Step 3: Define Metadata

The `metadata` method describes the options that this strategy accepts. We use [`StrategyMetadata`](@ref CTModels.Strategies.StrategyMetadata) and [`OptionDefinition`](@ref CTModels.Options.OptionDefinition).

Let's define two options:

1. `max_iter`: An integer for maximum iterations.
2. `verbose`: A boolean to control output.

```julia
Strategies.metadata(::Type{SimpleSolver}) = StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum number of iterations",
        aliases = (:N, :iterations),
        validator = x -> x > 0
    ),
    OptionDefinition(
        name = :verbose,
        type = Bool,
        default = false,
        description = "Print solver progress"
    )
)
```

Notice we added:

* **Aliases**: Users can pass `N=50` or `iterations=50` instead of `max_iter`.
* **Validator**: We ensure `max_iter` is positive.

## Step 4: Implement the Constructor

The constructor is responsible for taking user keyword arguments, validating them against the metadata, and creating the `StrategyOptions` object. `CTModels` provides a helper for this.

```julia
function SimpleSolver(; kwargs...)
    options = Strategies.build_strategy_options(SimpleSolver; kwargs...)
    return SimpleSolver(options)
end
```

## Step 5: Test Your Strategy

Now we can instantiate and use our strategy.

```julia
# Create with default values
solver1 = SimpleSolver()

# Check values
using Test
@test Strategies.option_value(solver1, :max_iter) == 100
@test Strategies.option_value(solver1, :verbose) == false

# Create with user values and aliases
solver2 = SimpleSolver(N=500, verbose=true)
@test Strategies.option_value(solver2, :max_iter) == 500
@test Strategies.option_value(solver2, :verbose) == true

# Ensure validation works
@test_throws Exception SimpleSolver(max_iter=-10) # Should fail
```

## Full Code

Here is the complete code for `SimpleSolver`:

```julia
using CTModels.Strategies

struct SimpleSolver <: AbstractStrategy
    options::StrategyOptions
end

Strategies.id(::Type{SimpleSolver}) = :simple

Strategies.metadata(::Type{SimpleSolver}) = StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum number of iterations",
        aliases = (:N, :iterations),
        validator = x -> x > 0
    ),
    OptionDefinition(
        name = :verbose,
        type = Bool,
        default = false,
        description = "Print solver progress"
    )
)

function SimpleSolver(; kwargs...)
    options = Strategies.build_strategy_options(SimpleSolver; kwargs...)
    return SimpleSolver(options)
end
```

## Next Steps

* Learn how to organize strategies into [families](../interfaces/strategy_families.md).
* Explore advanced [`OptionDefinition`](@ref CTModels.Options.OptionDefinition) features.
