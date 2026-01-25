# DOCP Constructors
#
# This module provides constructor functions and accessors for DOCP types,
# including helper functions for creating and manipulating discretized optimal
# control problems and their builders.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
$(TYPEDSIGNATURES)

Extract the original optimal control problem from a discretized problem.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem

# Returns
- `AbstractOptimizationProblem`: The original optimal control problem

# Example
```julia-repl
julia> ocp = ocp_model(docp)
AbstractOptimizationProblem(...)
```
"""
ocp_model(docp::DiscretizedOptimalControlProblem) = docp.optimal_control_problem

"""
$(TYPEDSIGNATURES)

Extract the backend builders from a discretized problem.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem

# Returns
- `NamedTuple`: Named tuple of backend builders

# Example
```julia-repl
julia> builders = backend_builders(docp)
(adnlp = OCPBackendBuilders(...), exa = OCPBackendBuilders(...))

julia> adnlp_builder = builders.adnlp
OCPBackendBuilders{ADNLPModelBuilder, ADNLPSolutionBuilder}(...)
```
"""
backend_builders(docp::DiscretizedOptimalControlProblem) = docp.backend_builders

"""
$(TYPEDSIGNATURES)

Get a specific backend builder from a discretized problem.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem
- `backend::Symbol`: Symbol identifying the backend (:adnlp, :exa, etc.)

# Returns
- `OCPBackendBuilders`: The OCPBackendBuilders for the specified backend

# Throws
- `KeyError`: If the backend is not available

# Example
```julia-repl
julia> adnlp_builders = get_backend_builder(docp, :adnlp)
OCPBackendBuilders{ADNLPModelBuilder, ADNLPSolutionBuilder}(...)

julia> exa_builders = get_backend_builder(docp, :exa)
OCPBackendBuilders{ExaModelBuilder, ExaSolutionBuilder}(...)
```
"""
function get_backend_builder(docp::DiscretizedOptimalControlProblem, backend::Symbol)
    return docp.backend_builders[backend]
end

"""
$(TYPEDSIGNATURES)

Get the list of available backends for a discretized problem.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem

# Returns
- `Vector{Symbol}`: Vector of backend symbols

# Example
```julia-repl
julia> available_backends(docp)
2-element Vector{Symbol}:
 :adnlp
 :exa
```
"""
function available_backends(docp::DiscretizedOptimalControlProblem)
    return collect(keys(docp.backend_builders))
end

"""
$(TYPEDSIGNATURES)

Check if a discretized problem has a specific backend available.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem
- `backend::Symbol`: Symbol identifying the backend

# Returns
- `Bool`: `true` if the backend is available, `false` otherwise

# Example
```julia-repl
julia> if has_backend(docp, :adnlp)
           # Use ADNLP backend
       end
```
"""
function has_backend(docp::DiscretizedOptimalControlProblem, backend::Symbol)
    return haskey(docp.backend_builders, backend)
end

"""
$(TYPEDSIGNATURES)

Create a discretized optimal control problem with custom backend builders.

# Arguments
- `ocp::AbstractOptimizationProblem`: The original optimal control problem
- `backend_builders::NamedTuple`: Named tuple mapping backend symbols to OCPBackendBuilders

# Returns
- `DiscretizedOptimalControlProblem`: A DiscretizedOptimalControlProblem instance

# Example
```julia-repl
julia> builders = (
           adnlp = OCPBackendBuilders(adnlp_model, adnlp_solution),
           exa = OCPBackendBuilders(exa_model, exa_solution)
       )
(adnlp = OCPBackendBuilders(...), exa = OCPBackendBuilders(...))

julia> docp = create_discretized_ocp(ocp, builders)
DiscretizedOptimalControlProblem{...}(...)
```
"""
function create_discretized_ocp(
    ocp::AbstractOptimizationProblem,
    backend_builders::NamedTuple
)
    return DiscretizedOptimalControlProblem(ocp, backend_builders)
end

"""
$(TYPEDSIGNATURES)

