# ------------------------------------------------------------------------------
# NLP Model and Solution builders
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Build an NLP model from an optimisation problem using the specified modeler.

# Arguments

- `prob::AbstractOptimizationProblem`: The optimisation problem.
- `initial_guess`: Initial guess for the NLP solver.
- `modeler::AbstractOptimizationModeler`: The modeler (e.g., `ADNLPModeler`, `ExaModeler`).

# Returns

- An NLP model suitable for the chosen backend.
"""
function build_model(
    prob::AbstractOptimizationProblem, initial_guess, modeler::AbstractOptimizationModeler
)
    return modeler(prob, initial_guess)
end

"""
$(TYPEDSIGNATURES)

Build an NLP model from a discretised optimal control problem.

# Arguments

- `prob::DiscretizedOptimalControlProblem`: The discretised OCP.
- `initial_guess`: Initial guess for the NLP solver.
- `modeler::AbstractOptimizationModeler`: The modeler to use.

# Returns

- `NLPModels.AbstractNLPModel`: The NLP model.
"""
function nlp_model(
    prob::DiscretizedOptimalControlProblem,
    initial_guess,
    modeler::AbstractOptimizationModeler,
)::NLPModels.AbstractNLPModel
    return build_model(prob, initial_guess, modeler)
end

"""
$(TYPEDSIGNATURES)

Build a solution from NLP execution statistics using the specified modeler.

# Arguments

- `prob::AbstractOptimizationProblem`: The optimisation problem.
- `model_solution`: NLP solver output (execution statistics).
- `modeler::AbstractOptimizationModeler`: The modeler used for building.

# Returns

- A solution object appropriate for the problem type.
"""
function build_solution(
    prob::AbstractOptimizationProblem, model_solution, modeler::AbstractOptimizationModeler
)
    return modeler(prob, model_solution)
end

"""
$(TYPEDSIGNATURES)

Build an optimal control solution from NLP execution statistics.

# Arguments

- `docp::DiscretizedOptimalControlProblem`: The discretised OCP.
- `model_solution::SolverCore.AbstractExecutionStats`: NLP solver output.
- `modeler::AbstractOptimizationModeler`: The modeler used.

# Returns

- `AbstractOptimalControlSolution`: The OCP solution.
"""
function ocp_solution(
    docp::DiscretizedOptimalControlProblem,
    model_solution::SolverCore.AbstractExecutionStats,
    modeler::AbstractOptimizationModeler,
)::AbstractOptimalControlSolution
    return build_solution(docp, model_solution, modeler)
end