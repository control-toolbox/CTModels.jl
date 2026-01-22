# Method-Based Functions - Simplification Analysis

**Date**: 2026-01-22  
**Status**: Analysis - Proposing Simplifications for OptimalControl.jl

---

## Executive Summary

OptimalControl.jl contains many helper functions that operate on "method" tuples (e.g., `(:collocation, :adnlp, :ipopt)`). Most of these can be **generalized and moved** to the Strategies module, reducing boilerplate in OptimalControl.

**Key Finding**: ~200 lines of OptimalControl code can be replaced with ~50 lines using generic Strategies functions.

---

## Current Method-Based Functions

### 1. Symbol Extraction (Lines 49-71)

**Current** (repeated 3 times for discretizer/modeler/solver):

```julia
function _get_unique_symbol(method::Tuple, allowed::Tuple, tool_name::String)
    hits = Symbol[]
    for s in method
        if s in allowed
            push!(hits, s)
        end
    end
    if length(hits) == 1
        return hits[1]
    elseif isempty(hits)
        error("No $tool_name symbol from $allowed found in method $method.")
    else
        error("Multiple $tool_name symbols $hits found in method $method")
    end
end

_get_discretizer_symbol(method) = _get_unique_symbol(method, CTDirect.discretizer_symbols(), "discretizer")
_get_modeler_symbol(method) = _get_unique_symbol(method, CTModels.modeler_symbols(), "NLP model")
_get_solver_symbol(method) = _get_unique_symbol(method, CTSolvers.solver_symbols(), "solver")
```

**Purpose**: Extract the relevant ID from a method tuple for a specific family.

**Can be generalized**: ✅ Yes

---

### 2. Option Keys Discovery (Lines 78-84, 107-113, 133-139)

**Current** (repeated 3 times):

```julia
function _discretizer_options_keys(method::Tuple)
    disc_sym = _get_discretizer_symbol(method)
    disc_type = CTDirect._discretizer_type_from_symbol(disc_sym)
    keys = CTModels.options_keys(disc_type)
    keys === missing && return ()
    return keys
end

# Same for _modeler_options_keys and _solver_options_keys
```

**Purpose**: Get option keys for a family given a method tuple.

**Can be generalized**: ✅ Yes

---

### 3. Strategy Construction from Method (Lines 73-76, 115-118, 128-131)

**Current** (repeated 3 times):

```julia
function _build_discretizer_from_method(method::Tuple, options::NamedTuple)
    disc_sym = _get_discretizer_symbol(method)
    return CTDirect.build_discretizer_from_symbol(disc_sym; options...)
end

# Same for _build_modeler_from_method and _build_solver_from_method
```

**Purpose**: Build a strategy from a method tuple + options.

**Can be generalized**: ✅ Yes

---

### 4. Option Routing (Lines 558-615)

**Current**:

```julia
function _split_kwargs_for_description(method::Tuple, parsed)
    disc_keys = Set(_discretizer_options_keys(method))
    model_keys = Set(_modeler_options_keys(method))
    solver_keys = Set(_solver_options_keys(method))
    
    # Route each option to the right family
    for (k, raw) in pairs(parsed.other_kwargs)
        owners = Symbol[]
        if k in disc_keys
            push!(owners, :discretizer)
        end
        if k in model_keys
            push!(owners, :modeler)
        end
        if k in solver_keys
            push!(owners, :solver)
        end
        
        value, tool = _route_option_for_description(k, raw, owners, :description)
        # ... route to appropriate NamedTuple
    end
end
```

**Purpose**: Route options to the correct family based on option keys.

**Can be generalized**: ⚠️ Partially (needs family registry)

---

## Proposed Generalization

### In Strategies Module (registration.jl)

Add method-based helper functions:

````julia
"""
Extract the ID for a specific family from a method tuple.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
id = extract_id_from_method(method, AbstractOptimizationModeler, registry)
# => :adnlp
```
"""
function extract_id_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry  # ← Explicit registry
)
    allowed = strategy_ids(family)
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
````

````julia
"""
Get option names for a family from a method tuple.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
keys = option_names_from_method(method, AbstractOptimizationModeler, registry)
# => (:backend, :show_time)
```
"""
function option_names_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry  # ← Explicit registry
)
    id = extract_id_from_method(method, family)
    strategy_type = type_from_id(id, family)
    return option_names(strategy_type)
end
````

````julia
"""
Build a strategy from a method tuple and options.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
modeler = build_strategy_from_method(method, AbstractOptimizationModeler, registry; backend=:sparse)
# => ADNLPModeler(backend=:sparse)
```
"""
function build_strategy_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry;  # ← Explicit registry
    kwargs...
)
    id = extract_id_from_method(method, family)
    return build_strategy(id, family; kwargs...)
end
````

**Estimated lines**: ~60 (including docstrings)

---

### In OptimalControl.jl (Simplified)

**Before** (~200 lines):

```julia
# 3 × _get_*_symbol functions
# 3 × _*_options_keys functions
# 3 × _build_*_from_method functions
# + _get_unique_symbol helper
```

**After** (~50 lines):

