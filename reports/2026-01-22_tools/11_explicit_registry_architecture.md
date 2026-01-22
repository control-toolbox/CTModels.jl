# Explicit Registry Architecture - Final Design

**Date**: 2026-01-22  
**Status**: Final - Architecture Decision

> [!IMPORTANT]
> **Major Architecture Decision**: Use **explicit registry** instead of global mutable state.
> Registry is created once and passed explicitly to functions that need it.

---

## Decision: Explicit Registry Passing

### Rationale

**Chosen**: Explicit registry (passed as argument)  
**Rejected**: Global mutable registry

**Why**:
- ✅ **Explicit dependencies**: Clear which functions need the registry
- ✅ **Testability**: Easy to create different registries for testing
- ✅ **No side-effects**: Pure functions, no global mutable state
- ✅ **Thread-safe**: No shared mutable state
- ✅ **Composability**: Can have multiple registries for different contexts

**Trade-offs**:
- ⚠️ More verbose (must pass registry to functions)
- ⚠️ Registry must be stored somewhere (module constant)

---

## Registry Structure

### Type Definition

```julia
struct StrategyRegistry
    families::Dict{Type{<:AbstractStrategy}, Vector{Type}}
end
```

### Creation

```julia
"""
Create a strategy registry from family => strategies pairs.

# Example
```julia
registry = create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler),
    AbstractOptimizationSolver => (IpoptSolver, MadNLPSolver),
)
```
"""
function create_registry(pairs::Pair{Type{<:AbstractStrategy}, <:Tuple}...)
    families = Dict{Type{<:AbstractStrategy}, Vector{Type}}()
    
    for (family, strategies) in pairs
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
        
        families[family] = collect(strategies)
    end
    
    return StrategyRegistry(families)
end
```

---

## Updated Function Signatures

All functions that need the registry now take it as an explicit argument.

### 1. `strategy_ids(family, registry)`

```julia
"""
Get all strategy IDs for a family from the registry.
"""
function strategy_ids(family::Type{<:AbstractStrategy}, registry::StrategyRegistry)
    if !haskey(registry.families, family)
        error("Family $family not found in registry")
    end
    strategies = registry.families[family]
    return Tuple(symbol(T) for T in strategies)
end
```

### 2. `type_from_id(id, family, registry)`

```julia
"""
Lookup a strategy type from its ID within a family.
"""
function type_from_id(
    id::Symbol,
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    if !haskey(registry.families, family)
        error("Family $family not found in registry")
    end
    
    for T in registry.families[family]
        if symbol(T) === id
            return T
        end
    end
    
    available = strategy_ids(family, registry)
    error("Unknown ID :$id for family $family. Available: $available")
end
```

### 3. `build_strategy(id, family, registry; kwargs...)`

```julia
"""
Build a strategy instance from its ID and options.
"""
function build_strategy(
    id::Symbol,
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry;
    kwargs...
)
    T = type_from_id(id, family, registry)
    return T(; kwargs...)
end
```

### 4. `extract_id_from_method(method, family, registry)`

```julia
"""
Extract the ID for a specific family from a method tuple.
"""
function extract_id_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    allowed = strategy_ids(family, registry)
    hits = Symbol[]
    
    for s in method
        if s in allowed
            push!(hits, s)
        end
    end
    
    if length(hits) == 1
        return hits[1]
    elseif isempty(hits)
        error("No ID for family $family found in method $method. Available: $allowed")
    else
        error("Multiple IDs $hits for family $family found in method $method")
    end
end
```

### 5. `option_names_from_method(method, family, registry)`

```julia
"""
Get option names for a family from a method tuple.
"""
function option_names_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    id = extract_id_from_method(method, family, registry)
    strategy_type = type_from_id(id, family, registry)
    return option_names(strategy_type)
end
```

### 6. `build_strategy_from_method(method, family, registry; kwargs...)`

```julia
"""
Build a strategy from a method tuple and options.
"""
function build_strategy_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry;
    kwargs...
)
    id = extract_id_from_method(method, family, registry)
    return build_strategy(id, family, registry; kwargs...)
end
```

### 7. `route_options(method, families, kwargs, registry; source_mode)`

