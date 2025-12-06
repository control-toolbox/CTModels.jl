# Implementing new optimization problems

This page explains how to implement new optimization problem types in
CTModels that follow the
[`AbstractOptimizationProblem`](@ref CTModels.AbstractOptimizationProblem)
interface.

Optimization problems form the bridge between high-level optimal control
models and low-level NLP back-ends. They expose back-end specific builders
for models and solutions.

The core of the interface is provided by:

- the abstract type
  [`AbstractOptimizationProblem`](@ref CTModels.AbstractOptimizationProblem);
- a set of generic methods defined in `nlp/problem_core.jl` that dispatch on
  `AbstractOptimizationProblem`:
  - [`get_adnlp_model_builder`](@ref CTModels.get_adnlp_model_builder)
  - [`get_exa_model_builder`](@ref CTModels.get_exa_model_builder)
  - [`get_adnlp_solution_builder`](@ref CTModels.get_adnlp_solution_builder)
  - [`get_exa_solution_builder`](@ref CTModels.get_exa_solution_builder)

Each generic function has a default implementation that throws
`CTBase.NotImplemented`. Concrete problem types are expected to specialize
these functions for the back-ends they want to support.

## Overview of the contract

A concrete optimization problem type `P` is expected to:

- subtype `AbstractOptimizationProblem`:

  ```julia
  struct MyProblem <: CTModels.AbstractOptimizationProblem
      # fields describing the OCP, discretization, etc.
  end
  ```

- store whatever information is needed to (re)build an NLP back-end model
  and interpret its solution;
- implement one or more of the `get_*_builder` functions listed above.

You only need to implement the methods for the back-ends that your problem
supports. For unsupported back-ends, the default `CTBase.NotImplemented`
methods will raise a clear error if they are called.

## Example: providing builders explicitly

A simple example (similar to the test helper in
`test/problems/problems_definition.jl`) is to store the builders as fields of
the problem type and just return them from the interface methods:

```julia
struct OptimizationProblem <: CTModels.AbstractOptimizationProblem
    build_adnlp_model::CTModels.ADNLPModelBuilder
    build_exa_model::CTModels.ExaModelBuilder
    adnlp_solution_builder::CTModels.ADNLPSolutionBuilder
    exa_solution_builder::CTModels.ExaSolutionBuilder
end

function CTModels.get_adnlp_model_builder(prob::OptimizationProblem)
    return prob.build_adnlp_model
end

function CTModels.get_exa_model_builder(prob::OptimizationProblem)
    return prob.build_exa_model
end

function CTModels.get_adnlp_solution_builder(prob::OptimizationProblem)
    return prob.adnlp_solution_builder
end

function CTModels.get_exa_solution_builder(prob::OptimizationProblem)
    return prob.exa_solution_builder
end
```

In this pattern, the optimization problem is essentially a container for the
four builders. The modelers and other components only interact with the
problem via the `get_*_builder` interface.

## Example: discretized optimal control problems

The type
[`DiscretizedOptimalControlProblem`](@ref CTModels.DiscretizedOptimalControlProblem)
provides a more structured example. It stores a high-level OCP model and a
mapping from symbols (e.g. `:adnlp`, `:exa`) to
[`OCPBackendBuilders`](@ref CTModels.OCPBackendBuilders) records:

```julia
struct DiscretizedOptimalControlProblem{TO<:CTModels.AbstractModel,TB<:NamedTuple} <:
       CTModels.AbstractOptimizationProblem
    optimal_control_problem::TO
    backend_builders::TB
end
```

Each `OCPBackendBuilders` value stores a model builder
(`TM <: AbstractModelBuilder`) and a solution builder
(`TS <: AbstractOCPSolutionBuilder`). The `get_*_builder` methods then
retrieve the appropriate entry from the `backend_builders` NamedTuple.

This design allows the same discretized problem to support multiple NLP
back-ends at once.

## Relationship with modelers and tools

Optimization problems do not directly know how to build an NLP model. That
logic lives in modelers, which are subtypes of
[`AbstractOptimizationModeler`](@ref CTModels.AbstractOptimizationModeler)
and also implement the [`AbstractOCPTool`](@ref CTModels.AbstractOCPTool)
interface.

A typical workflow is:

1. Construct a `MyProblem <: AbstractOptimizationProblem` that describes the
   OCP and its discretization.
2. Construct a modeler tool (e.g. `ADNLPModeler`, `ExaModeler`).
3. The modeler calls `get_*_model_builder(prob)` to obtain the builder for its
   back-end, then applies it to the initial guess to obtain an NLP model.
4. After solving the NLP, the modeler may call `get_*_solution_builder(prob)`
   to turn the back-end solution into an OCP-related representation.

For the implementation of modelers and tools, see also
[`ocp_tools.md`](@ref) and the separate page on optimization modelers.
