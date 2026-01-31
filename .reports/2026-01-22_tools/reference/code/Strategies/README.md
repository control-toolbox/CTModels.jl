# Strategies Module - Code Annexes

This directory contains the reference implementation for the **Strategies** module.

---

## Structure

### `contract/` - What Users Must Implement

Types and methods that strategies must implement:

- **[abstract_strategy.jl](contract/abstract_strategy.jl)** - `AbstractStrategy` type and required methods (`symbol()`, `metadata()`, `options()`)
- **[option_specification.jl](contract/option_specification.jl)** - `OptionSpecification` type for defining option specs
- **[strategy_options.jl](contract/strategy_options.jl)** - `StrategyOptions` type for configured options
- **[metadata.jl](contract/metadata.jl)** - `StrategyMetadata` type wrapping option specifications

### `api/` - What the System Provides

Functions provided by the Strategies module:

- **[introspection.jl](api/introspection.jl)** - `option_names()`, `option_type()`, `option_description()`, `option_default()`, `option_defaults()`
- **[configuration.jl](api/configuration.jl)** - `build_strategy_options()`, `option_value()`, `option_source()`
- **[registry.jl](api/registry.jl)** - `StrategyRegistry`, `create_registry()`, `strategy_ids()`, `type_from_id()`
- **[builders.jl](api/builders.jl)** - `build_strategy()`, `extract_id_from_method()`, `option_names_from_method()`, `build_strategy_from_method()`
- **[validation.jl](api/validation.jl)** - `validate_strategy_contract()`

---

## Contract vs API

**CONTRACT** (in `contract/`):

- What every strategy **must** implement
- Abstract types and required methods
- Data structures for metadata and options

**API** (in `api/`):

- What the system **provides**
- Helper functions for introspection
- Configuration and building utilities
- Registry management

---

## Complete Example

```julia
using CTModels.Strategies

# 1. Define strategy type
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end

# 2. Implement contract - Type level
symbol(::Type{<:MyStrategy}) = :mystrategy

metadata(::Type{<:MyStrategy}) = StrategyMetadata((
    max_iter = OptionSpecification(
        type = Int,
        default = 100,
        description = "Maximum iterations",
        aliases = (:max, :maxiter),
        validator = x -> x > 0
    ),
    tol = OptionSpecification(
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
))

# 3. Constructor using API
MyStrategy(; kwargs...) = MyStrategy(build_strategy_options(MyStrategy; kwargs...))

# 4. Usage
strategy = MyStrategy(max_iter=200)  # Using primary name
strategy = MyStrategy(max=200)       # Using alias

# Introspection
option_names(strategy)                    # => (:max_iter, :tol)
option_type(strategy, :max_iter)          # => Int
option_description(strategy, :max_iter)   # => "Maximum iterations"
option_default(strategy, :max_iter)       # => 100
option_value(strategy, :max_iter)         # => 200
option_source(strategy, :max_iter)        # => :user
option_source(strategy, :tol)             # => :default
```

---

## See Also

- [../README.md](../README.md) - Overall code annexes documentation
- [../../08_complete_contract_specification.md](../../08_complete_contract_specification.md) - Complete contract specification
- [../../05_design_decisions_summary.md](../../05_design_decisions_summary.md) - Design decisions
- [../../13_module_dependencies_architecture.md](../../13_module_dependencies_architecture.md) - Module architecture
