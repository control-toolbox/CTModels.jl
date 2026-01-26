# DOCP Types
#
# This module defines concrete types for Discretized Optimal Control Problems (DOCP)
# and their associated builders. Abstract types are imported from the Optimization module.
#
# Author: CTModels Development Team
# Date: 2026-01-26

"""
$(TYPEDEF)

Builder for constructing ADNLPModels-based NLP models from an 
AbstractOptimizationProblem.

# Fields
- `f::T`: A callable that builds the ADNLPModel when invoked.

# Example
```julia-repl
julia> builder = ADNLPModelBuilder(problem -> ADNLPModel(...))
ADNLPModelBuilder(...)

julia> nlp_model = builder(problem, initial_guess)
ADNLPModel(...)
```
"""
struct ADNLPModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

"""
$(TYPEDEF)

Builder for constructing ExaModels-based NLP models from an 
AbstractOptimizationProblem.

# Fields
- `f::T`: A callable that builds the ExaModel when invoked.

# Example
```julia-repl
julia> builder = ExaModelBuilder((T, problem, x; kwargs...) -> ExaModel(...))
ExaModelBuilder(...)

julia> nlp_model = builder(Float32, problem, initial_guess)
ExaModel{Float32}(...)
```
"""
struct ExaModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end


"""
$(TYPEDEF)

Builder for constructing OCP solutions from ADNLP solver results.

# Fields
- `f::T`: A callable that builds the solution when invoked.

# Example
```julia-repl
julia> builder = ADNLPSolutionBuilder(stats -> build_ocp_solution(stats))
ADNLPSolutionBuilder(...)

julia> solution = builder(stats)
OCPSolution(...)
```
"""
struct ADNLPSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end

"""
$(TYPEDEF)

Builder for constructing OCP solutions from ExaModels solver results.

# Fields
- `f::T`: A callable that builds the solution when invoked.

# Example
```julia-repl
julia> builder = ExaSolutionBuilder(stats -> build_ocp_solution(stats))
ExaSolutionBuilder(...)

julia> solution = builder(stats)
OCPSolution(...)
```
"""
struct ExaSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end


"""
$(TYPEDEF)

Container for model and solution builders for a specific NLP backend.

# Fields
- `model::TM`: The model builder for this backend
- `solution::TS`: The solution builder for this backend

# Example
```julia-repl
julia> builders = OCPBackendBuilders(
           ADNLPModelBuilder(problem -> ADNLPModel(...)),
           ADNLPSolutionBuilder(stats -> build_ocp_solution(stats))
       )
OCPBackendBuilders{ADNLPModelBuilder, ADNLPSolutionBuilder}(...)
```
"""
struct OCPBackendBuilders{TM<:AbstractModelBuilder,TS<:AbstractOCPSolutionBuilder}
    model::TM
    solution::TS
end

"""
$(TYPEDEF)

Discretized optimal control problem ready for NLP solving.

Wraps an optimal control problem together with backend builders for
multiple NLP backends (e.g., ADNLPModels and ExaModels).

# Fields

- `optimal_control_problem::TO`: The original optimal control problem model.
- `backend_builders::TB`: Named tuple mapping backend symbols to OCPBackendBuilders.

# Example

```julia-repl
julia> docp = DiscretizedOptimalControlProblem(ocp, backend_builders)
DiscretizedOptimalControlProblem{...}(...)
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
