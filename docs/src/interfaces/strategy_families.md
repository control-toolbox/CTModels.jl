# Creating Strategy Families

This page explains how to organize related strategies into **families** and manage them using a **Registry**.

## What are Strategy Families?

A **Strategy Family** is a group of strategies that share a common purpose and abstract supertype. Examples include:

*   **Modelers**: Transform an OCP into an NLP (e.g., `ADNLPModeler`, `ExaModeler`).
*   **Solvers**: Solve the resulting NLP (e.g., `IpoptSolver`, `MadNLPSolver`).

By defining a family, you allow the system to treat different implementations interchangeably.

## Defining a Family

Start by defining an abstract type that inherits from `AbstractStrategy`.

```julia
using CTModels.Strategies

"""
    AbstractMyFamily

Abstract base type for all MyFamily strategies.
"""
abstract type AbstractMyFamily <: AbstractStrategy end
```

## Implementing Family Members

Implement concrete strategies that subtype your family abstract type.

```julia
struct MemberA <: AbstractMyFamily
    options::StrategyOptions
end

Strategies.id(::Type{MemberA}) = :a
Strategies.metadata(::Type{MemberA}) = StrategyMetadata(...)
# ... constructor ...
```

```julia
struct MemberB <: AbstractMyFamily
    options::StrategyOptions
end

Strategies.id(::Type{MemberB}) = :b
Strategies.metadata(::Type{MemberB}) = StrategyMetadata(...)
# ... constructor ...
```

## Registry Integration

A **Strategy Registry** maps symbols (IDs) to concrete types for a given family. This allows users to select a strategy by name (e.g., `backend=:adnlp`).

### Creating a Registry

Use [`create_registry`](@ref CTModels.Strategies.create_registry) to define the mappings.

```julia
const MY_REGISTRY = Strategies.create_registry(
    AbstractMyFamily => (MemberA, MemberB)
)
```

You can register multiple families in a single registry:

```julia
const GLOBAL_REGISTRY = Strategies.create_registry(
    AbstractModeler => (ADNLPModeler, ExaModeler),
    AbstractSolver  => (IpoptSolver, MadNLPSolver)
)
```

### Using the Registry

The registry powers helper functions like [`build_strategy`](@ref CTModels.Strategies.build_strategy).

```julia
# User asks for strategy :a
strategy = Strategies.build_strategy(
    :a,                 # ID
    AbstractMyFamily,   # Family
    MY_REGISTRY;        # Registry
    param=10            # Options
)
# Returns an instance of MemberA
```

## Complete Example: Optimization Modelers

Here is how you might structure a family of optimization modelers.

```julia
# 1. Define Family
abstract type AbstractOptimizationModeler <: AbstractStrategy end

# 2. Define Members
struct ADNLPModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end
Strategies.id(::Type{ADNLPModeler}) = :adnlp
# ... metadata ...

struct ExaModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end
Strategies.id(::Type{ExaModeler}) = :exa
# ... metadata ...

# 3. Create Registry
const MODELER_REGISTRY = Strategies.create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler)
)
```

## Dependency Injection

The `CTModels` architecture encourages **explicit** registry passing. When building higher-level systems (like an Orchestrator), you pass the registry as an argument rather than relying on a global variable.

```julia
function solve(ocp; user_registry=DEFAULT_REGISTRY, kwargs...)
    # ... use user_registry to look up strategies ...
end
```

## Testing Strategies

You should test that your strategies fulfill the contract.

```julia
using Test

@testset "MyFamily Contract" begin
    for StrategyType in (MemberA, MemberB)
        @test Strategies.validate_strategy_contract(StrategyType)
        
        # Test instantiation
        s = StrategyType()
        @test s isa AbstractMyFamily
        @test Strategies.id(s) isa Symbol
    end
end
```
