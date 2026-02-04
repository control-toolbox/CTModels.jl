# Option Routing and Orchestration

This page explains how the **Orchestration** module routes options to strategies and handles disambiguation when multiple strategies share the same option names.

## Overview

The Orchestration module provides the glue between user-provided options and strategy instances. Its main responsibilities are:

1. **Separating action options from strategy options**
2. **Routing strategy options** to the correct strategy family
3. **Handling disambiguation** when option names are ambiguous
4. **Supporting multi-strategy routing** for shared options

## The Routing Problem

When a user calls a solve function with options, the system needs to determine which options belong to which strategy:

```julia
solve(ocp, :collocation, :adnlp, :ipopt;
    grid_size = 100,      # → discretizer only
    max_iter = 500,       # → solver only
    backend = :sparse,    # → ??? modeler AND solver both have this option!
    display = false       # → action option
)
```

The Orchestration module solves this problem through **automatic routing** and **explicit disambiguation**.

## Auto-Routing (Unambiguous Options)

When an option belongs to only one strategy, it is **automatically routed**:

```julia
using CTModels.Orchestration

method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractDiscretizer,
    modeler = AbstractModeler,
    solver = AbstractSolver
)

routed = route_all_options(
    method,
    families,
    action_defs,  # Action option definitions
    (grid_size = 100, max_iter = 500, display = false),
    registry
)

# Result:
# routed.action = (display = OptionValue(false, :user),)
# routed.strategies.discretizer = (grid_size = 100,)
# routed.strategies.solver = (max_iter = 500,)
```

## Disambiguation Syntax

When an option is **ambiguous** (belongs to multiple strategies), you must explicitly specify which strategy should receive it.

### Single Strategy Disambiguation

Route an option to **one specific strategy** using `(value, :strategy_id)`:

```julia
solve(ocp, :collocation, :adnlp, :ipopt;
    backend = (:sparse, :adnlp)  # Route backend to modeler only
)
```

The syntax is:
- `option_name = (value, :strategy_id)`
- `:strategy_id` must be one of the IDs in the method tuple

### Multi-Strategy Disambiguation

Route an option to **multiple strategies** with different values:

```julia
solve(ocp, :collocation, :adnlp, :ipopt;
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))
    # backend = :sparse for modeler
    # backend = :cpu for solver
)
```

The syntax is:
- `option_name = ((value1, :id1), (value2, :id2), ...)`
- Each tuple `(value, :id)` routes to a specific strategy

## Error Messages

The Orchestration module provides helpful error messages:

### Unknown Option

```julia
solve(ocp, :collocation, :adnlp, :ipopt; unknown_key = 123)
```

```
Error: Option :unknown_key doesn't belong to any strategy in method 
(:collocation, :adnlp, :ipopt).

Available options:
  discretizer (:collocation): grid_size, scheme
  modeler (:adnlp): backend, show_time
  solver (:ipopt): max_iter, tol, backend
```

### Ambiguous Option

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = :sparse)
```

```
Error: Option :backend is ambiguous between strategies: :adnlp, :ipopt.

Disambiguate by specifying the strategy ID:
  backend = (:sparse, :adnlp)    # Route to modeler
  backend = (:cpu, :ipopt)       # Route to solver

Or set for multiple strategies:
  backend = ((:sparse, :adnlp), (:cpu, :ipopt))
```

### Invalid Disambiguation

```julia
solve(ocp, :collocation, :adnlp, :ipopt; grid_size = (100, :ipopt))
```

```
Error: Option :grid_size cannot be routed to strategy :ipopt.
This option belongs to: [:collocation]
```

## Complete Example

```julia
using CTModels.Orchestration
using CTModels.Strategies
using CTModels.Options

# Define method and families
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractDiscretizer,
    modeler = AbstractModeler,
    solver = AbstractSolver
)

# Define action options
action_defs = [
    OptionDefinition(
        name = :display,
        type = Bool,
        default = true,
        description = "Display solver output"
    ),
    OptionDefinition(
        name = :initial_guess,
        type = Symbol,
        default = :cold,
        description = "Initial guess strategy"
    )
]

# Route options
routed = route_all_options(
    method,
    families,
    action_defs,
    (
        # Action options
        display = false,
        initial_guess = :warm,
        
        # Unambiguous strategy options (auto-routed)
        grid_size = 150,
        max_iter = 1000,
        
        # Ambiguous option (disambiguated)
        backend = ((:sparse, :adnlp), (:cpu, :ipopt))
    ),
    registry
)

# Access results
@assert routed.action[:display].value == false
@assert routed.strategies.discretizer[:grid_size] == 150
@assert routed.strategies.modeler[:backend] == :sparse
@assert routed.strategies.solver[:backend] == :cpu
@assert routed.strategies.solver[:max_iter] == 1000
```

## API Reference

See the [Orchestration API Reference](@ref) for detailed documentation of:

- [`route_all_options`](@ref CTModels.Orchestration.route_all_options)
- [`extract_strategy_ids`](@ref CTModels.Orchestration.extract_strategy_ids)
- [`build_strategy_to_family_map`](@ref CTModels.Orchestration.build_strategy_to_family_map)
- [`build_option_ownership_map`](@ref CTModels.Orchestration.build_option_ownership_map)

## Advanced Topics

### Source Modes

The `route_all_options` function accepts a `source_mode` parameter:

- `:description` (default): User-friendly error messages with examples
- `:explicit`: Developer-oriented error messages

```julia
routed = route_all_options(
    method, families, action_defs, kwargs, registry;
    source_mode = :explicit  # For internal/debugging use
)
```

### Integration with Strategy Builders

The Orchestration module integrates seamlessly with strategy builders:

```julia
# 1. Route options
routed = route_all_options(method, families, action_defs, kwargs, registry)

# 2. Build strategies with routed options
discretizer = Orchestration.build_strategy_from_method(
    method,
    AbstractDiscretizer,
    registry;
    routed.strategies.discretizer...
)

modeler = Orchestration.build_strategy_from_method(
    method,
    AbstractModeler,
    registry;
    routed.strategies.modeler...
)

solver = Orchestration.build_strategy_from_method(
    method,
    AbstractSolver,
    registry;
    routed.strategies.solver...
)
```

## Best Practices

1. **Use auto-routing when possible**: Only disambiguate when necessary
2. **Prefer single-strategy disambiguation**: Use multi-strategy only when you need different values
3. **Validate early**: Use `route_all_options` to catch option errors before strategy construction
4. **Provide clear option names**: Avoid ambiguous names when designing strategy APIs
5. **Document disambiguation requirements**: Tell users which options need disambiguation

## See Also

- [Implementing Strategies](@ref) - How to create strategies with options
- [Strategy Families](@ref) - Organizing related strategies
- [Options Module](@ref) - Low-level option handling
