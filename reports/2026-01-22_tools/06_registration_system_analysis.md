# Registration System - Deep Analysis

**Date**: 2026-01-22  
**Status**: Analysis - **SUPERSEDED by 07_registration_final_design.md**

> [!IMPORTANT]
> This document contains the initial analysis of the registration system.
> The **final design** is documented in `07_registration_final_design.md` which describes
> the validated **hybrid approach** where OptimalControl.jl creates the registry.

---

## Executive Summary

The registration system currently requires **significant boilerplate** in each package (CTModels, CTDirect, CTSolvers). This analysis examines:
1. What each registration function does
2. How OptimalControl.jl uses them
3. Opportunities for automation and simplification

**Key Finding**: Most registration code can be **automated** or **centralized** in the Strategies module, reducing boilerplate by ~80%.

---

## 1. Current Registration Pattern

### 1.1 What Gets Registered (CTModels Example)

```julia
# Lines 206-233: Symbol and package name for each strategy
get_symbol(::Type{<:ADNLPModeler}) = :adnlp
get_symbol(::Type{<:ExaModeler}) = :exa
tool_package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
tool_package_name(::Type{<:ExaModeler}) = "ExaModels"

# Line 240: List of registered types
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)

# Line 247: Accessor for the list
registered_modeler_types() = REGISTERED_MODELERS

# Line 256: Get all symbols
modeler_symbols() = Tuple(get_symbol(T) for T in REGISTERED_MODELERS)

# Lines 265-273: Lookup type from symbol
function _modeler_type_from_symbol(sym::Symbol)
    for T in REGISTERED_MODELERS
        if get_symbol(T) === sym
            return T
        end
    end
    throw(CTBase.IncorrectArgument("Unknown symbol $sym"))
end

# Lines 297-300: Build instance from symbol
function build_modeler_from_symbol(sym::Symbol; kwargs...)
    T = _modeler_type_from_symbol(sym)
    return T(; kwargs...)
end
```

**Same pattern in CTSolvers** (lines 39-58 of backends_types.jl):
- `solver_symbols()`
- `_solver_type_from_symbol(sym)`
- `build_solver_from_symbol(sym; kwargs...)`

**Same pattern in CTDirect** (presumably):
- `discretizer_symbols()`
- `_discretizer_type_from_symbol(sym)`
- `build_discretizer_from_symbol(sym; kwargs...)`

---

## 2. How OptimalControl.jl Uses Registration

### 2.1 Symbol Extraction

```julia
# Get available symbols for each category
disc_sym = _get_discretizer_symbol(method)     # Uses CTDirect.discretizer_symbols()
model_sym = _get_modeler_symbol(method)        # Uses CTModels.modeler_symbols()
solver_sym = _get_solver_symbol(method)        # Uses CTSolvers.solver_symbols()
```

**Purpose**: Extract the relevant symbol from a method tuple like `(:collocation, :adnlp, :ipopt)`.

### 2.2 Option Keys Discovery

```julia
# Get option keys for routing
disc_keys = _discretizer_options_keys(method)
# Internally:
disc_type = CTDirect._discretizer_type_from_symbol(disc_sym)
keys = CTModels.options_keys(disc_type)
```

**Purpose**: Determine which options belong to which strategy for automatic routing.

**Example**: If user writes `solve(ocp, :collocation, :adnlp, :ipopt; grid_size=100, max_iter=1000)`:
- `grid_size` → belongs to discretizer only → auto-route to discretizer
- `max_iter` → belongs to solver only → auto-route to solver
- If an option belongs to multiple → require disambiguation: `backend=(value, :modeler)`

### 2.3 Strategy Construction

```julia
# Build strategies from symbols + options
discretizer = CTDirect.build_discretizer_from_symbol(:collocation; grid_size=100)
modeler = CTModels.build_modeler_from_symbol(:adnlp)
solver = CTSolvers.build_solver_from_symbol(:ipopt; max_iter=1000)
```

**Purpose**: Construct strategy instances from symbols and routed options.

### 2.4 Display

```julia
# Get package names for display
model_pkg = CTModels.tool_package_name(modeler)
solver_pkg = CTModels.tool_package_name(solver)
```

**Purpose**: Show user-friendly package names in output.

---

## 3. Analysis of Each Registration Function

### 3.1 `REGISTERED_MODELERS` Constant

**Current**:
```julia
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)
```

**Purpose**: Explicit list of strategies in this family.

**Question**: Can we auto-discover this from the type hierarchy?

