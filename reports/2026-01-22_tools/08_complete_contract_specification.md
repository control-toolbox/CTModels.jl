# Strategies Module - Complete Contract Specification

**Date**: 2026-01-22  
**Status**: Final - Complete Contract Definition

---

## Strategy Contract

Every strategy **must** implement the following contract to work with the Strategies module and registration system.

---

## Type-Level Contract (Static Metadata)

### Required Methods

#### 1. `symbol(::Type{<:MyStrategy}) -> Symbol`

**Purpose**: Returns the unique identifier for the strategy type.

**Requirements**:
- Must return a `Symbol` (e.g., `:adnlp`, `:ipopt`)
- Must be **unique within the strategy's family**
- Should be short and memorable

**Example**:
```julia
symbol(::Type{<:ADNLPModeler}) = :adnlp
```

---

#### 2. `metadata(::Type{<:MyStrategy}) -> StrategyMetadata`

**Purpose**: Returns the option specifications for the strategy.

**Requirements**:
- Must return a `StrategyMetadata` wrapping a `NamedTuple` of `OptionSpecification`
- Can return empty metadata: `StrategyMetadata(NamedTuple())`

**Example**:
```julia
metadata(::Type{<:ADNLPModeler}) = StrategyMetadata((
    backend = OptionSpecification(
        type = Symbol,
        default = :optimized,
        description = "AD backend used by ADNLPModels"
    ),
    show_time = OptionSpecification(
        type = Bool,
        default = false,
        description = "Whether to show timing information"
    ),
))
```

---

### Optional Methods

#### 3. `package_name(::Type{<:MyStrategy}) -> Union{String, Missing}`

**Purpose**: Returns the Julia package name for display purposes.

**Default**: Returns `missing`

**Example**:
```julia
package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
```

---

## Instance-Level Contract (Configured State)

### Required Field or Getter

#### 4. `options(strategy::MyStrategy) -> StrategyOptions`

**Purpose**: Returns the configured options for the strategy instance.

**Requirements**:
- Either have an `options::StrategyOptions` field (recommended)
- Or implement a custom `options()` getter

**Default implementation**: Accesses `.options` field

**Example (field-based)**:
```julia
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end

# Uses default implementation of options()
```

**Example (custom getter)**:
```julia
struct MyStrategy <: AbstractStrategy
    config::Dict  # Custom internal structure
end

function options(strategy::MyStrategy)
    # Convert custom structure to StrategyOptions
    return StrategyOptions(...)
end
```

---

## Constructor Contract

### Required Constructor

#### 5. `MyStrategy(; kwargs...) -> MyStrategy`

**Purpose**: Keyword-only constructor for building strategy instances.

**Requirements**:
- **Must** accept keyword arguments
- **Must** use `build_strategy_options()` to validate and merge options
- **Must** return an instance of the strategy

**Standard pattern**:
```julia
function MyStrategy(; kwargs...)
    options = build_strategy_options(MyStrategy; kwargs...)
    return MyStrategy(options)
end
```

**Why required**: The registration system uses this constructor to build strategies from IDs:
```julia
# This is what build_strategy() does internally:
T = type_from_id(:adnlp, AbstractOptimizationModeler)
return T(; backend=:sparse)  # ← Calls the kwargs constructor
```

---

## Complete Example

```julia
using CTModels.Strategies

# 1. Define the strategy type
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end

# 2. Type-level contract (REQUIRED)
symbol(::Type{<:MyStrategy}) = :mystrategy

metadata(::Type{<:MyStrategy}) = StrategyMetadata((
    max_iter = OptionSpecification(
        type = Int,
        default = 100,
        description = "Maximum number of iterations"
    ),
    tol = OptionSpecification(
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
))

# 3. Package name (OPTIONAL)
package_name(::Type{<:MyStrategy}) = "MyStrategyPackage"

# 4. Constructor (REQUIRED)
function MyStrategy(; kwargs...)
    options = build_strategy_options(MyStrategy; kwargs...)
    return MyStrategy(options)
end

# That's it! The strategy is now fully compliant.
```

---

## Usage

Once a strategy implements the contract, it can be:

### 1. Used directly
```julia
strategy = MyStrategy(max_iter=200, tol=1e-8)
```

### 2. Registered in a family
```julia
# In OptimalControl.jl
register_family!(AbstractMyStrategyFamily, (MyStrategy, OtherStrategy))
```

### 3. Built from ID
```julia
strategy = build_strategy(:mystrategy, AbstractMyStrategyFamily; max_iter=200)
```

### 4. Introspected
```julia
symbol(strategy)                    # => :mystrategy
metadata(strategy)                  # => StrategyMetadata (auto-displays)
options(strategy)                   # => StrategyOptions (auto-displays)
option_names(strategy)              # => (:max_iter, :tol)
option_value(strategy, :max_iter)   # => 200
option_source(strategy, :max_iter)  # => :user
```

---

## Contract Validation

The Strategies module provides a validation function for testing:

```julia
using CTModels.Strategies: validate_strategy_contract

# In tests
@test validate_strategy_contract(MyStrategy)
```

This checks:
- ✅ `symbol()` is implemented
- ✅ `metadata()` is implemented
- ✅ Constructor `MyStrategy(; kwargs...)` exists and works

---

## Summary: Contract Checklist

For a strategy to be fully compliant:

- [ ] **Type-level**:
  - [ ] `symbol(::Type{<:MyStrategy})` implemented
  - [ ] `metadata(::Type{<:MyStrategy})` implemented
  - [ ] `package_name(::Type{<:MyStrategy})` implemented (optional)

- [ ] **Instance-level**:
  - [ ] Has `options::StrategyOptions` field OR implements `options(strategy)`

- [ ] **Constructor**:
  - [ ] `MyStrategy(; kwargs...)` constructor implemented
  - [ ] Uses `build_strategy_options()` for validation

- [ ] **Testing**:
  - [ ] `validate_strategy_contract(MyStrategy)` passes

---

## Migration from Old Contract

### Old (AbstractOCPTool)
```julia
struct MyTool <: AbstractOCPTool
    options_values::NamedTuple
    options_sources::NamedTuple
end

get_symbol(::Type{<:MyTool}) = :mytool
_option_specs(::Type{<:MyTool}) = (...)
tool_package_name(::Type{<:MyTool}) = "MyPackage"

function MyTool(; kwargs...)
    values, sources = _build_ocp_tool_options(MyTool; kwargs...)
    return MyTool(values, sources)
end
```

### New (AbstractStrategy)
```julia
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions  # ← Unified structure
end

symbol(::Type{<:MyStrategy}) = :mystrategy  # ← No get_
metadata(::Type{<:MyStrategy}) = StrategyMetadata(...)  # ← Returns wrapper
package_name(::Type{<:MyStrategy}) = "MyPackage"  # ← No tool_ prefix

function MyStrategy(; kwargs...)
    options = build_strategy_options(MyStrategy; kwargs...)  # ← Unified
    return MyStrategy(options)
end
```

**Key changes**:
1. `options_values` + `options_sources` → `options::StrategyOptions`
2. `get_symbol` → `symbol`
3. `_option_specs` → `metadata` (returns `StrategyMetadata`)
4. `tool_package_name` → `package_name`
5. `_build_ocp_tool_options` → `build_strategy_options`
