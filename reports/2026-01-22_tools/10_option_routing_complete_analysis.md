# Option Routing System - Final Design (Breaking)

**Date**: 2026-01-22  
**Status**: Final - Breaking Changes Accepted

> [!IMPORTANT]
> This document describes the **breaking** design for option routing.
> Strategy-based disambiguation is the only supported syntax.
> Family-based disambiguation is deprecated.
>
> **Registry Approach**: This document uses **explicit registry** (passed as argument).
> See `11_explicit_registry_architecture.md` for complete registry specification.

---

## Executive Summary

OptimalControl's option routing system is more sophisticated than initially analyzed. It includes:

1. **Disambiguation syntax**: `key=(value, :family)` to resolve ambiguities
2. **Source modes**: `:description` vs explicit mode for different error messages
3. **Multi-owner handling**: Options that belong to multiple families

This document analyzes the current system and proposes improvements.

---

## Current Disambiguation System

### 1. Basic Syntax: `(value, :tool)`

**Current implementation** (lines 147-155):

```julia
function _extract_option_tool(raw)
    if raw isa Tuple{Any,Symbol}
        value, tool = raw
        if tool in _OCP_TOOLS  # (:discretizer, :modeler, :solver, :solve)
            return value, tool
        end
    end
    return raw, nothing
end
```

**Usage**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :modeler)  # Disambiguate: backend goes to modeler
)
```

**Problem identified**: Uses **family names** (`:modeler`) instead of **strategy IDs** (`:adnlp`).

---

### 2. Source Mode: `:description` vs Explicit

**Purpose** (lines 176-187):

```julia
if source_mode === :description
    msg = "Keyword option $(key) is ambiguous between tools $(owners). " *
          "Disambiguate it by writing $(key) = (value, :tool), for example " *
          "$(key) = (value, :discretizer) or $(key) = (value, :solver)."
    throw(CTBase.IncorrectArgument(msg))
else
    msg = "Ambiguous keyword option $(key) when routing from explicit mode; " *
          "internal calls should use the (value, tool) form."
    throw(CTBase.IncorrectArgument(msg))
end
```

**Explanation**:

- **`:description` mode**: User calls `solve(ocp, :collocation, :adnlp, :ipopt; kwargs...)`
  - Error message is **user-friendly**: "Disambiguate by writing `key = (value, :tool)`"
  
- **Explicit mode**: User calls `solve(ocp; discretizer=..., modeler=..., solver=..., kwargs...)`
  - Error message is **developer-oriented**: "Internal calls should use the (value, tool) form"
  - This is for **internal** routing when components are provided explicitly

**Why two modes?**

- Description mode: User-facing, needs helpful error messages
- Explicit mode: Internal/advanced usage, different expectations

---

### 3. Routing Logic (lines 157-189)

**Step-by-step**:

1. **Extract disambiguation** (if present):

   ```julia
   value, explicit_tool = _extract_option_tool(raw_value)
   # If raw_value = (:sparse, :modeler) => value = :sparse, explicit_tool = :modeler
   ```

2. **If explicitly disambiguated**:

   ```julia
   if explicit_tool !== nothing
       if !(explicit_tool in owners)
           error("Cannot route to $explicit_tool; valid tools are $owners")
       end
       return value, explicit_tool
   end
   ```

3. **If not disambiguated**:
   - **No owners**: Error (option doesn't belong to anyone)
   - **One owner**: Auto-route to that owner
   - **Multiple owners**: Error (ambiguous) with different message based on `source_mode`

---

## Issues with Current System

### Issue 1: Family Names vs Strategy IDs

**Current**: `backend = (:sparse, :modeler)`  
**Problem**: Uses family name (`:modeler`) which is abstract

**Better**: `backend = (:sparse, :adnlp)`  
**Benefit**: Uses strategy ID, more specific and consistent with method tuples

**Example**:

```julia
# Current (family-based)
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :modeler))

