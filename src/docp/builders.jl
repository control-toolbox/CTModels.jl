# DOCP Builders
#
# This module provides builder functions and utilities for creating and managing
# model and solution builders for discretized optimal control problems.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
    get_adnlp_model_builder(prob::AbstractOptimizationProblem)

Get the appropriate ADNLP model builder for the given problem type.

This function dispatches on the problem type to return the correct
ADNLPModelBuilder implementation.

# Arguments
- `prob`: The discretized optimal control problem

# Returns
- An ADNLPModelBuilder instance

# Throws
- `MethodError` if no builder is defined for the problem type
"""
function get_adnlp_model_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(MethodError("get_adnlp_model_builder not implemented for $(typeof(prob))"))
end

"""
    get_exa_model_builder(prob::AbstractOptimizationProblem)

Get the appropriate ExaModel builder for the given problem type.

This function dispatches on the problem type to return the correct
ExaModelBuilder implementation.

# Arguments
- `prob`: The discretized optimal control problem

# Returns
- An ExaModelBuilder instance

# Throws
- `MethodError` if no builder is defined for the problem type
"""
function get_exa_model_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(MethodError("get_exa_model_builder not implemented for $(typeof(prob))"))
end

"""
    get_adnlp_solution_builder(prob::AbstractOptimizationProblem)

Get the appropriate ADNLP solution builder for the given problem type.

This function dispatches on the problem type to return the correct
ADNLPSolutionBuilder implementation.

# Arguments
- `prob`: The discretized optimal control problem

# Returns
- An ADNLPSolutionBuilder instance

# Throws
- `MethodError` if no builder is defined for the problem type
"""
function get_adnlp_solution_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(MethodError("get_adnlp_solution_builder not implemented for $(typeof(prob))"))
end

"""
    get_exa_solution_builder(prob::AbstractOptimizationProblem)

Get the appropriate ExaModel solution builder for the given problem type.

This function dispatches on the problem type to return the correct
ExaSolutionBuilder implementation.

# Arguments
- `prob`: The discretized optimal control problem

# Returns
- An ExaSolutionBuilder instance

# Throws
- `MethodError` if no builder is defined for the problem type
"""
function get_exa_solution_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(MethodError("get_exa_solution_builder not implemented for $(typeof(prob))"))
end

"""
    create_adnlp_model_builder(f::Function)

Create an ADNLPModelBuilder from a callable function.

# Arguments
- `f`: A function that takes (problem, initial_guess; kwargs...) and returns an ADNLPModel

# Returns
- An ADNLPModelBuilder instance

# Example
```julia
builder = create_adnlp_model_builder((prob, x; show_time=false, backend=:optimized) -> 
    ADNLPModel(prob.objective, prob.constraints, x; show_time=show_time, backend=backend)
)
```
"""
function create_adnlp_model_builder(f::Function)
    return ADNLPModelBuilder(f)
end

"""
    create_exa_model_builder(f::Function)

Create an ExaModelBuilder from a callable function.

# Arguments
- `f`: A function that takes (T, problem, initial_guess; kwargs...) and returns an ExaModel

# Returns
- An ExaModelBuilder instance

# Example
```julia
builder = create_exa_model_builder((T, prob, x; backend=nothing, minimize=true) -> 
    ExaModel(T, prob.objective, prob.constraints, x; backend=backend, minimize=minimize)
)
```
"""
function create_exa_model_builder(f::Function)
    return ExaModelBuilder(f)
end

"""
    create_adnlp_solution_builder(f::Function)

Create an ADNLPSolutionBuilder from a callable function.

# Arguments
- `f`: A function that takes solver stats and returns an OCP solution

# Returns
- An ADNLPSolutionBuilder instance

# Example
```julia
builder = create_adnlp_solution_builder(stats -> 
    build_ocp_solution_from_stats(stats)
)
```
"""
function create_adnlp_solution_builder(f::Function)
    return ADNLPSolutionBuilder(f)
end

"""
    create_exa_solution_builder(f::Function)

Create an ExaSolutionBuilder from a callable function.

# Arguments
- `f`: A function that takes solver stats and returns an OCP solution

# Returns
- An ExaSolutionBuilder instance

# Example
```julia
builder = create_exa_solution_builder(stats -> 
    build_ocp_solution_from_stats(stats)
)
```
"""
function create_exa_solution_builder(f::Function)
    return ExaSolutionBuilder(f)
end

"""
    BackendBuilders

Named tuple of backend builders for different NLP backends.

This type alias provides a convenient way to work with collections of builders.

# Example
```julia
builders = BackendBuilders(
    adnlp = OCPBackendBuilders(adnlp_model, adnlp_solution),
    exa = OCPBackendBuilders(exa_model, exa_solution)
)
```
"""
const BackendBuilders = NamedTuple
