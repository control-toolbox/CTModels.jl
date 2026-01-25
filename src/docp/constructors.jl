# DOCP Constructors
#
# This module provides constructor functions and accessors for DOCP types,
# including helper functions for creating and manipulating discretized optimal
# control problems and their builders.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
    ocp_model(docp::DiscretizedOptimalControlProblem)

Extract the original optimal control problem from a discretized problem.

# Arguments
- `docp`: The discretized optimal control problem

# Returns
- The original optimal control problem

# Example
```julia
ocp = ocp_model(docp)
```
"""
ocp_model(docp::DiscretizedOptimalControlProblem) = docp.optimal_control_problem

"""
    backend_builders(docp::DiscretizedOptimalControlProblem)

Extract the backend builders from a discretized problem.

# Arguments
- `docp`: The discretized optimal control problem

# Returns
- Named tuple of backend builders

# Example
```julia
builders = backend_builders(docp)
adnlp_builder = builders.adnlp
exa_builder = builders.exa
```
"""
backend_builders(docp::DiscretizedOptimalControlProblem) = docp.backend_builders

"""
    get_backend_builder(docp::DiscretizedOptimalControlProblem, backend::Symbol)

Get a specific backend builder from a discretized problem.

# Arguments
- `docp`: The discretized optimal control problem
- `backend`: Symbol identifying the backend (:adnlp, :exa, etc.)

# Returns
- The OCPBackendBuilders for the specified backend

# Throws
- `KeyError` if the backend is not available

# Example
```julia
adnlp_builders = get_backend_builder(docp, :adnlp)
exa_builders = get_backend_builder(docp, :exa)
```
"""
function get_backend_builder(docp::DiscretizedOptimalControlProblem, backend::Symbol)
    return docp.backend_builders[backend]
end

"""
    available_backends(docp::DiscretizedOptimalControlProblem)

Get the list of available backends for a discretized problem.

# Arguments
- `docp`: The discretized optimal control problem

# Returns
- Vector of backend symbols

# Example
```julia
backends = available_backends(docp)
# [:adnlp, :exa]
```
"""
function available_backends(docp::DiscretizedOptimalControlProblem)
    return collect(keys(docp.backend_builders))
end

"""
    has_backend(docp::DiscretizedOptimalControlProblem, backend::Symbol)

Check if a discretized problem has a specific backend available.

# Arguments
- `docp`: The discretized optimal control problem
- `backend`: Symbol identifying the backend

# Returns
- `true` if the backend is available, `false` otherwise

# Example
```julia
if has_backend(docp, :adnlp)
    # Use ADNLP backend
end
```
"""
function has_backend(docp::DiscretizedOptimalControlProblem, backend::Symbol)
    return haskey(docp.backend_builders, backend)
end

"""
    create_discretized_ocp(
        ocp::AbstractOptimalControlProblem,
        backend_builders::NamedTuple
    )

Create a discretized optimal control problem with custom backend builders.

# Arguments
- `ocp`: The original optimal control problem
- `backend_builders`: Named tuple mapping backend symbols to OCPBackendBuilders

# Returns
- A DiscretizedOptimalControlProblem instance

# Example
```julia
builders = (
    adnlp = OCPBackendBuilders(adnlp_model, adnlp_solution),
    exa = OCPBackendBuilders(exa_model, exa_solution)
)
docp = create_discretized_ocp(ocp, builders)
```
"""
function create_discretized_ocp(
    ocp::AbstractOptimizationProblem,
    backend_builders::NamedTuple
)
    return DiscretizedOptimalControlProblem(ocp, backend_builders)
end

"""
    create_discretized_ocp(
        ocp::AbstractOptimizationProblem,
        backend_pairs::Pair{Symbol,<:OCPBackendBuilders}...
    )

Create a discretized optimal control problem from backend builder pairs.

# Arguments
- `ocp`: The original optimal control problem
- `backend_pairs`: Pairs of backend symbols and their builders

# Returns
- A DiscretizedOptimalControlProblem instance

# Example
```julia
docp = create_discretized_ocp(
    ocp,
    :adnlp => OCPBackendBuilders(adnlp_model, adnlp_solution),
    :exa => OCPBackendBuilders(exa_model, exa_solution)
)
```
"""
function create_discretized_ocp(
    ocp::AbstractOptimizationProblem,
    backend_pairs::Pair{Symbol,<:OCPBackendBuilders}...
)
    return DiscretizedOptimalControlProblem(ocp, backend_pairs...)
end

"""
    create_discretized_ocp(
        ocp::AbstractOptimizationProblem,
        adnlp_model_builder::ADNLPModelBuilder,
        exa_model_builder::ExaModelBuilder,
        adnlp_solution_builder::ADNLPSolutionBuilder,
        exa_solution_builder::ExaSolutionBuilder
    )

Create a discretized optimal control problem with standard ADNLP and ExaModel builders.

# Arguments
- `ocp`: The original optimal control problem
- `adnlp_model_builder`: Builder for ADNLP models
- `exa_model_builder`: Builder for ExaModels
- `adnlp_solution_builder`: Builder for ADNLP solutions
- `exa_solution_builder`: Builder for ExaModel solutions

# Returns
- A DiscretizedOptimalControlProblem instance

# Example
```julia
docp = create_discretized_ocp(
    ocp,
    adnlp_model_builder, exa_model_builder,
    adnlp_solution_builder, exa_solution_builder
)
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
    add_backend!(
        docp::DiscretizedOptimalControlProblem,
        backend::Symbol,
        builders::OCPBackendBuilders
    )

Add a new backend to an existing discretized problem.

# Arguments
- `docp`: The discretized optimal control problem to modify
- `backend`: Symbol identifying the new backend
- `builders`: The OCPBackendBuilders for the new backend

# Returns
- The modified DiscretizedOptimalControlProblem

# Example
```julia
docp = add_backend!(docp, :custom, custom_builders)
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
    remove_backend(docp::DiscretizedOptimalControlProblem, backend::Symbol)

Remove a backend from a discretized problem, returning a new instance.

# Arguments
- `docp`: The discretized optimal control problem
- `backend`: Symbol identifying the backend to remove

# Returns
- A new DiscretizedOptimalControlProblem without the specified backend

# Example
```julia
docp_without_exa = remove_backend(docp, :exa)
```
"""
function remove_backend(docp::DiscretizedOptimalControlProblem, backend::Symbol)
    new_builders = Base.structdiff(docp.backend_builders, NamedTuple{(backend,)}(()))
    return DiscretizedOptimalControlProblem(docp.optimal_control_problem, new_builders)
end
