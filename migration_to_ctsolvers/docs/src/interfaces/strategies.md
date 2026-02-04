# Implementing Strategies

This page explains how to implement configurable components using the **Strategies** architecture (`AbstractStrategy`). This is the modern replacement for the legacy `AbstractOCPTool` interface.

## Overview

A **Strategy** in CTModels is a configurable component that:

1. Is a subtype of [`AbstractStrategy`](@ref CTModels.Strategies.AbstractStrategy).
2. Described its available options via [`StrategyMetadata`](@ref CTModels.Strategies.StrategyMetadata) at the type level.
3. Stores its configuration in a single [`StrategyOptions`](@ref CTModels.Strategies.StrategyOptions) field.
4. Provides a keyword-only constructor that uses [`build_strategy_options`](@ref CTModels.Strategies.build_strategy_options) to validate inputs.

This architecture ensures:

* Type Stability: Options are stored in a type-stable structure.
* Validation: Options are validated against their definitions.
* Aliases: Users can use convenient aliases (e.g., `max_iter` vs `max_iterations`).
* Introspection: Tools can programmatically query available options and defaults.

## Quick Start

Here is a minimal complete example of a strategy:

```julia
using CTModels.Strategies

# 1. Define the strategy type
struct MySolver <: AbstractStrategy
    options::StrategyOptions
end

# 2. Implement the ID contract
Strategies.id(::Type{MySolver}) = :mysolver

# 3. Define metadata (available options)
Strategies.metadata(::Type{MySolver}) = StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum iterations",
        aliases = (:max, :max_iterations),
        validator = x -> x > 0
    )
)

# 4. Implement the constructor
function MySolver(; kwargs...)
    options = Strategies.build_strategy_options(MySolver; kwargs...)
    return MySolver(options)
end
```

**Usage:**

```julia
# Create with defaults
solver = MySolver()
# MySolver(options=StrategyOptions((max_iter = 100,)))

# Create with overrides (using aliases)
solver = MySolver(max=500)
# MySolver(options=StrategyOptions((max_iter = 500,)))

# Access options
val = Strategies.option_value(solver, :max_iter) # 500
```

## Strategy Contract

To implement a compliant strategy, you must fulfill the following contract.

### 1. The Type Definition

Your type must subtype `AbstractStrategy` (or an abstract subtype of it) and contain a field to store the options.

```julia
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end
```

The field name `options` is convention, but the `AbstractStrategy` interface uses the accessor method `Strategies.options(s)` which defaults to `s.options`. If you name the field differently, you must overload `Strategies.options`.

### 2. Type-Level Metadata

You must implement two methods for your type: `id` and `metadata`.

#### `Strategies.id`

Returns a unique `Symbol` identifier for the strategy.

```julia
Strategies.id(::Type{MyStrategy}) = :strategy_id
```

#### `Strategies.metadata`

Returns a `StrategyMetadata` object containing `OptionDefinition`s.

```julia


Strategies.metadata(::Type{MyStrategy}) = StrategyMetadata(
    # Option 1
    OptionDefinition(name=:opt1, type=Float64, default=1.0),
    # Option 2
    OptionDefinition(name=:opt2, type=Bool, default=false),
)
```

See [`OptionDefinition`](@ref CTModels.Options.OptionDefinition) for full details on defining options.

### 3. Constructor

You must provide a keyword constructor that delegates to `build_strategy_options`.

```julia
function MyStrategy(; kwargs...)
    options = Strategies.build_strategy_options(MyStrategy; kwargs...)
    return MyStrategy(options)
end
```

This helper function handles:

* Checking independent keys against the metadata.
* resolving aliases.
* Validating types and values.
* Merging user values with defaults.

## Strategy Families

Strategies are often grouped into **families**—abstract types that define a common purpose. For example:

* `AbstractOptimizationModeler`
* `AbstractOptimizationSolver`
* `AbstractOptimalControlDiscretizer`

When implementing a strategy for a family, subtype the family abstract type instead of `AbstractStrategy` directly.

```julia
abstract type AbstractSolver <: AbstractStrategy end

struct SolverA <: AbstractSolver
    options::StrategyOptions
end

struct SolverB <: AbstractSolver
    options::StrategyOptions
end
```

See [Creating Strategy Families](strategy_families.md) for details on managing families with registries.

## Advanced Topics

### Accessing Options

The `StrategyOptions` object provides optimized access to values.

**Generic Access:**

```julia
val = Strategies.option_value(strategy, :option_name)
```

**Type-Stable Access:**

For tight inner loops, use `get` with `Val`:

```julia
opts = Strategies.options(strategy)
val = get(opts, Val(:option_name))
```

This allows the compiler to infer the exact return type.

### Validation

You can verify your strategy implementation complies with the contract using `validate_strategy_contract`.

```julia
using Test
@test Strategies.validate_strategy_contract(MyStrategy)
```

## Migration Guide

If you are migrating from `AbstractOCPTool` to `AbstractStrategy`:

| Feature | Legacy (`AbstractOCPTool`) | Modern (`AbstractStrategy`) |
| :--- | :--- | :--- |
| **Type** | `<: AbstractOCPTool` | `<: AbstractStrategy` |
| **Storage** | `options_values::NT`, `options_sources::NT` | `options::StrategyOptions` |
| **ID** | `get_symbol(T)` | `Strategies.id(T)` |
| **Specs** | `_option_specs(T)` | `Strategies.metadata(T)` |
| **Build** | `_build_ocp_tool_options` | `Strategies.build_strategy_options` |
| **Schema** | `OptionSpec` | `OptionDefinition` |

### Example Migration

**Old Way:**

```julia
struct OldTool <: AbstractOCPTool
    options_values::NamedTuple
    options_sources::NamedTuple
end

CTModels.get_symbol(::Type{OldTool}) = :old
CTModels._option_specs(::Type{OldTool}) = (
    tol = OptionSpec(type=Float64, default=1e-6),
)

function OldTool(; kwargs...)
    # ... complex build ...
end
```

**New Way:**

```julia
struct NewStrategy <: AbstractStrategy
    options::StrategyOptions
end



Strategies.id(::Type{NewStrategy}) = :new
Strategies.metadata(::Type{NewStrategy}) = StrategyMetadata(
    OptionDefinition(name=:tol, type=Float64, default=1e-6)
)

function NewStrategy(; kwargs...)
    opts = Strategies.build_strategy_options(NewStrategy; kwargs...)
    return NewStrategy(opts)
end
```
