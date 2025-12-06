# ------------------------------------------------------------------------------
# NLP Model and Solution builders
# ------------------------------------------------------------------------------
function build_model(
    prob::AbstractOptimizationProblem, initial_guess, modeler::AbstractOptimizationModeler
)
    return modeler(prob, initial_guess)
end

function nlp_model(
    prob::DiscretizedOptimalControlProblem,
    initial_guess,
    modeler::AbstractOptimizationModeler,
)::NLPModels.AbstractNLPModel
    return build_model(prob, initial_guess, modeler)
end

function build_solution(
    prob::AbstractOptimizationProblem, model_solution, modeler::AbstractOptimizationModeler
)
    return modeler(prob, model_solution)
end

function ocp_solution(
    docp::DiscretizedOptimalControlProblem,
    model_solution::SolverCore.AbstractExecutionStats,
    modeler::AbstractOptimizationModeler,
)::AbstractOptimalControlSolution
    return build_solution(docp, model_solution, modeler)
end