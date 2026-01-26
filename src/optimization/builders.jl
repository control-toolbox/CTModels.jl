# Abstract Builders
#
# General abstract builder types for optimization problems.
# These types define the interface for building NLP models and solutions.
#
# Author: CTModels Development Team
# Date: 2026-01-26

"""
AbstractBuilder

Abstract base type for all builders in the optimization system.

This provides a common interface for model builders and solution builders
that work with optimization problems.
"""
abstract type AbstractBuilder end

"""
AbstractModelBuilder

Abstract base type for builders that construct NLP back-end models from
an AbstractOptimizationProblem.

Concrete subtypes are expected to be callable objects that encapsulate 
the logic for building a model for a specific NLP back-end.

# Example
```julia-repl
julia> struct MyModelBuilder <: AbstractModelBuilder
           f::Function
       end

julia> builder = MyModelBuilder(problem -> build_nlp_model(problem))
MyModelBuilder(...)

julia> nlp_model = builder(problem, initial_guess)
NLPModel(...)
```
"""
abstract type AbstractModelBuilder <: AbstractBuilder end

"""
AbstractSolutionBuilder

Abstract base type for builders that transform NLP solutions into other
representations (for example, solutions of an optimal control problem).

Subtypes are expected to be callable, but the abstract type does not fix
the argument types. More specific contracts are documented on concrete types.
"""
abstract type AbstractSolutionBuilder <: AbstractBuilder end

"""
AbstractOCPSolutionBuilder

Abstract base type for builders that transform NLP solutions into OCP solutions.

Concrete implementations should define the exact call signature and behavior
for specific solution types.
"""
abstract type AbstractOCPSolutionBuilder <: AbstractSolutionBuilder end
