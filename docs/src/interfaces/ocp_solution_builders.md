# Implementing OCP solution builders

This page explains how to implement builders that turn NLP back-end
execution statistics into objects associated with discretized optimal
control problems.

These builders implement the
[`AbstractOCPSolutionBuilder`](@ref CTModels.AbstractOCPSolutionBuilder)
interface, which refines the more general
[`AbstractSolutionBuilder`](@ref CTModels.AbstractSolutionBuilder).

## Overview of the contract

A concrete OCP solution builder type `B` is expected to:

- subtype `AbstractOCPSolutionBuilder`:

  ```julia
  struct MySolutionBuilder{F} <: CTModels.AbstractOCPSolutionBuilder
      f::F  # function or callable used internally
  end
  ```

- be callable on an NLP back-end solution, represented as
  `SolverCore.AbstractExecutionStats`:

  ```julia
  (builder::MySolutionBuilder)(
      nlp_solution::SolverCore.AbstractExecutionStats;
      kwargs...,
  ) = ...
  ```

A generic fallback for this call is defined on
`AbstractOCPSolutionBuilder` and throws `CTBase.NotImplemented` if it is not
specialized.

## Relationship with optimization problems

OCP solution builders are typically stored inside
[`OCPBackendBuilders`](@ref CTModels.OCPBackendBuilders), which itself is
used by [`DiscretizedOptimalControlProblem`](@ref
CTModels.DiscretizedOptimalControlProblem). Each back-end (e.g. ADNLPModels,
ExaModels) has a pair of builders:

- a model builder `TM <: AbstractModelBuilder`;
- a solution builder `TS <: AbstractOCPSolutionBuilder`.

The optimization problem exposes these builders via the `get_*_builder`
interface:

- [`get_adnlp_solution_builder`](@ref CTModels.get_adnlp_solution_builder)
- [`get_exa_solution_builder`](@ref CTModels.get_exa_solution_builder)

Modelers (see the `optimization_modelers.md` page) retrieve the appropriate
solution builder and apply it to the NLP back-end solution when they want to
produce an OCP-related representation.

## Example: ADNLPSolutionBuilder and ExaSolutionBuilder

CTModels defines two concrete OCP solution builders in `core/types/nlp.jl`:

```julia
struct ADNLPSolutionBuilder{T<:Function} <: CTModels.AbstractOCPSolutionBuilder
    f::T
end

struct ExaSolutionBuilder{T<:Function} <: CTModels.AbstractOCPSolutionBuilder
    f::T
end
```

The corresponding call methods are implemented in `nlp/discretized_ocp.jl`:

```julia
function (builder::CTModels.ADNLPSolutionBuilder)(
    nlp_solution::SolverCore.AbstractExecutionStats,
)
    return builder.f(nlp_solution)
end

function (builder::CTModels.ExaSolutionBuilder)(
    nlp_solution::SolverCore.AbstractExecutionStats,
)
    return builder.f(nlp_solution)
end
```

This pattern allows the internal implementation (carried by `f`) to vary
while the external interface remains stable.

## Example: minimal builders in tests

The test helper in `test/problems/problems_definition.jl` shows a minimal
implementation where the solution builders simply return the NLP solution
unchanged:

```julia
abstract type AbstractNLPSolutionBuilder <: CTModels.AbstractSolutionBuilder end

struct ADNLPSolutionBuilder <: AbstractNLPSolutionBuilder end
struct ExaSolutionBuilder  <: AbstractNLPSolutionBuilder end

function (builder::ADNLPSolutionBuilder)(
    nlp_solution::SolverCore.AbstractExecutionStats,
)
    return nlp_solution
end

function (builder::ExaSolutionBuilder)(
    nlp_solution::SolverCore.AbstractExecutionStats,
)
    return nlp_solution
end
```

This illustrates that the only strict requirement at the interface level is
being callable on `AbstractExecutionStats`. The actual transformation (if
any) is left to the concrete implementation.

## Designing your own OCP solution builder

When designing a new solution builder, consider:

- **Input**: a back-end solution object, typically
  `SolverCore.AbstractExecutionStats` from the NLP solver.
- **Output**: an OCP-related representation (e.g. an
  `AbstractSolution`, a struct containing trajectories, or an intermediate
  diagnostic object).
- **Configuration**: solution builders do not usually follow the
  `AbstractOCPTool` options interface, but they may still store internal
  functions and parameters as fields.

A typical pattern is to:

1. define a struct that stores whatever is needed to interpret the NLP
   solution;
2. implement the call method described above;
3. plug the builder into your
   `AbstractOptimizationProblem` implementation via the
   `get_*_solution_builder` interface.

See also the documentation pages on optimization problems and modelers for
how these components fit together.
