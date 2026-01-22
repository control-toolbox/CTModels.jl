# Registration System - Final Design (Hybrid Approach)

**Date**: 2026-01-22  
**Status**: **SUPERSEDED** - See 11_explicit_registry_architecture.md

> [!IMPORTANT]
> This document describes the **hybrid approach with global registry**.
>
> **This has been superseded** by the **explicit registry** approach documented in:
> `11_explicit_registry_architecture.md`
>
> The explicit registry approach was chosen for:
>
> - No global mutable state
> - Better testability
> - Explicit dependencies
> - Thread safety

---

## Executive Summary

The **hybrid registration approach** eliminates all registration boilerplate from CTModels, CTDirect, and CTSolvers by moving registration responsibility to OptimalControl.jl, which uses generic functions provided by the Strategies module.

**Key Benefits**:

- ✅ **~160 lines removed** from CTModels/CTDirect/CTSolvers
- ✅ **~20 lines added** to OptimalControl.jl
- ✅ **Net reduction**: ~140 lines
- ✅ **Clearer separation**: Registration is where it's used (OptimalControl)
- ✅ **No boilerplate**: Strategy packages only define strategies + contract

---

## Core Principle

**Registration = ID → Type mapping for a family**

The essential need is:

1. **Unique IDs** within a family
2. **Lookup Type** from ID
3. **Construct instance** from ID + options

Everything else (option discovery, routing) comes from the **strategy contract**, not registration.

---

## Architecture

### 1. Strategy Packages (CTModels, CTDirect, CTSolvers)

**Only define strategies + contract** (no registration code):

```julia
# In CTModels/src/nlp/nlp_backends.jl

# ADNLPModeler - just the strategy definition
struct ADNLPModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end

# Contract implementation
symbol(::Type{<:ADNLPModeler}) = :adnlp
metadata(::Type{<:ADNLPModeler}) = StrategyMetadata((
    backend = OptionSpecification(
        type = Symbol,
        default = :optimized,
        description = "AD backend"
    ),
    # ... other options
))
package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"

# Constructor (part of contract)
ADNLPModeler(; kwargs...) = ADNLPModeler(build_strategy_options(ADNLPModeler; kwargs...))

# Same for ExaModeler
# NO registration boilerplate!
```

**What's removed** (~60 lines per package):

- ❌ `REGISTERED_MODELERS` constant
- ❌ `registered_modeler_types()` function
- ❌ `modeler_symbols()` function
- ❌ `_modeler_type_from_symbol()` function
- ❌ `build_modeler_from_symbol()` function

---

### 2. Strategies Module (CTModels)

**Provides generic registration functions**:

```julia
# In src/strategies/registration.jl

"""
Global registry mapping families to their strategies.
"""
const GLOBAL_REGISTRY = Dict{Type{<:AbstractStrategy}, Vector{Type}}()

"""
Register a family of strategies.

# Example
```julia
register_family!(AbstractOptimizationModeler, (ADNLPModeler, ExaModeler))
```

"""
function register_family!(family::Type{<:AbstractStrategy}, strategies::Tuple)
    # Validate uniqueness of IDs
    ids = [symbol(T) for T in strategies]
    if length(ids) != length(unique(ids))
        duplicates = [id for id in ids if count(==(id), ids) > 1]
        error("Duplicate IDs in family $family: $duplicates")
    end

    # Validate all strategies are subtypes of family
    for T in strategies
        if !(T <: family)
            error("Type $T is not a subtype of $family")
        end
    end
    
    # Register
    GLOBAL_REGISTRY[family] = collect(strategies)
end

"""
Get all registered strategies for a family.
"""
function get_strategies_for_family(family::Type{<:AbstractStrategy})
    if !haskey(GLOBAL_REGISTRY, family)
        error("Family $family not registered. Use register_family! first.")
    end
    return GLOBAL_REGISTRY[family]
end

"""
Get all IDs for a family.

# Example

```julia
strategy_ids(AbstractOptimizationModeler)  # => (:adnlp, :exa)
```

"""
function strategy_ids(family::Type{<:AbstractStrategy})
    strategies = get_strategies_for_family(family)
    return Tuple(symbol(T) for T in strategies)
end

"""
Lookup a strategy type from its ID within a family.

# Example

```julia
type_from_id(:adnlp, AbstractOptimizationModeler)  # => ADNLPModeler
```

"""
function type_from_id(id::Symbol, family::Type{<:AbstractStrategy})
    strategies = get_strategies_for_family(family)

    for T in strategies
        if symbol(T) === id
            return T
        end
    end
    
    # Not found - provide helpful error
    available = strategy_ids(family)
    error("Unknown ID :$id for family $family. Available: $available")
end

"""
Build a strategy instance from its ID and options.

# Example

```julia
modeler = build_strategy(:adnlp, AbstractOptimizationModeler; backend=:sparse)
```

"""
function build_strategy(
    id::Symbol,
    family::Type{<:AbstractStrategy};
    kwargs...
)
    T = type_from_id(id, family)
    return T(; kwargs...)
end

```

