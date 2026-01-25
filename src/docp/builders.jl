# DOCP Builders
#
# This module provides builder functions and utilities for creating and managing
# model and solution builders for discretized optimal control problems.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
$(TYPEDSIGNATURES)

Get the appropriate ADNLP model builder for the given problem type.

This function dispatches on the problem type to return the correct
ADNLPModelBuilder implementation.

# Arguments
- `prob::AbstractOptimizationProblem`: The discretized optimal control problem

# Returns
- `ADNLPModelBuilder`: An ADNLPModelBuilder instance

# Throws
- `CTBase.NotImplemented`: If no builder is defined for the problem type

# Example
```julia-repl
julia> builder = get_adnlp_model_builder(problem)
ADNLPModelBuilder(...)
```
"""
function get_adnlp_model_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(CTBase.NotImplemented("get_adnlp_model_builder not implemented for $(typeof(prob))"))
end

"""
$(TYPEDSIGNATURES)

Get the appropriate ExaModel builder for the given problem type.

This function dispatches on the problem type to return the correct
ExaModelBuilder implementation.

# Arguments
- `prob::AbstractOptimizationProblem`: The discretized optimal control problem

# Returns
- `ExaModelBuilder`: An ExaModelBuilder instance

# Throws
- `CTBase.NotImplemented`: If no builder is defined for the problem type

# Example
```julia-repl
julia> builder = get_exa_model_builder(problem)
ExaModelBuilder(...)
```
"""
function get_exa_model_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(CTBase.NotImplemented("get_exa_model_builder not implemented for $(typeof(prob))"))
end

"""
$(TYPEDSIGNATURES)

Get the appropriate ADNLP solution builder for the given problem type.

This function dispatches on the problem type to return the correct
ADNLPSolutionBuilder implementation.

# Arguments
- `prob::AbstractOptimizationProblem`: The discretized optimal control problem

# Returns
- `ADNLPSolutionBuilder`: An ADNLPSolutionBuilder instance

# Throws
- `CTBase.NotImplemented`: If no builder is defined for the problem type

# Example
```julia-repl
julia> builder = get_adnlp_solution_builder(problem)
ADNLPSolutionBuilder(...)
```
"""
function get_adnlp_solution_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(CTBase.NotImplemented("get_adnlp_solution_builder not implemented for $(typeof(prob))"))
end

"""
$(TYPEDSIGNATURES)

Get the appropriate ExaModel solution builder for the given problem type.

This function dispatches on the problem type to return the correct
ExaSolutionBuilder implementation.

# Arguments
- `prob::AbstractOptimizationProblem`: The discretized optimal control problem

# Returns
- `ExaSolutionBuilder`: An ExaSolutionBuilder instance

# Throws
- `CTBase.NotImplemented`: If no builder is defined for the problem type

# Example
```julia-repl
julia> builder = get_exa_solution_builder(problem)
ExaSolutionBuilder(...)
```
"""
function get_exa_solution_builder(prob::AbstractOptimizationProblem)
    # Default implementation - should be overridden by concrete problem types
    throw(CTBase.NotImplemented("get_exa_solution_builder not implemented for $(typeof(prob))"))
end

"""
$(TYPEDSIGNATURES)

Create an ADNLPModelBuilder from a callable function.

# Arguments
- `f::Function`: A function that takes (problem, initial_guess; kwargs...) and returns an ADNLPModel

# Returns
- `ADNLPModelBuilder`: An ADNLPModelBuilder instance

# Example
```julia-repl
julia> builder = create_adnlp_model_builder((prob, x; show_time=false, backend=:optimized) -> 
       ADNLPModel(prob.objective, prob.constraints, x; show_time=show_time, backend=backend))
ADNLPModelBuilder(...)
```
"""
function create_adnlp_model_builder(f::Function)
    return ADNLPModelBuilder(f)
end

"""
$(TYPEDSIGNATURES)

Create an ExaModelBuilder from a callable function.

# Arguments
- `f::Function`: A function that takes (T, problem, initial_guess; kwargs...) and returns an ExaModel

# Returns
- `ExaModelBuilder`: An ExaModelBuilder instance

# Example
```julia-repl
julia> builder = create_exa_model_builder((T, prob, x; backend=nothing, minimize=true) -> 
       ExaModel(T, prob.objective, prob.constraints, x; backend=backend, minimize=minimize))
ExaModelBuilder(...)
```
"""
function create_exa_model_builder(f::Function)
    return ExaModelBuilder(f)
end

"""
$(TYPEDSIGNATURES)

Create an ADNLPSolutionBuilder from a callable function.

# Arguments
- `f::Function`: A function that takes solver stats and returns an OCP solution

# Returns
- `ADNLPSolutionBuilder`: An ADNLPSolutionBuilder instance

# Example
```julia-repl
julia> builder = create_adnlp_solution_builder(stats -> build_ocp_solution_from_stats(stats))
ADNLPSolutionBuilder(...)
```
"""
function create_adnlp_solution_builder(f::Function)
    return ADNLPSolutionBuilder(f)
end

"""
$(TYPEDSIGNATURES)

Create an ExaSolutionBuilder from a callable function.

# Arguments
- `f::Function`: A function that takes solver stats and returns an OCP solution

# Returns
- `ExaSolutionBuilder`: An ExaSolutionBuilder instance

# Example
```julia-repl
julia> builder = create_exa_solution_builder(stats -> build_ocp_solution_from_stats(stats))
ExaSolutionBuilder(...)
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
```julia-repl
julia> builders = BackendBuilders(
       adnlp = OCPBackendBuilders(adnlp_model, adnlp_solution),
       exa = OCPBackendBuilders(exa_model, exa_solution)
)
(adnlp = OCPBackendBuilders(...), exa = OCPBackendBuilders(...))
```
"""
const BackendBuilders = NamedTuple