Create a discretized optimal control problem from backend builder pairs.

# Arguments
- `ocp::AbstractOptimizationProblem`: The original optimal control problem
- `backend_pairs::Pair{Symbol,<:OCPBackendBuilders}...`: Pairs of backend symbols and their builders

# Returns
- `DiscretizedOptimalControlProblem`: A DiscretizedOptimalControlProblem instance

# Example
```julia-repl
julia> docp = create_discretized_ocp(
           ocp,
           :adnlp => OCPBackendBuilders(adnlp_model, adnlp_solution),
           :exa => OCPBackendBuilders(exa_model, exa_solution)
       )
DiscretizedOptimalControlProblem{...}(...)
```
"""
function create_discretized_ocp(
    ocp::AbstractOptimizationProblem,
    backend_pairs::Pair{Symbol,<:OCPBackendBuilders}...
)
    return DiscretizedOptimalControlProblem(ocp, backend_pairs...)
end

"""
$(TYPEDSIGNATURES)

Create a discretized optimal control problem with standard ADNLP and ExaModel builders.

# Arguments
- `ocp::AbstractOptimizationProblem`: The original optimal control problem
- `adnlp_model_builder::ADNLPModelBuilder`: Builder for ADNLP models
- `exa_model_builder::ExaModelBuilder`: Builder for ExaModels
- `adnlp_solution_builder::ADNLPSolutionBuilder`: Builder for ADNLP solutions
- `exa_solution_builder::ExaSolutionBuilder`: Builder for ExaModel solutions

# Returns
- `DiscretizedOptimalControlProblem`: A DiscretizedOptimalControlProblem instance

# Example
```julia-repl
julia> docp = create_discretized_ocp(
           ocp,
           adnlp_model_builder, exa_model_builder,
           adnlp_solution_builder, exa_solution_builder
       )
DiscretizedOptimalControlProblem{...}(...)
```
"""
function create_discretized_ocp(
    ocp::AbstractOptimizationProblem,
    adnlp_model_builder::ADNLPModelBuilder,
    exa_model_builder::ExaModelBuilder,
    adnlp_solution_builder::ADNLPSolutionBuilder,
    exa_solution_builder::ExaSolutionBuilder
)
    return DiscretizedOptimalControlProblem(
        ocp,
        adnlp_model_builder,
        exa_model_builder,
        adnlp_solution_builder,
        exa_solution_builder
    )
end

"""
$(TYPEDSIGNATURES)

Add a new backend to an existing discretized problem.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem to modify
- `backend::Symbol`: Symbol identifying the new backend
- `builders::OCPBackendBuilders`: The OCPBackendBuilders for the new backend

# Returns
- `DiscretizedOptimalControlProblem`: The modified DiscretizedOptimalControlProblem

# Example
```julia-repl
julia> docp = add_backend!(docp, :custom, custom_builders)
DiscretizedOptimalControlProblem{...}(...)
```
"""
function add_backend!(
    docp::DiscretizedOptimalControlProblem,
    backend::Symbol,
    builders::OCPBackendBuilders
)
    new_builders = merge(docp.backend_builders, NamedTuple{(backend,)}((builders,)))
    return DiscretizedOptimalControlProblem(docp.optimal_control_problem, new_builders)
end

"""
$(TYPEDSIGNATURES)

Remove a backend from a discretized problem, returning a new instance.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized optimal control problem
- `backend::Symbol`: Symbol identifying the backend to remove

# Returns
- `DiscretizedOptimalControlProblem`: A new DiscretizedOptimalControlProblem without the specified backend

# Example
```julia-repl
julia> docp_without_exa = remove_backend(docp, :exa)
DiscretizedOptimalControlProblem{...}(...)
```
"""
function remove_backend(docp::DiscretizedOptimalControlProblem, backend::Symbol)
    new_builders = Base.structdiff(docp.backend_builders, NamedTuple{(backend,)}(()))
    return DiscretizedOptimalControlProblem(docp.optimal_control_problem, new_builders)
end
