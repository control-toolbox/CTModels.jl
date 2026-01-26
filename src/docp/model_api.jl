# DOCP Model API
#
# Specific API for building NLP models and solutions from DiscretizedOptimalControlProblem.
# These functions provide convenient wrappers for DOCP-specific operations.
#
# Author: CTModels Development Team
# Date: 2026-01-26

"""
$(TYPEDSIGNATURES)

Build an NLP model from a discretized optimal control problem.

This is a convenience wrapper around `build_model` that provides explicit
typing for `DiscretizedOptimalControlProblem`.

# Arguments
- `prob::DiscretizedOptimalControlProblem`: The discretized OCP
- `initial_guess`: Initial guess for the NLP solver
- `modeler`: The modeler to use (e.g., ADNLPModeler, ExaModeler)

# Returns
- `NLPModels.AbstractNLPModel`: The NLP model

# Example
```julia-repl
julia> nlp = nlp_model(docp, initial_guess, modeler)
ADNLPModel(...)
```
"""
function nlp_model(
    prob::DiscretizedOptimalControlProblem,
    initial_guess,
    modeler
)::NLPModels.AbstractNLPModel
    return build_model(prob, initial_guess, modeler)
end

"""
$(TYPEDSIGNATURES)

Build an optimal control solution from NLP execution statistics.

This is a convenience wrapper around `build_solution` that provides explicit
typing for `DiscretizedOptimalControlProblem` and ensures the return type
is an optimal control solution.

# Arguments
- `docp::DiscretizedOptimalControlProblem`: The discretized OCP
- `model_solution::SolverCore.AbstractExecutionStats`: NLP solver output
- `modeler`: The modeler used for building

# Returns
- `AbstractOptimalControlSolution`: The OCP solution

# Example
```julia-repl
julia> solution = ocp_solution(docp, nlp_stats, modeler)
OptimalControlSolution(...)
```
"""
function ocp_solution(
    docp::DiscretizedOptimalControlProblem,
    model_solution::SolverCore.AbstractExecutionStats,
    modeler
)
    return build_solution(docp, model_solution, modeler)
end