**Estimated lines**: ~80 (including docstrings)

---

### 3. OptimalControl.jl

**Creates the registry** using generic functions:

```julia
# In OptimalControl.jl/src/solve.jl or separate registration file

using CTModels.Strategies: register_family!, strategy_ids, build_strategy

# Import all strategy types
using CTModels: ADNLPModeler, ExaModeler, AbstractOptimizationModeler
using CTDirect: CollocationDiscretizer, AbstractOptimalControlDiscretizer
using CTSolvers: IpoptSolver, MadNLPSolver, KnitroSolver, MadNCLSolver, AbstractOptimizationSolver

# Register families (explicit and controlled)
register_family!(
    AbstractOptimalControlDiscretizer,
    (CollocationDiscretizer,)
)

register_family!(
    AbstractOptimizationModeler,
    (ADNLPModeler, ExaModeler)
)

register_family!(
    AbstractOptimizationSolver,
    (IpoptSolver, MadNLPSolver, KnitroSolver, MadNCLSolver)
)

# Now use generic functions instead of package-specific ones
function _get_discretizer_symbol(method::Tuple)
    allowed = strategy_ids(AbstractOptimalControlDiscretizer)
    return _get_unique_symbol(method, allowed, "discretizer")
end

function _build_discretizer_from_method(method::Tuple, options::NamedTuple)
    disc_id = _get_discretizer_symbol(method)
    return build_strategy(disc_id, AbstractOptimalControlDiscretizer; options...)
end

# Same pattern for modeler and solver
function _get_modeler_symbol(method::Tuple)
    allowed = strategy_ids(AbstractOptimizationModeler)
    return _get_unique_symbol(method, allowed, "modeler")
end

function _build_modeler_from_method(method::Tuple, options::NamedTuple)
    model_id = _get_modeler_symbol(method)
    return build_strategy(model_id, AbstractOptimizationModeler; options...)
end

function _get_solver_symbol(method::Tuple)
    allowed = strategy_ids(AbstractOptimizationSolver)
    return _get_unique_symbol(method, allowed, "solver")
end

function _build_solver_from_method(method::Tuple, options::NamedTuple)
    solver_id = _get_solver_symbol(method)
    return build_strategy(solver_id, AbstractOptimizationSolver; options...)
end

# For option discovery (uses type_from_id)
function _discretizer_options_keys(method::Tuple)
    disc_id = _get_discretizer_symbol(method)
    disc_type = type_from_id(disc_id, AbstractOptimalControlDiscretizer)
    keys = option_names(disc_type)
    return keys
end

# Same for modeler and solver
```

**Lines added**: ~20 (registration) + minor changes to existing functions

---

## Comparison: Before vs After

### Before (Current)

**CTModels** (lines 195-301 of nlp_backends.jl):

```julia
# ~107 lines of boilerplate
get_symbol(::Type{<:ADNLPModeler}) = :adnlp
get_symbol(::Type{<:ExaModeler}) = :exa
tool_package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
tool_package_name(::Type{<:ExaModeler}) = "ExaModels"
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)
registered_modeler_types() = REGISTERED_MODELERS
modeler_symbols() = Tuple(get_symbol(T) for T in REGISTERED_MODELERS)
function _modeler_type_from_symbol(sym::Symbol)
    # ... 8 lines ...
end
function build_modeler_from_symbol(sym::Symbol; kwargs...)
    # ... 3 lines ...
end
```

**CTDirect**: ~50 lines (same pattern)  
**CTSolvers**: ~50 lines (same pattern)  
**Total boilerplate**: ~207 lines

### After (Hybrid)

**CTModels**:

```julia
# Just strategies + contract (no registration)
struct ADNLPModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end

symbol(::Type{<:ADNLPModeler}) = :adnlp
metadata(::Type{<:ADNLPModeler}) = StrategyMetadata(...)
package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
ADNLPModeler(; kwargs...) = ADNLPModeler(build_strategy_options(ADNLPModeler; kwargs...))

# Same for ExaModeler
```

**Strategies module**: ~80 lines (generic functions, reusable)

**OptimalControl**: ~20 lines (registration calls)

**Net change**: -207 + 80 + 20 = **-107 lines** (plus better organization)

---

## Benefits

### 1. Eliminates Boilerplate

Each strategy package only defines:

- ✅ Strategy types
- ✅ Contract implementation (`symbol`, `metadata`, `package_name`)
- ✅ Constructor

No registration code needed.

### 2. Centralized Registration

Registration happens where it's used (OptimalControl), making it clear:

- Which strategies are available
- How they're organized into families
- What combinations are valid

### 3. Generic and Reusable

