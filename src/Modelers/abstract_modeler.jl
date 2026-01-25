# Abstract Modeler
#
# Defines the AbstractModeler strategy contract for all modeler strategies.
# This extends the AbstractStrategy contract with modeler-specific interfaces.
#
# Author: CTModels Development Team
# Date: 2026-01-25

# Import types from parent modules
# Note: AbstractOptimizationProblem will be available as CTModels.AbstractOptimalControlProblem
# when the module is used in the parent context

"""
    AbstractModeler

Abstract base type for all modeler strategies.

Modeler strategies are responsible for converting discretized optimal control
problems into NLP backend models. They implement the `AbstractStrategy` contract
and provide modeler-specific interfaces for model and solution building.

# Implementation Requirements
All concrete modeler strategies must:
- Implement the `AbstractStrategy` contract (see Strategies module)
- Provide callable interfaces for model building
- Provide callable interfaces for solution building
- Define strategy metadata with option specifications

# Example
```julia
struct MyModelerStrategy <: AbstractModeler
    options::Strategies.StrategyOptions
end

Strategies.id(::Type{<:MyModelerStrategy}) = :my_modeler

function (modeler::MyModelerStrategy)(
    prob::CTModels.AbstractOptimalControlProblem, 
    initial_guess
)
    # Build NLP model from problem and initial guess
    return nlp_model
end
```
"""
abstract type AbstractModeler <: Strategies.AbstractStrategy end

"""
    (modeler::AbstractModeler)(prob::CTModels.AbstractOptimalControlProblem, initial_guess)

Build an NLP model from a discretized optimal control problem and initial guess.

# Arguments
- `modeler`: The modeler strategy instance
- `prob`: The discretized optimal control problem
- `initial_guess`: Initial guess for optimization variables

# Returns
- An NLP model compatible with the target backend (e.g., ADNLPModel, ExaModel)

# Throws
- `CTBase.NotImplemented` if not implemented by concrete type
"""
function (modeler::AbstractModeler)(
    prob, 
    initial_guess
)
    throw(CTBase.NotImplemented(
        "Model building not implemented for $(typeof(modeler))"
    ))
end

"""
    (modeler::AbstractModeler)(prob::CTModels.AbstractOptimalControlProblem, nlp_solution)

Build a solution object from a discretized optimal control problem and NLP solution.

# Arguments
- `modeler`: The modeler strategy instance
- `prob`: The discretized optimal control problem
- `nlp_solution`: Solution from NLP solver

# Returns
- A solution object appropriate for the problem type

# Throws
- `CTBase.NotImplemented` if not implemented by concrete type
"""
function (modeler::AbstractModeler)(
    prob,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    throw(CTBase.NotImplemented(
        "Solution building not implemented for $(typeof(modeler))"
    ))
end