**Answer**: **Partially**. We could use `subtypes(AbstractOptimizationModeler)`, BUT:
- ❌ Requires all types to be defined before registration
- ❌ Doesn't work across packages (CTDirect can't see CTSolvers types)
- ❌ Includes abstract intermediate types
- ✅ Explicit list is clearer and more controlled

**Recommendation**: **Keep explicit registration**, but simplify with macro.

---

### 3.2 `modeler_symbols()` Function

**Current**:
```julia
modeler_symbols() = Tuple(get_symbol(T) for T in REGISTERED_MODELERS)
```

**Purpose**: Return `(:adnlp, :exa)` for OptimalControl.jl to validate method descriptions.

**Question**: Is this needed or can we use a generic function?

**Answer**: **Needed**, but can be auto-generated from registration.

**Recommendation**: **Auto-generate** via macro.

---

### 3.3 `_modeler_type_from_symbol(sym)` Function

**Current**:
```julia
function _modeler_type_from_symbol(sym::Symbol)
    for T in REGISTERED_MODELERS
        if get_symbol(T) === sym
            return T
        end
    end
    throw(CTBase.IncorrectArgument(...))
end
```

**Purpose**: Lookup `ADNLPModeler` from `:adnlp`.

**Question**: Can we have ONE generic function instead of one per package?

**Answer**: **Yes!** We can create a generic function in Strategies module:

```julia
# In Strategies module
function type_from_symbol(registry::Tuple, sym::Symbol)
    for T in registry
        if symbol(T) === sym
            return T
        end
    end
    throw(CTBase.IncorrectArgument("Unknown symbol $sym in registry"))
end

# In CTModels
_modeler_type_from_symbol(sym) = Strategies.type_from_symbol(REGISTERED_MODELERS, sym)
```

**Recommendation**: **Provide generic helper** in Strategies, auto-generate wrapper via macro.

---

### 3.4 `build_modeler_from_symbol(sym; kwargs...)` Function

**Current**:
```julia
function build_modeler_from_symbol(sym::Symbol; kwargs...)
    T = _modeler_type_from_symbol(sym)
    return T(; kwargs...)
end
```

**Purpose**: Construct modeler from symbol + options.

**Question**: Can we have ONE generic function?

**Answer**: **Yes!** Same pattern:

```julia
# In Strategies module
function build_from_symbol(registry::Tuple, sym::Symbol; kwargs...)
    T = type_from_symbol(registry, sym)
    return T(; kwargs...)
end

# In CTModels
build_modeler_from_symbol(sym; kwargs...) = 
    Strategies.build_from_symbol(REGISTERED_MODELERS, sym; kwargs...)
```

**Recommendation**: **Provide generic helper**, auto-generate wrapper via macro.

---

## 4. Proposed Simplifications

### 4.1 Centralize Generic Functions in Strategies Module

**Provide in `src/strategies/registration.jl`**:

```julia
"""
Get all symbols from a registry.
"""
function symbols_from_registry(registry::Tuple)
    return Tuple(symbol(T) for T in registry)
end

"""
Lookup a strategy type from its symbol in a registry.
"""
function type_from_symbol(registry::Tuple, sym::Symbol)
    for T in registry
        if symbol(T) === sym
            return T
        end
    end
    syms = symbols_from_registry(registry)
    throw(CTBase.IncorrectArgument("Unknown symbol $sym. Available: $syms"))
end

"""
Build a strategy instance from its symbol and options.
"""
function build_from_symbol(registry::Tuple, sym::Symbol; kwargs...)
    T = type_from_symbol(registry, sym)
    return T(; kwargs...)
end
```

**Benefits**:
- ✅ Generic, reusable across all packages
- ✅ Consistent error messages
- ✅ Less code duplication

---

### 4.2 Macro for Registration Boilerplate

**Provide `@register_strategies` macro**:

```julia
@register_strategies modeler begin
    ADNLPModeler => :adnlp
    ExaModeler => :exa
end
```

**Expands to**:

```julia
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)

registered_modeler_types() = REGISTERED_MODELERS

modeler_symbols() = Strategies.symbols_from_registry(REGISTERED_MODELERS)

function _modeler_type_from_symbol(sym::Symbol)
    return Strategies.type_from_symbol(REGISTERED_MODELERS, sym)
end

function build_modeler_from_symbol(sym::Symbol; kwargs...)
    return Strategies.build_from_symbol(REGISTERED_MODELERS, sym; kwargs...)
end
```

**Benefits**:
- ✅ **Reduces boilerplate by ~80%**
- ✅ Consistent naming across packages
- ✅ Less error-prone