# Proposed (strategy-based)
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :adnlp))
```

---

### Issue 2: No Multi-Strategy Support

**Missing**: `key = ((value1, :strategy1), (value2, :strategy2))`

**Use case**: Set the same option to different values for different strategies

**Example**:

```julia
# Hypothetical: Set backend for both modeler AND solver
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))
)
```

**Current behavior**: Not supported, would fail

---

### Issue 3: Ambiguity Detection is Pre-Routing

**Current** (lines 416-446):

```julia
function _ensure_no_ambiguous_description_kwargs(method::Tuple, kwargs::NamedTuple)
    # Check for ambiguities BEFORE routing
    for (k, raw) in pairs(kwargs)
        owners = Symbol[]
        # ... find owners ...
        _route_option_for_description(k, raw, owners, :description)
    end
end
```

**Called**: Before any actual routing happens (line 640)

**Purpose**: Early validation to give better error messages

---

## Proposed Improvements

### Improvement 1: Strategy-Based Disambiguation

**Change**: Use strategy IDs instead of family names

**Implementation**:

```julia
# New extraction function
function _extract_option_strategy(raw, method::Tuple)
    if raw isa Tuple{Any,Symbol}
        value, id = raw
        # Validate that id is in the method
        if id in method
            return value, id
        else
            error("Strategy ID $id not in method $method")
        end
    end
    return raw, nothing
end

# Updated routing
function _route_option_for_description(
    key::Symbol, 
    raw_value, 
    owners::Dict{Symbol, Symbol},  # family => strategy_id
    method::Tuple,
    source_mode::Symbol
)
    value, explicit_id = _extract_option_strategy(raw_value, method)
    
    if explicit_id !== nothing
        # Find which family this strategy belongs to
        family = find_family_for_strategy(explicit_id, owners)
        return value, family
    end
    
    # ... rest of logic
end
```

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # ← Uses strategy ID, not family name
)
```

---

### Improvement 2: Multi-Strategy Routing

**Syntax**: `key = ((value1, :id1), (value2, :id2), ...)`

**Implementation**:

```julia
function _extract_option_strategies(raw, method::Tuple)
    # Single strategy: (value, :id)
    if raw isa Tuple{Any,Symbol}
        value, id = raw
        if id in method
            return [(value, id)]
        end
    end
    
    # Multiple strategies: ((value1, :id1), (value2, :id2))
    if raw isa Tuple
        results = Tuple{Any,Symbol}[]
        for item in raw
            if item isa Tuple{Any,Symbol}
                value, id = item
                if id in method
                    push!(results, (value, id))
                end
            end
        end
        if !isempty(results)
            return results
        end
    end
    
    # No disambiguation
    return nothing
end
```

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))  # Set for both
)
```

---

### Improvement 3: Clearer Error Messages

**Current**:

```
"Disambiguate it by writing backend = (value, :tool)"
```

**Proposed**:

```
"Disambiguate it by writing backend = (value, :strategy_id), for example:
  backend = (:sparse, :adnlp)  or  backend = (:cpu, :ipopt)
