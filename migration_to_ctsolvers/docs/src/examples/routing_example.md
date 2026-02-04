# Example: Option Routing with Disambiguation

This example demonstrates how to use the Orchestration module to route options to strategies, including handling ambiguous options through disambiguation.

## Setup

First, let's define some simple strategies for this example:

```julia
using CTModels.Strategies
using CTModels.Options
using CTModels.Orchestration

# Define strategy families
abstract type ExampleDiscretizer <: AbstractStrategy end
abstract type ExampleModeler <: AbstractStrategy end
abstract type ExampleSolver <: AbstractStrategy end

# Discretizer strategy
struct Collocation <: ExampleDiscretizer
    options::StrategyOptions
end

Strategies.id(::Type{Collocation}) = :collocation

Strategies.metadata(::Type{Collocation}) = StrategyMetadata(
    OptionDefinition(
        name = :grid_size,
        type = Int,
        default = 100,
        description = "Number of grid points"
    ),
    OptionDefinition(
        name = :scheme,
        type = Symbol,
        default = :trapezoidal,
        description = "Discretization scheme"
    )
)

function Collocation(; kwargs...)
    options = Strategies.build_strategy_options(Collocation; kwargs...)
    return Collocation(options)
end

# Modeler strategy
struct ADNLPModeler <: ExampleModeler
    options::StrategyOptions
end

Strategies.id(::Type{ADNLPModeler}) = :adnlp

Strategies.metadata(::Type{ADNLPModeler}) = StrategyMetadata(
    OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :dense,
        description = "Backend type (dense/sparse)"
    ),
    OptionDefinition(
        name = :show_time,
        type = Bool,
        default = false,
        description = "Show modeling time"
    )
)

function ADNLPModeler(; kwargs...)
    options = Strategies.build_strategy_options(ADNLPModeler; kwargs...)
    return ADNLPModeler(options)
end

# Solver strategy
struct IpoptSolver <: ExampleSolver
    options::StrategyOptions
end

Strategies.id(::Type{IpoptSolver}) = :ipopt

Strategies.metadata(::Type{IpoptSolver}) = StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 1000,
        description = "Maximum iterations"
    ),
    OptionDefinition(
        name = :tol,
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
    OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :cpu,
        description = "Solver backend (cpu/gpu)"
    )
)

function IpoptSolver(; kwargs...)
    options = Strategies.build_strategy_options(IpoptSolver; kwargs...)
    return IpoptSolver(options)
end

# Create registry
registry = Strategies.create_registry(
    ExampleDiscretizer => (Collocation,),
    ExampleModeler => (ADNLPModeler,),
    ExampleSolver => (IpoptSolver,)
)
```

## Example 1: Auto-Routing (No Ambiguity)

When options are unambiguous, they are automatically routed:

```julia
# Define method and families
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = ExampleDiscretizer,
    modeler = ExampleModeler,
    solver = ExampleSolver
)

# Define action options
action_defs = [
    OptionDefinition(
        name = :display,
        type = Bool,
        default = true,
        description = "Display output"
    )
]

# Route options (all unambiguous)
routed = route_all_options(
    method,
    families,
    action_defs,
    (
        display = false,        # → action
        grid_size = 200,        # → discretizer (only owner)
        scheme = :hermite,      # → discretizer (only owner)
        show_time = true,       # → modeler (only owner)
        max_iter = 500,         # → solver (only owner)
        tol = 1e-8              # → solver (only owner)
    ),
    registry
)

# Inspect results
println("Action options:")
println("  display = ", routed.action[:display].value)

println("\nDiscretizer options:")
println("  grid_size = ", routed.strategies.discretizer[:grid_size])
println("  scheme = ", routed.strategies.discretizer[:scheme])

println("\nModeler options:")
println("  show_time = ", routed.strategies.modeler[:show_time])

println("\nSolver options:")
println("  max_iter = ", routed.strategies.solver[:max_iter])
println("  tol = ", routed.strategies.solver[:tol])
```

Output:
```
Action options:
  display = false

Discretizer options:
  grid_size = 200
  scheme = :hermite

Modeler options:
  show_time = true

Solver options:
  max_iter = 500
  tol = 1.0e-8
```

## Example 2: Single Strategy Disambiguation

When an option is ambiguous (like `backend`), use disambiguation:

```julia
# This would error (backend is ambiguous):
# routed = route_all_options(
#     method, families, action_defs,
#     (backend = :sparse,),  # ERROR: ambiguous!
#     registry
# )

# Instead, disambiguate by specifying the strategy:
routed = route_all_options(
    method,
    families,
    action_defs,
    (
        backend = (:sparse, :adnlp),  # Route to modeler only
        grid_size = 150
    ),
    registry
)

println("Modeler backend: ", routed.strategies.modeler[:backend])
println("Solver backend: ", haskey(routed.strategies.solver, :backend) ? 
    routed.strategies.solver[:backend] : "not set (using default)")
```