```julia
"""
Route options to strategies with strategy-based disambiguation.

# Arguments
- `method`: Complete method tuple
- `families`: NamedTuple mapping family names to types
- `kwargs`: User options to route
- `registry`: Strategy registry
- `source_mode`: `:description` or `:explicit`
"""
function route_options(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    kwargs::NamedTuple,
    registry::StrategyRegistry;
    source_mode::Symbol=:description
)
    # Build strategy-to-family mapping
    strategy_to_family = Dict{Symbol,Symbol}()
    for (family_name, family_type) in pairs(families)
        id = extract_id_from_method(method, family_type, registry)
        strategy_to_family[id] = family_name
    end
    
    # Build option ownership map
    option_owners = Dict{Symbol, Set{Symbol}}()
    for (family_name, family_type) in pairs(families)
        keys = option_names_from_method(method, family_type, registry)
        for key in keys
            if !haskey(option_owners, key)
                option_owners[key] = Set{Symbol}()
            end
            push!(option_owners[key], family_name)
        end
    end
    
    # Route each option (same logic as before)
    # ...
end
```

---

## Usage in OptimalControl.jl

### Create Registry Once

```julia
# In OptimalControl.jl module initialization

const OCP_REGISTRY = create_registry(
    CTDirect.AbstractOptimalControlDiscretizer => (CTDirect.CollocationDiscretizer,),
    CTModels.AbstractOptimizationModeler => (CTModels.ADNLPModeler, CTModels.ExaModeler),
    CTSolvers.AbstractOptimizationSolver => (
        CTSolvers.IpoptSolver,
        CTSolvers.MadNLPSolver,
        CTSolvers.KnitroSolver,
        CTSolvers.MadNCLSolver
    ),
)
```

### Pass to Functions

```julia
function _solve_from_description(ocp, method, parsed)
    # Pass registry explicitly
    routed = route_options(
        method,
        STRATEGY_FAMILIES,
        parsed.other_kwargs,
        OCP_REGISTRY;  # ← Explicit registry
        source_mode=:description
    )
    
    # Pass registry explicitly
    discretizer = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.discretizer,
        OCP_REGISTRY;  # ← Explicit registry
        routed.discretizer...
    )
    
    modeler = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.modeler,
        OCP_REGISTRY;  # ← Explicit registry
        routed.modeler...
    )
    
    solver = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.solver,
        OCP_REGISTRY;  # ← Explicit registry
        routed.solver...
    )
    
    # ... solve
end
```

---

## Impact on Strategies Module

### What Changes

**File**: `src/strategies/registration.jl`

**Remove**:
- ❌ `GLOBAL_REGISTRY` constant
- ❌ `register_family!()` function
- ❌ `get_strategies_for_family()` function

**Add**:
- ✅ `StrategyRegistry` struct
- ✅ `create_registry()` function

**Update** (add `registry` parameter):
- ✅ `strategy_ids(family, registry)`
- ✅ `type_from_id(id, family, registry)`
- ✅ `build_strategy(id, family, registry; kwargs...)`
- ✅ `extract_id_from_method(method, family, registry)`
- ✅ `option_names_from_method(method, family, registry)`
- ✅ `build_strategy_from_method(method, family, registry; kwargs...)`
- ✅ `route_options(method, families, kwargs, registry; source_mode)`

---

## Impact on OptimalControl.jl

### What Changes

**Lines changed**: ~7 locations where registry is passed

**Before**:
```julia
routed = route_options(method, STRATEGY_FAMILIES, kwargs)
```

**After**:
```julia
routed = route_options(method, STRATEGY_FAMILIES, kwargs, OCP_REGISTRY)
```

**Net change**: +1 argument per call, +5 lines for registry creation

---

## Benefits Summary

1. ✅ **Explicit dependencies**: Functions clearly declare they need the registry
2. ✅ **Testability**: Easy to create test registries with different strategies
3. ✅ **No global state**: Pure functions, easier to reason about
4. ✅ **Thread-safe**: No shared mutable state
5. ✅ **Flexibility**: Can have multiple registries (e.g., for different problem types)

---

## Migration Checklist

- [ ] Update `src/strategies/registration.jl`:
  - [ ] Add `StrategyRegistry` struct
  - [ ] Add `create_registry()` function
  - [ ] Remove `GLOBAL_REGISTRY`
  - [ ] Remove `register_family!()`
  - [ ] Add `registry` parameter to all functions

- [ ] Update documentation:
  - [ ] `07_registration_final_design.md`
  - [ ] `09_method_based_functions_simplification.md`
  - [ ] `10_option_routing_complete_analysis.md`

- [ ] Update `solve_simplified.jl`:
  - [ ] Replace `register_family!()` calls with `create_registry()`
  - [ ] Pass `OCP_REGISTRY` to all functions

- [ ] Update `implementation_plan.md` with explicit registry approach