Available strategies in this method: :collocation, :adnlp, :ipopt"
```

---

## Generalized Routing Function

### For Strategies Module

```julia
"""
Route options to strategies with disambiguation support.

# Disambiguation Syntax

- `key = value` - Auto-route if unambiguous
- `key = (value, :strategy_id)` - Route to specific strategy
- `key = ((v1, :id1), (v2, :id2))` - Route to multiple strategies

# Example

```julia
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver,
)
kwargs = (
    grid_size = 100,                    # Unambiguous → discretizer
    backend = (:sparse, :adnlp),        # Disambiguated → modeler
    max_iter = 1000,                    # Unambiguous → solver
)

routed = route_options_with_disambiguation(method, families, kwargs)
# => (
#     discretizer => (grid_size=100,),
#     modeler => (backend=:sparse,),
#     solver => (max_iter=1000,),
# )
```

"""
function route_options_with_disambiguation(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,  # family_name => Type
    kwargs::NamedTuple;
    source_mode::Symbol=:description
)
    # Build strategy-to-family mapping
    strategy_to_family = Dict{Symbol,Symbol}()
    for (family_name, family_type) in pairs(families)
        id = extract_id_from_method(method, family_type)
        strategy_to_family[id] = family_name
    end

    # Build option ownership: option_key => Set{family_name}
    option_owners = Dict{Symbol, Set{Symbol}}()
    for (family_name, family_type) in pairs(families)
        keys = option_names_from_method(method, family_type)
        for key in keys
            if !haskey(option_owners, key)
                option_owners[key] = Set{Symbol}()
            end
            push!(option_owners[key], family_name)
        end
    end
    
    # Route each option
    routed = Dict{Symbol, Vector{Pair{Symbol,Any}}}()
    for (family_name, _) in pairs(families)
        routed[family_name] = Pair{Symbol,Any}[]
    end
    
    for (key, raw_value) in pairs(kwargs)
        # Try to extract disambiguation
        disambiguations = _extract_option_strategies(raw_value, method)
        
        if disambiguations !== nothing
            # Explicitly disambiguated
            for (value, strategy_id) in disambiguations
                family_name = strategy_to_family[strategy_id]
                # Validate that this family owns this option
                if haskey(option_owners, key) && family_name in option_owners[key]
                    push!(routed[family_name], key => value)
                else
                    error("Option $key cannot be routed to $strategy_id")
                end
            end
        else
            # Auto-route based on ownership
            value = raw_value
            owners = get(option_owners, key, Set{Symbol}())
            
            if isempty(owners)
                error("Option $key doesn't belong to any strategy in method $method")
            elseif length(owners) == 1
                family_name = first(owners)
                push!(routed[family_name], key => value)
            else
                # Ambiguous
                if source_mode === :description
                    strategies = [id for (id, fam) in strategy_to_family if fam in owners]
                    msg = "Option $key is ambiguous between strategies: $strategies. " *
                          "Disambiguate by writing $key = (value, :strategy_id), for example: " *
                          "$key = ($value, :$(first(strategies)))"
                    error(msg)
                else
                    error("Ambiguous option $key in explicit mode")
                end
            end
        end
    end
    
    # Convert to NamedTuples
    result_pairs = Pair{Symbol,NamedTuple}[]
    for (family_name, pairs) in routed
        push!(result_pairs, family_name => NamedTuple(pairs))
    end
    
    return NamedTuple(result_pairs)
end

# Helper function

function _extract_option_strategies(raw, method::Tuple)
    # Single: (value, :id)
    if raw isa Tuple{Any,Symbol} && length(raw) == 2
        value, id = raw
        if id in method
            return [(value, id)]
        end
    end

    # Multiple: ((v1, :id1), (v2, :id2), ...)
    if raw isa Tuple
        results = Tuple{Any,Symbol}[]
        all_valid = true
        for item in raw
            if item isa Tuple{Any,Symbol} && length(item) == 2
                value, id = item
                if id in method
                    push!(results, (value, id))
                else
                    all_valid = false
                    break
                end
            else
                all_valid = false
                break
            end
        end
        if all_valid && !isempty(results)
            return results
        end
    end
    
    return nothing
end

```

---

## Summary of Changes

### 1. Disambiguation Syntax

**Old**: `key = (value, :family_name)`  
**New**: `key = (value, :strategy_id)`

**Benefit**: Consistent with method tuples, more specific

### 2. Multi-Strategy Support

**New**: `key = ((value1, :id1), (value2, :id2))`

**Benefit**: Can set same option for multiple strategies

### 3. Source Mode

**Keep**: `source_mode` parameter for different error messages

**Values**:
- `:description` - User-facing mode (helpful errors)
- `:explicit` - Internal mode (developer errors)

### 4. Error Messages

**Improved**: Show available strategy IDs in error messages

---

## Migration Impact

### OptimalControl.jl

**Before**:
```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :modeler)  # Family name
)
```

**After**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # Strategy ID
)
```

**Breaking change**: Yes, but more consistent