The Strategies module provides generic functions that work for **any** family:

- `register_family!(family, strategies)`
- `strategy_ids(family)`
- `type_from_id(id, family)`
- `build_strategy(id, family; kwargs...)`

### 4. Validation at Registration Time

```julia
register_family!(AbstractOptimizationModeler, (ADNLPModeler, ExaModeler))
# Validates:
# - IDs are unique within family
# - All types are subtypes of family
# - All types implement symbol()
```

### 5. Easier to Extend

To add a new strategy:

**Before**:

1. Define strategy in CTModels
2. Add to `REGISTERED_MODELERS`
3. Update `modeler_symbols()` (automatic but implicit)

**After**:

1. Define strategy in CTModels (just type + contract)
2. Add to registration in OptimalControl

Clearer and more explicit.

---

## Migration Path

### Phase 1: Implement in Strategies Module

Add to `src/strategies/registration.jl`:

- `GLOBAL_REGISTRY`
- `register_family!`
- `get_strategies_for_family`
- `strategy_ids`
- `type_from_id`
- `build_strategy`

### Phase 2: Update OptimalControl

Add registration calls:

```julia
register_family!(AbstractOptimalControlDiscretizer, (...))
register_family!(AbstractOptimizationModeler, (...))
register_family!(AbstractOptimizationSolver, (...))
```

Update helper functions to use generic functions.

### Phase 3: Remove Boilerplate

In CTModels, CTDirect, CTSolvers:

- Remove `REGISTERED_*` constants
- Remove `*_symbols()` functions
- Remove `_*_type_from_symbol()` functions
- Remove `build_*_from_symbol()` functions

Keep only strategy definitions + contract.

### Phase 4: Test

Verify all tests pass in:

- CTModels
- CTDirect
- CTSolvers
- OptimalControl

---

## Contract Requirements

For this to work, all strategies **must** have a keyword-only constructor:

```julia
# Required constructor signature
MyStrategy(; kwargs...) = MyStrategy(build_strategy_options(MyStrategy; kwargs...))
```

This is now part of the **strategy contract**:

1. ✅ Type-level: `symbol()`, `metadata()`, `package_name()` (optional)
2. ✅ Instance-level: `options()`
3. ✅ **Constructor**: `T(; kwargs...)`

---

## Example: Complete Flow

### 1. User calls solve

```julia
solve(ocp, :collocation, :adnlp, :ipopt; grid_size=100, max_iter=1000)
```

### 2. OptimalControl extracts IDs

```julia
disc_id = :collocation   # from strategy_ids(AbstractOptimalControlDiscretizer)
model_id = :adnlp        # from strategy_ids(AbstractOptimizationModeler)
solver_id = :ipopt       # from strategy_ids(AbstractOptimizationSolver)
```

### 3. OptimalControl routes options

```julia
# Discover option keys for each type
disc_type = type_from_id(:collocation, AbstractOptimalControlDiscretizer)
disc_keys = option_names(disc_type)  # => (:grid_size, :scheme, ...)

# Route grid_size → discretizer, max_iter → solver
```

### 4. OptimalControl builds strategies

```julia
discretizer = build_strategy(:collocation, AbstractOptimalControlDiscretizer; grid_size=100)
modeler = build_strategy(:adnlp, AbstractOptimizationModeler)
solver = build_strategy(:ipopt, AbstractOptimizationSolver; max_iter=1000)
```

### 5. Internally

```julia
# build_strategy(:adnlp, AbstractOptimizationModeler)
# 1. type_from_id(:adnlp, AbstractOptimizationModeler) => ADNLPModeler
# 2. ADNLPModeler(; kwargs...)
# 3. Returns ADNLPModeler instance
```

---

## Open Questions

### Q1: Should registration be mandatory?

**Current proposal**: Yes, families must be registered before use.

**Alternative**: Lazy registration on first use?

**Recommendation**: **Mandatory**. Explicit is better than implicit.

### Q2: Where should registration happen in OptimalControl?

**Option A**: In `src/solve.jl` (where it's used)  
**Option B**: Separate `src/registration.jl` file  

**Recommendation**: **Option B**. Keeps solve.jl focused on solving logic.

### Q3: Should we provide a macro for registration?

```julia
@register_strategies begin
    AbstractOptimalControlDiscretizer => (CollocationDiscretizer,)
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler)
    AbstractOptimizationSolver => (IpoptSolver, MadNLPSolver, ...)
end
```

**Recommendation**: **Not needed**. The explicit function calls are clear enough.

---

## Summary

The hybrid approach achieves the best of both worlds:

✅ **Strategy packages**: Simple, focused on defining strategies  
✅ **Strategies module**: Generic, reusable registration functions  
✅ **OptimalControl**: Explicit registration, clear control  
✅ **Net result**: Less code, better organization, clearer responsibilities

**Next step**: Implement generic functions in Strategies module.