Output:
```
Modeler backend: sparse
Solver backend: not set (using default)
```

## Example 3: Multi-Strategy Disambiguation

Set the same option to different values for multiple strategies:

```julia
routed = route_all_options(
    method,
    families,
    action_defs,
    (
        # Set backend for BOTH modeler and solver with different values
        backend = ((:sparse, :adnlp), (:gpu, :ipopt)),
        grid_size = 100,
        max_iter = 2000
    ),
    registry
)

println("Modeler backend: ", routed.strategies.modeler[:backend])
println("Solver backend: ", routed.strategies.solver[:backend])
println("Discretizer grid_size: ", routed.strategies.discretizer[:grid_size])
println("Solver max_iter: ", routed.strategies.solver[:max_iter])
```

Output:
```
Modeler backend: sparse
Solver backend: gpu
Discretizer grid_size: 100
Solver max_iter: 2000
```

## Example 4: Complete Workflow

Putting it all together - route options and build strategies:

```julia
# 1. Route all options
routed = route_all_options(
    method,
    families,
    action_defs,
    (
        # Action options
        display = false,
        
        # Strategy options (mix of auto-routed and disambiguated)
        grid_size = 150,
        scheme = :hermite,
        show_time = true,
        backend = ((:sparse, :adnlp), (:cpu, :ipopt)),
        max_iter = 500,
        tol = 1e-8
    ),
    registry
)

# 2. Build strategies with routed options
discretizer = Orchestration.build_strategy_from_method(
    method,
    ExampleDiscretizer,
    registry;
    routed.strategies.discretizer...
)

modeler = Orchestration.build_strategy_from_method(
    method,
    ExampleModeler,
    registry;
    routed.strategies.modeler...
)

solver = Orchestration.build_strategy_from_method(
    method,
    ExampleSolver,
    registry;
    routed.strategies.solver...
)

# 3. Verify strategies were built correctly
println("Discretizer: ", typeof(discretizer))
println("  grid_size = ", Strategies.option_value(discretizer, :grid_size))
println("  scheme = ", Strategies.option_value(discretizer, :scheme))

println("\nModeler: ", typeof(modeler))
println("  backend = ", Strategies.option_value(modeler, :backend))
println("  show_time = ", Strategies.option_value(modeler, :show_time))

println("\nSolver: ", typeof(solver))
println("  max_iter = ", Strategies.option_value(solver, :max_iter))
println("  tol = ", Strategies.option_value(solver, :tol))
println("  backend = ", Strategies.option_value(solver, :backend))
```

Output:
```
Discretizer: Collocation
  grid_size = 150
  scheme = hermite

Modeler: ADNLPModeler
  backend = sparse
  show_time = true

Solver: IpoptSolver
  max_iter = 500
  tol = 1.0e-8
  backend = cpu
```

## Error Handling Examples

### Unknown Option Error

```julia
try
    routed = route_all_options(
        method, families, action_defs,
        (unknown_option = 123,),
        registry
    )
catch e
    println("Error: ", e.msg)
end
```

Output:
```
Error: Option :unknown_option doesn't belong to any strategy in method 
(:collocation, :adnlp, :ipopt).

Available options:
  discretizer (:collocation): grid_size, scheme
  modeler (:adnlp): backend, show_time
  solver (:ipopt): max_iter, tol, backend
```

### Ambiguous Option Error

```julia
try
    routed = route_all_options(
        method, families, action_defs,
        (backend = :sparse,),  # Ambiguous!
        registry
    )
catch e
    println("Error: ", e.msg)
end
```

Output:
```
Error: Option :backend is ambiguous between strategies: :adnlp, :ipopt.

Disambiguate by specifying the strategy ID:
  backend = (:sparse, :adnlp)    # Route to modeler
  backend = (:cpu, :ipopt)       # Route to solver

Or set for multiple strategies:
  backend = ((:sparse, :adnlp), (:cpu, :ipopt))
```

### Invalid Disambiguation Error

```julia
try
    routed = route_all_options(
        method, families, action_defs,
        (grid_size = (100, :ipopt),),  # grid_size doesn't belong to solver!
        registry
    )
catch e
    println("Error: ", e.msg)
end
```

Output:
```
Error: Option :grid_size cannot be routed to strategy :ipopt.
This option belongs to: [:collocation]
```

## Summary

This example demonstrated:

1. ✅ **Auto-routing** for unambiguous options
2. ✅ **Single-strategy disambiguation** with `(value, :id)` syntax
3. ✅ **Multi-strategy disambiguation** with `((v1, :id1), (v2, :id2))` syntax
4. ✅ **Complete workflow** from routing to strategy construction
5. ✅ **Error handling** with helpful messages

## See Also

- [Option Routing and Orchestration](@ref) - Detailed explanation
- [Implementing Strategies](@ref) - How to create strategies
- [Strategy Families](@ref) - Organizing strategies