**Migration**: Update documentation and examples

---

---

## Final Breaking Design

### Decision: Strategy-Based Disambiguation Only

**Syntax**: `key = (value, :strategy_id)`

**Benefits**:

- ✅ Consistent with method tuples
- ✅ More specific and explicit
- ✅ Simpler mental model

**Breaking change**: Old `key = (value, :family)` syntax is **removed**

---

## Complete Routing Function Specification

### Function Signature

```julia
function route_options(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,  # family_name => AbstractStrategy subtype
    kwargs::NamedTuple;
    source_mode::Symbol=:description
) -> NamedTuple  # family_name => NamedTuple of routed options
```

### Arguments

1. **`method`**: Complete method tuple (e.g., `(:collocation, :adnlp, :ipopt)`)
2. **`families`**: Named tuple mapping family names to types

   ```julia
   (
       discretizer = AbstractOptimalControlDiscretizer,
       modeler = AbstractOptimizationModeler,
       solver = AbstractOptimizationSolver,
   )
   ```

3. **`kwargs`**: User-provided options to route
4. **`source_mode`**: Error message mode (`:description` or `:explicit`)

### Return Value

NamedTuple with routed options per family:

```julia
(
    discretizer = (grid_size=100,),
    modeler = (backend=:sparse,),
    solver = (max_iter=1000,),
)
```

---

## Disambiguation Syntax

### 1. Auto-Routing (Unambiguous)

**Syntax**: `key = value`

**When**: Option belongs to exactly ONE strategy in the method

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    grid_size = 100  # Only discretizer has this option → auto-route
)
```

### 2. Single Strategy Disambiguation

**Syntax**: `key = (value, :strategy_id)`

**When**: Option belongs to MULTIPLE strategies, user picks one

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # Both modeler and solver have backend → disambiguate
)
```

### 3. Multi-Strategy Routing

**Syntax**: `key = ((value1, :id1), (value2, :id2), ...)`

**When**: User wants to set SAME option to DIFFERENT values for MULTIPLE strategies

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))  # Set backend for both
)
```

---

## Algorithm

### Step 1: Build Strategy-to-Family Mapping

```julia
strategy_to_family = Dict{Symbol,Symbol}()
for (family_name, family_type) in pairs(families)
    id = extract_id_from_method(method, family_type)
    strategy_to_family[id] = family_name
end
# => Dict(:collocation => :discretizer, :adnlp => :modeler, :ipopt => :solver)
```

### Step 2: Build Option Ownership Map

```julia
option_owners = Dict{Symbol, Set{Symbol}}()
for (family_name, family_type) in pairs(families)
    keys = option_names_from_method(method, family_type)
    for key in keys
        if !haskey(option_owners, key)
            option_owners[key] = Set{Symbol}()
        end
        push!(option_owners[key], family_name)
    end
end
# => Dict(:grid_size => Set([:discretizer]), :backend => Set([:modeler, :solver]), ...)
```

### Step 3: Route Each Option

For each `(key, raw_value)` in kwargs:

1. **Try to extract disambiguation**:

   ```julia
   disambiguations = extract_strategy_ids(raw_value, method)
   ```

2. **If disambiguated** (not `nothing`):

   ```julia
   for (value, strategy_id) in disambiguations
       family_name = strategy_to_family[strategy_id]
       # Validate ownership
       if family_name in option_owners[key]
           route to family_name
       else
           error("Option $key cannot be routed to $strategy_id")
       end
   end
   ```

3. **If not disambiguated**:

   ```julia
   owners = option_owners[key]
   if length(owners) == 0
       error("Unknown option $key")
   elseif length(owners) == 1
       route to first(owners)
   else
       error("Ambiguous option $key between $owners")
   end
   ```

---

## Error Messages

### Unknown Option

```
Error: Option `unknown_key` doesn't belong to any strategy in method (:collocation, :adnlp, :ipopt).

Available options:
  Discretizer (:collocation): grid_size, scheme
  Modeler (:adnlp): backend, show_time
  Solver (:ipopt): max_iter, tol, print_level
