# DOCP Types
#
# This module defines the core types for Discretized Optimal Control Problems (DOCP)
# and their associated builders. These types are migrated from the legacy
# AbstractOCPTool system to work with the new strategy-based architecture.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
    AbstractBuilder

Abstract base type for all builders in the DOCP system.

This provides a common interface for model builders and solution builders
that work with discretized optimal control problems.
"""
abstract type AbstractBuilder end

"""
    AbstractModelBuilder

Abstract base type for builders that construct NLP back-end models from
an AbstractOptimizationProblem.

Concrete subtypes (for example ADNLPModelBuilder and ExaModelBuilder) are 
expected to be callable objects that encapsulate the logic for building a model 
for a specific NLP back-end.

# Example
```julia
struct MyModelBuilder <: AbstractModelBuilder
    f::Function
end

# Usage
builder = MyModelBuilder(problem -> build_nlp_model(problem))
nlp_model = builder(problem, initial_guess)
```
"""
abstract type AbstractModelBuilder <: AbstractBuilder end

"""
    ADNLPModelBuilder

Builder for constructing ADNLPModels-based NLP models from an 
AbstractOptimizationProblem.

# Fields
- `f::T`: A callable that builds the ADNLPModel when invoked.

# Example
```julia
builder = ADNLPModelBuilder(problem -> ADNLPModel(...))
nlp_model = builder(problem, initial_guess)
```
"""
struct ADNLPModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

"""
    ExaModelBuilder

Builder for constructing ExaModels-based NLP models from an 
AbstractOptimizationProblem.

# Fields
- `f::T`: A callable that builds the ExaModel when invoked.

# Example
```julia
builder = ExaModelBuilder((T, problem, x; kwargs...) -> ExaModel(...))
nlp_model = builder(Float32, problem, initial_guess)
```
"""
struct ExaModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

"""
    AbstractSolutionBuilder

Abstract base type for builders that transform NLP solutions into other
representations (for example, solutions of an optimal control problem).

Subtypes are expected to be callable, but the abstract type does not fix
the argument types. More specific contracts are documented on
AbstractOCPSolutionBuilder and related concrete types.
"""
abstract type AbstractSolutionBuilder <: AbstractBuilder end

"""
    AbstractOCPSolutionBuilder

Abstract base type for builders that transform NLP solutions into OCP solutions.

Concrete implementations should define the exact call signature and behavior
for specific solution types.
"""
abstract type AbstractOCPSolutionBuilder <: AbstractSolutionBuilder end

"""
    ADNLPSolutionBuilder

Builder for constructing OCP solutions from ADNLP solver results.

# Fields
- `f::T`: A callable that builds the solution when invoked.

# Example
```julia
builder = ADNLPSolutionBuilder(stats -> build_ocp_solution(stats))
solution = builder(stats)
```
"""
struct ADNLPSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end

"""
    ExaSolutionBuilder

Builder for constructing OCP solutions from ExaModels solver results.

# Fields
- `f::T`: A callable that builds the solution when invoked.

# Example
```julia
builder = ExaSolutionBuilder(stats -> build_ocp_solution(stats))
solution = builder(stats)
```
"""
struct ExaSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end

"""
    AbstractOptimizationProblem

Abstract base type for optimization problems built on optimal control
problems.

Subtypes of AbstractOptimizationProblem are typically paired with
AbstractModelBuilder and AbstractSolutionBuilder implementations that 
know how to construct and interpret NLP back-end models and solutions.
"""
abstract type AbstractOptimizationProblem end

"""
    OCPBackendBuilders{TM<:AbstractModelBuilder,TS<:AbstractOCPSolutionBuilder}

Container for model and solution builders for a specific NLP backend.

# Fields
- `model::TM`: The model builder for this backend
- `solution::TS`: The solution builder for this backend

# Example
```julia
builders = OCPBackendBuilders(
    ADNLPModelBuilder(problem -> ADNLPModel(...)),
    ADNLPSolutionBuilder(stats -> build_ocp_solution(stats))
)
```
"""
struct OCPBackendBuilders{TM<:AbstractModelBuilder,TS<:AbstractOCPSolutionBuilder}
    model::TM
    solution::TS
end

"""
    DiscretizedOptimalControlProblem

Discretized optimal control problem ready for NLP solving.

Wraps an optimal control problem together with backend builders for
multiple NLP backends (e.g., ADNLPModels and ExaModels).

# Fields

- `optimal_control_problem::TO`: The original optimal control problem model.
- `backend_builders::TB`: Named tuple mapping backend symbols to OCPBackendBuilders.

# Example

```julia
julia> docp = DiscretizedOptimalControlProblem(ocp, backend_builders)
```
"""
struct DiscretizedOptimalControlProblem{TO<:AbstractOptimizationProblem,TB<:NamedTuple} <: 
    AbstractOptimizationProblem
    optimal_control_problem::TO
    backend_builders::TB
    
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::TO, backend_builders::TB
    ) where {TO<:AbstractOptimizationProblem,TB<:NamedTuple}
        return new{TO,TB}(optimal_control_problem, backend_builders)
    end
    
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::AbstractOptimizationProblem,
        backend_builders::Tuple{Vararg{Pair{Symbol,<:OCPBackendBuilders}}},
    )
        return DiscretizedOptimalControlProblem(
            optimal_control_problem, (; backend_builders...)
        )
    end
    
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::AbstractOptimizationProblem,
        adnlp_model_builder::ADNLPModelBuilder,
        exa_model_builder::ExaModelBuilder,
        adnlp_solution_builder::ADNLPSolutionBuilder,
        exa_solution_builder::ExaSolutionBuilder,
    )
        return DiscretizedOptimalControlProblem(
            optimal_control_problem,
            (
                :adnlp => OCPBackendBuilders(adnlp_model_builder, adnlp_solution_builder),
                :exa => OCPBackendBuilders(exa_model_builder, exa_solution_builder),
            ),
        )
    end
end
