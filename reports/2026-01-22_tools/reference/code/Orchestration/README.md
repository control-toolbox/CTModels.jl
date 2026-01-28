# Orchestration Module - Code Annexes

This directory contains the reference implementation for the **Orchestration** module.

---

## Structure

### `api/` - What the System Provides

Functions provided by the Orchestration module:

- **[disambiguation.jl](api/disambiguation.jl)** - `extract_strategy_ids()`, helper functions for disambiguation
- **[routing.jl](api/routing.jl)** - `route_all_options()`, complete routing with disambiguation
- **[method_builders.jl](api/method_builders.jl)** - `build_strategies_from_method()`, method-based construction

> **Note**: Orchestration has no `contract/` directory because it doesn't define types that users must implement.
> It only provides API functions that orchestrate Options and Strategies.

---

## New Features

### 1. Strategy-Based Disambiguation

**Syntax**: `option = (value, :strategy_id)`

**Purpose**: Resolve ambiguous options by specifying which strategy should receive the option.

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # Route backend to :adnlp (modeler)
)
```

**Why strategy IDs instead of family names?**

- ✅ Consistent with method tuples
- ✅ More specific and explicit
- ✅ Validates that the strategy is actually in the method

---

### 2. Multi-Strategy Routing

**Syntax**: `option = ((value1, :id1), (value2, :id2), ...)`

**Purpose**: Set the same option to different values for multiple strategies.

**Example**:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))
    # Set backend=:sparse for modeler AND backend=:cpu for solver
)
```

---

## Usage Examples

### Auto-Routing (Unambiguous)

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    grid_size = 100  # Only discretizer has this option → auto-route
)
```

### Single Strategy Disambiguation

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # Both modeler and solver have backend → disambiguate
)
```

### Multi-Strategy Routing

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))  # Set for both
)
```

---

## Error Messages

### Unknown Option

```
Error: Option :unknown_key doesn't belong to any strategy in method (:collocation, :adnlp, :ipopt).

Available options:
  discretizer (:collocation): grid_size, scheme
  modeler (:adnlp): backend, show_time
  solver (:ipopt): max_iter, tol, print_level
```

### Ambiguous Option

```
Error: Option :backend is ambiguous between strategies: :adnlp, :ipopt.

Disambiguate by specifying the strategy ID:
  backend = (:sparse, :adnlp)    # Route to modeler
  backend = (:cpu, :ipopt)       # Route to solver

Or set for multiple strategies:
  backend = ((:sparse, :adnlp), (:cpu, :ipopt))
```

### Invalid Disambiguation

```
Error: Option :grid_size cannot be routed to strategy :ipopt.
This option belongs to: [:collocation]
```

---

## Breaking Changes

**Old syntax** (family-based, deprecated):

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :modeler))
```

**New syntax** (strategy-based):

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :adnlp))
```

---

## Implementation Notes

### Algorithm

1. **Extract action options first** (using `Options.extract_options`)
2. **Build mappings**:
   - Strategy ID → Family name
   - Option name → Set of owning families
3. **Route each option**:
   - If disambiguated: validate and route to specified strategy/strategies
   - If not: auto-route if unambiguous, error if ambiguous
4. **Return** action options and routed strategy options

### Source Modes

- `:description` - User-facing mode with helpful error messages
- `:explicit` - Internal mode with developer-oriented errors

---

## See Also

- [../README.md](../README.md) - Overall code annexes documentation
- [../../solve_ideal.jl](../../solve_ideal.jl) - Complete example using disambiguation
- [../../13_module_dependencies_architecture.md](../../13_module_dependencies_architecture.md) - Overall architecture
- [../../../analysis/10_option_routing_complete_analysis.md](../../../analysis/10_option_routing_complete_analysis.md) - Detailed analysis