```

### Ambiguous Option

```
Error: Option `backend` is ambiguous between strategies: :adnlp, :ipopt.

Disambiguate by specifying the strategy ID:
  backend = (:sparse, :adnlp)    # Route to modeler
  backend = (:cpu, :ipopt)       # Route to solver

Or set for both:
  backend = ((:sparse, :adnlp), (:cpu, :ipopt))
```

### Invalid Disambiguation

```
Error: Option `grid_size` cannot be routed to strategy :ipopt.

This option belongs to: :collocation (discretizer)
```

### Invalid Strategy ID

```
Error: Strategy ID :unknown not in method (:collocation, :adnlp, :ipopt).

Available strategies: :collocation, :adnlp, :ipopt
```

---

## Helper Function: Extract Strategy IDs

```julia
"""
Extract strategy IDs from raw value for disambiguation.

Returns `nothing` if no disambiguation, or a vector of (value, id) pairs.
"""
function extract_strategy_ids(raw, method::Tuple)
    # Single: (value, :id)
    if raw isa Tuple{Any,Symbol} && length(raw) == 2
        value, id = raw
        if id in method
            return [(value, id)]
        else
            error("Strategy ID $id not in method $method")
        end
    end
    
    # Multiple: ((v1, :id1), (v2, :id2), ...)
    if raw isa Tuple && length(raw) > 0
        results = Tuple{Any,Symbol}[]
        for item in raw
            if item isa Tuple{Any,Symbol} && length(item) == 2
                value, id = item
                if !(id in method)
                    error("Strategy ID $id not in method $method")
                end
                push!(results, (value, id))
            else
                # Not a valid disambiguation tuple
                return nothing
            end
        end
        if !isempty(results)
            return results
        end
    end
    
    # No disambiguation
    return nothing