---

### 4.3 Symbol Uniqueness Validation

**Question**: Should we verify symbols are unique within a registry?

**Answer**: **Yes**, at registration time.

**Implementation**:

```julia
macro register_strategies(category, strategies_block)
    # ... parse strategies_block ...
    
    # Check for duplicate symbols
    symbols_seen = Set{Symbol}()
    for (type, sym) in type_symbol_pairs
        if sym in symbols_seen
            error("Duplicate symbol $sym in registration for $category")
        end
        push!(symbols_seen, sym)
    end
    
    # ... generate code ...
end
```

**Benefits**:
- ✅ Catches errors at compile time
- ✅ Prevents runtime confusion

---

### 4.4 Rename `symbol` to `id`?

**Question**: Should we use `id` instead of `symbol` for clarity?

**Analysis**:
- **Pro `id`**: More general, clearer intent (identifier)
- **Pro `symbol`**: Julia convention, already used everywhere
- **Current usage**: `:adnlp`, `:ipopt` are literally Julia `Symbol`s

**Recommendation**: **Keep `symbol`**. It's accurate and conventional in Julia.

---

## 5. Cross-Package Registration

**Question**: Should OptimalControl.jl maintain a central registry of all families?

**Current approach**: Each package exports its own functions:
- `CTDirect.discretizer_symbols()`
- `CTModels.modeler_symbols()`
- `CTSolvers.solver_symbols()`

**Alternative**: Central registry in OptimalControl:

```julia
# In OptimalControl.jl
const STRATEGY_FAMILIES = (
    :discretizer => CTDirect.REGISTERED_DISCRETIZERS,
    :modeler => CTModels.REGISTERED_MODELERS,
    :solver => CTSolvers.REGISTERED_SOLVERS,
)
```

**Analysis**:
- ❌ Creates tight coupling
- ❌ OptimalControl must know about all packages
- ❌ Harder to extend with new packages
- ✅ Current approach is more modular

**Recommendation**: **Keep current approach**. Each package manages its own registry.

---

## 6. Auto-Discovery from Type Hierarchy

**Question**: Can we discover registered strategies from `subtypes(AbstractOptimizationModeler)`?

**Example**:

```julia
# Hypothetical auto-discovery
function discover_strategies(::Type{T}) where {T<:AbstractStrategy}
    return Tuple(subtypes(T))
end
```

**Problems**:
1. **Includes abstract types**: `subtypes(AbstractOptimizationModeler)` might include intermediate abstract types
2. **Cross-package**: CTDirect can't see CTSolvers types
3. **Compilation order**: Types must be defined before discovery
4. **No control**: Can't exclude experimental/internal types

**Recommendation**: **Don't auto-discover**. Explicit registration is clearer and more controlled.

---

## 7. Simplified Registration API

### 7.1 What Developers Write (Current)

**In CTModels** (~107 lines of boilerplate):

```julia
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

### 7.2 What Developers Write (Proposed)

**In CTModels** (~10 lines):

```julia
using CTModels.Strategies: @register_strategies

@register_strategies modeler begin
    ADNLPModeler => :adnlp
    ExaModeler => :exa
end
```

**Reduction**: **~90% less code**

---

## 8. What OptimalControl.jl Needs

### 8.1 Current Usage

```julia
# 1. Get symbols for validation
CTDirect.discretizer_symbols()   # => (:collocation,)
CTModels.modeler_symbols()        # => (:adnlp, :exa)
CTSolvers.solver_symbols()        # => (:ipopt, :madnlp, :knitro, :madncl)

# 2. Get option keys for routing
disc_type = CTDirect._discretizer_type_from_symbol(:collocation)
CTModels.options_keys(disc_type)  # => (:grid_size, :scheme, ...)

# 3. Build strategies
CTDirect.build_discretizer_from_symbol(:collocation; grid_size=100)
CTModels.build_modeler_from_symbol(:adnlp)
CTSolvers.build_solver_from_symbol(:ipopt; max_iter=1000)