```julia
using CTModels.Strategies: extract_id_from_method, option_names_from_method, build_strategy_from_method

# Define family mapping (once)
const STRATEGY_FAMILIES = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver,
)

# Option routing (simplified)
function _split_kwargs_for_description(method::Tuple, parsed)
    # Get option keys for each family
    disc_keys = Set(option_names_from_method(method, STRATEGY_FAMILIES.discretizer))
    model_keys = Set(option_names_from_method(method, STRATEGY_FAMILIES.modeler))
    solver_keys = Set(option_names_from_method(method, STRATEGY_FAMILIES.solver))
    
    # Route options (same logic as before)
    # ...
end

# Building strategies (simplified)
function _solve_from_complete_description(ocp, method, parsed)
    discretizer = build_strategy_from_method(method, STRATEGY_FAMILIES.discretizer; parsed.disc_kwargs...)
    modeler = build_strategy_from_method(method, STRATEGY_FAMILIES.modeler; parsed.modeler_options...)
    solver = build_strategy_from_method(method, STRATEGY_FAMILIES.solver; parsed.solver_kwargs...)
    
    # ... rest of solve logic
end
```

**Reduction**: ~150 lines removed

---

## Advanced: Generic Option Routing

We could go further and make option routing completely generic:

### In Strategies Module

````julia
"""
Route kwargs to multiple families based on their option keys.

Returns a Dict mapping family names to their kwargs.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver,
)
kwargs = (grid_size=100, backend=:sparse, max_iter=1000)

routed = route_options_to_families(method, families, kwargs)
# => Dict(
#     :discretizer => (grid_size=100,),
#     :modeler => (backend=:sparse,),
#     :solver => (max_iter=1000,),
# )
```
"""
function route_options_to_families(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,  # family_name => Type
    kwargs::NamedTuple;
    allow_ambiguous::Bool=false
)
    # Build option key sets for each family
    family_keys = Dict{Symbol, Set{Symbol}}()
    for (name, family) in pairs(families)
        keys = option_names_from_method(method, family)
        family_keys[name] = Set(keys)
    end
    
    # Route each kwarg
    routed = Dict{Symbol, Vector{Pair{Symbol,Any}}}()
    for (name, _) in pairs(families)
        routed[name] = Pair{Symbol,Any}[]
    end
    
    for (key, value) in pairs(kwargs)
        # Find which families own this option
        owners = Symbol[]
        for (name, keys) in pairs(family_keys)
            if key in keys
                push!(owners, name)
            end
        end
        
        # Route
        if length(owners) == 1
            push!(routed[owners[1]], key => value)
        elseif isempty(owners)
            error("Option $key doesn't belong to any family")
        elseif !allow_ambiguous
            error("Option $key is ambiguous between families: $owners")
        end
    end
    
    # Convert to NamedTuples
    result_pairs = Pair{Symbol,NamedTuple}[]
    for (name, pairs) in routed
        push!(result_pairs, name => NamedTuple(pairs))
    end
    
    return NamedTuple(result_pairs)
end
````

### In OptimalControl.jl (Ultra-Simplified)

```julia
function _solve_from_complete_description(ocp, method, parsed)
    # Route all options in one call
    routed = route_options_to_families(method, STRATEGY_FAMILIES, parsed.other_kwargs)
    
    # Build strategies
    discretizer = build_strategy_from_method(method, STRATEGY_FAMILIES.discretizer; routed.discretizer...)
    modeler = build_strategy_from_method(method, STRATEGY_FAMILIES.modeler; routed.modeler...)
    solver = build_strategy_from_method(method, STRATEGY_FAMILIES.solver; routed.solver...)
    
    # ... rest
end
```

**Even more reduction**: ~180 lines removed total

---

## Benefits

### 1. Less Boilerplate in OptimalControl

**Before**: ~200 lines of helper functions  
**After**: ~20-50 lines (depending on how much we generalize)

### 2. Reusable for Other Projects

Any project using the Strategies registration system can use these method-based helpers.

### 3. Consistent Error Messages

All error messages come from Strategies module, ensuring consistency.

### 4. Easier to Test

Generic functions in Strategies can be tested independently.

---

## Recommendations

### Minimal Approach (Recommended)

Add to Strategies module:

- ✅ `extract_id_from_method(method, family)`
- ✅ `option_names_from_method(method, family)`
- ✅ `build_strategy_from_method(method, family; kwargs...)`

**Benefit**: ~150 lines removed from OptimalControl  
**Effort**: ~60 lines added to Strategies

### Maximal Approach (Optional)

Also add:

- ⚠️ `route_options_to_families(method, families, kwargs)`

**Benefit**: ~180 lines removed from OptimalControl  
**Effort**: ~120 lines added to Strategies

**Trade-off**: More complex, but more powerful

---

## Migration Path

### Phase 1: Add Generic Functions to Strategies

Implement in `src/strategies/registration.jl`:

- `extract_id_from_method`
- `option_names_from_method`
- `build_strategy_from_method`

### Phase 2: Update OptimalControl

Replace:

- `_get_discretizer_symbol` → `extract_id_from_method(method, AbstractOptimalControlDiscretizer)`
- `_discretizer_options_keys` → `option_names_from_method(method, AbstractOptimalControlDiscretizer)`
- `_build_discretizer_from_method` → `build_strategy_from_method(method, AbstractOptimalControlDiscretizer; kwargs...)`

Same for modeler and solver.

### Phase 3: Test

Verify all OptimalControl tests pass.

---

## Summary

**What to move to Strategies**:

1. ✅ ID extraction from method tuple
2. ✅ Option keys discovery from method tuple
3. ✅ Strategy construction from method tuple
4. ⚠️ (Optional) Complete option routing

**What stays in OptimalControl**:

- Method registry (`AVAILABLE_METHODS`)
- Family definitions (`STRATEGY_FAMILIES`)
- Solve-specific logic (initial guess, display, etc.)
- High-level solve orchestration

**Net result**: ~150-180 lines removed from OptimalControl, better separation of concerns.