end
```

---

## Complete Implementation

````julia
"""
Route options to strategies with strategy-based disambiguation.

# Arguments
- `method`: Complete method tuple (e.g., `(:collocation, :adnlp, :ipopt)`)
- `families`: NamedTuple mapping family names to AbstractStrategy types
- `kwargs`: User options to route
- `source_mode`: `:description` (user-facing) or `:explicit` (internal)

# Returns
NamedTuple with routed options per family

# Disambiguation Syntax
- `key = value` - Auto-route if unambiguous
- `key = (value, :strategy_id)` - Route to specific strategy
- `key = ((v1, :id1), (v2, :id2))` - Route to multiple strategies

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver,
)
kwargs = (
    grid_size = 100,                        # Auto-route
    backend = (:sparse, :adnlp),            # Disambiguate to modeler
    max_iter = 1000,                        # Auto-route
)

routed = route_options(method, families, kwargs)
# => (
#     discretizer = (grid_size=100,),
#     modeler = (backend=:sparse,),
#     solver = (max_iter=1000,),
# )
```
"""
function route_options(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    kwargs::NamedTuple;
    source_mode::Symbol=:description
)
    # Step 1: Build strategy-to-family mapping
    strategy_to_family = Dict{Symbol,Symbol}()
    for (family_name, family_type) in pairs(families)
        id = extract_id_from_method(method, family_type)
        strategy_to_family[id] = family_name
    end
    
    # Step 2: Build option ownership map
    option_owners = Dict{Symbol, Set{Symbol}}()
    for (family_name, family_type) in pairs(families)
        keys = option_names_from_method(method, family_type)
        for key in keys
            if !haskey(option_owners, key)
                option_owners[key] = Set{Symbol}()
            end
            push!(option_owners[key], family_name)
        end
    end
    
    # Step 3: Route each option
    routed = Dict{Symbol, Vector{Pair{Symbol,Any}}}()
    for (family_name, _) in pairs(families)
        routed[family_name] = Pair{Symbol,Any}[]
    end
    
    for (key, raw_value) in pairs(kwargs)
        # Try to extract disambiguation
        disambiguations = extract_strategy_ids(raw_value, method)
        
        if disambiguations !== nothing
            # Explicitly disambiguated
            for (value, strategy_id) in disambiguations
                family_name = strategy_to_family[strategy_id]
                owners = get(option_owners, key, Set{Symbol}())
                
                # Validate that this family owns this option
                if family_name in owners
                    push!(routed[family_name], key => value)
                else
                    # Better error message
                    valid_strategies = [id for (id, fam) in strategy_to_family if fam in owners]
                    error("Option $key cannot be routed to $strategy_id. " *
                          "This option belongs to: $valid_strategies")
                end
            end
        else
            # Auto-route based on ownership
            value = raw_value
            owners = get(option_owners, key, Set{Symbol}())
            
            if isempty(owners)
                # Unknown option - provide helpful error
                all_options = Dict{Symbol, Vector{Symbol}}()
                for (family_name, family_type) in pairs(families)
                    id = extract_id_from_method(method, family_type)
                    keys = option_names_from_method(method, family_type)
                    all_options[id] = collect(keys)
                end
                
                msg = "Option $key doesn't belong to any strategy in method $method.\n\n" *
                      "Available options:\n"
                for (id, keys) in all_options
                    family = strategy_to_family[id]
                    msg *= "  $family ($id): $(join(keys, ", "))\n"
                end
                error(msg)
                
            elseif length(owners) == 1
                # Unambiguous - auto-route
                family_name = first(owners)
                push!(routed[family_name], key => value)
            else
                # Ambiguous
                strategies = [id for (id, fam) in strategy_to_family if fam in owners]
                
                if source_mode === :description
                    msg = "Option $key is ambiguous between strategies: $(join(strategies, ", ")).\n\n" *
                          "Disambiguate by specifying the strategy ID:\n"
                    for id in strategies
                        fam = strategy_to_family[id]
                        msg *= "  $key = ($value, :$id)    # Route to $fam\n"
                    end
                    msg *= "\nOr set for multiple strategies:\n" *
                           "  $key = (" * join(["($value, :$id)" for id in strategies], ", ") * ")"
                    error(msg)
                else
                    error("Ambiguous option $key in explicit mode between families: $owners")
                end
            end
        end
    end
    
    # Step 4: Convert to NamedTuples
    result_pairs = Pair{Symbol,NamedTuple}[]
    for (family_name, pairs) in routed
        push!(result_pairs, family_name => NamedTuple(pairs))
    end
    
    return NamedTuple(result_pairs)
end
````

---

## Usage in OptimalControl.jl

**Before** (manual routing):

```julia
function _split_kwargs_for_description(method::Tuple, parsed)
    disc_keys = Set(_discretizer_options_keys(method))
    model_keys = Set(_modeler_options_keys(method))
    solver_keys = Set(_solver_options_keys(method))
    
    # ~50 lines of manual routing logic
    # ...
end
```

**After** (using route_options):

```julia
function _split_kwargs_for_description(method::Tuple, parsed)
    routed = route_options(method, STRATEGY_FAMILIES, parsed.other_kwargs)
    
    return (
        initial_guess = parsed.initial_guess,
        display = parsed.display,
        disc_kwargs = routed.discretizer,
        modeler_options = merge(parsed.modeler_options, routed.modeler),
        solver_kwargs = routed.solver,
    )
end
```

**Reduction**: ~50 lines → ~10 lines

---

## Summary

**Breaking changes**:

1. ❌ Remove family-based disambiguation: `key = (value, :modeler)`
2. ✅ Strategy-based only: `key = (value, :adnlp)`
3. ✅ Multi-strategy support: `key = ((v1, :adnlp), (v2, :ipopt))`
4. ✅ Better error messages with strategy IDs

**Benefits**:

- Consistent with method tuples
- More explicit and specific
- Supports advanced use cases (multi-strategy)
- Clearer error messages

**Implementation**:

- Add `route_options()` to Strategies module
- Add `extract_strategy_ids()` helper
- Update OptimalControl to use new function
- Update documentation and examples