# 4. Display
CTModels.tool_package_name(modeler)
```

### 8.2 Proposed (No Change Needed)

The macro generates the same API, so **OptimalControl.jl doesn't change**.

---

## 9. Final Recommendations

### 9.1 Implement in Strategies Module

1. ✅ **Generic helpers**:
   - `symbols_from_registry(registry)`
   - `type_from_symbol(registry, sym)`
   - `build_from_symbol(registry, sym; kwargs...)`

2. ✅ **`@register_strategies` macro**:
   - Generates `REGISTERED_<CATEGORY>S` constant
   - Generates `<category>_symbols()` function
   - Generates `_<category>_type_from_symbol(sym)` function
   - Generates `build_<category>_from_symbol(sym; kwargs...)` function
   - Validates symbol uniqueness at compile time

### 9.2 Migration Path

**Phase 1**: Implement in Strategies module
- Add generic helpers
- Add `@register_strategies` macro
- Test with CTModels

**Phase 2**: Migrate packages
- CTModels: Replace boilerplate with macro
- CTDirect: Replace boilerplate with macro
- CTSolvers: Replace boilerplate with macro

**Phase 3**: Verify
- All tests pass
- OptimalControl.jl works unchanged

---

## 10. Example: Complete Registration

### Before (CTModels)

```julia
# 107 lines of boilerplate
get_symbol(::Type{<:ADNLPModeler}) = :adnlp
get_symbol(::Type{<:ExaModeler}) = :exa
tool_package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
tool_package_name(::Type{<:ExaModeler}) = "ExaModels"
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)
registered_modeler_types() = REGISTERED_MODELERS
modeler_symbols() = Tuple(get_symbol(T) for T in REGISTERED_MODELERS)
function _modeler_type_from_symbol(sym::Symbol)
    for T in REGISTERED_MODELERS
        if get_symbol(T) === sym
            return T
        end
    end
    msg = "Unknown NLP model symbol $(sym). Supported symbols: $(modeler_symbols())."
    throw(CTBase.IncorrectArgument(msg))
end
function build_modeler_from_symbol(sym::Symbol; kwargs...)
    T = _modeler_type_from_symbol(sym)
    return T(; kwargs...)
end
```

### After (CTModels)

```julia
# 10 lines total
using CTModels.Strategies: @register_strategies

@register_strategies modeler begin
    ADNLPModeler => :adnlp
    ExaModeler => :exa
end
```

**Note**: `symbol()` and `package_name()` are still implemented separately as part of the strategy contract:

```julia
symbol(::Type{<:ADNLPModeler}) = :adnlp
symbol(::Type{<:ExaModeler}) = :exa
package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
package_name(::Type{<:ExaModeler}) = "ExaModels"
```

---

## 11. Open Questions

### Q1: Should the macro also generate `symbol()` and `package_name()`?

**Option A**: Macro generates everything

```julia
@register_strategies modeler begin
    ADNLPModeler => :adnlp => "ADNLPModels"
    ExaModeler => :exa => "ExaModels"
end
```

**Option B**: Keep contract methods separate (current proposal)

**Recommendation**: **Option B**. Contract methods are part of the strategy definition, not registration.

### Q2: Should we validate that registered types actually implement the contract?

**Implementation**:

```julia
macro register_strategies(category, strategies_block)
    # ... parse ...
    
    # Generate validation at module load time
    quote
        # ... registration code ...
        
        # Validate contract
        for T in $registry_tuple
            Strategies.validate_strategy_contract(T)
        end
    end
end
```

**Recommendation**: **Yes**, but make it optional (debug mode).

---

## Appendix: Macro Implementation Sketch

```julia
macro register_strategies(category_name, strategies_block)
    # Parse strategies_block to extract Type => :symbol pairs
    type_symbol_pairs = parse_strategies_block(strategies_block)
    
    # Validate uniqueness
    validate_symbol_uniqueness(type_symbol_pairs)
    
    # Generate names
    category_str = string(category_name)
    category_upper = uppercase(category_str)
    const_name = Symbol("REGISTERED_$(category_upper)S")
    types_func = Symbol("registered_$(category_str)_types")
    symbols_func = Symbol("$(category_str)_symbols")
    lookup_func = Symbol("_$(category_str)_type_from_symbol")
    build_func = Symbol("build_$(category_str)_from_symbol")
    
    # Extract types and symbols
    types = [pair[1] for pair in type_symbol_pairs]
    
    # Generate code
    quote
        const $(esc(const_name)) = ($(esc.(types)...),)
        
        $(esc(types_func))() = $(esc(const_name))
        
        $(esc(symbols_func))() = Strategies.symbols_from_registry($(esc(const_name)))
        
        function $(esc(lookup_func))(sym::Symbol)
            return Strategies.type_from_symbol($(esc(const_name)), sym)
        end
        
        function $(esc(build_func))(sym::Symbol; kwargs...)
            return Strategies.build_from_symbol($(esc(const_name)), sym; kwargs...)
        end
    end
end
```
