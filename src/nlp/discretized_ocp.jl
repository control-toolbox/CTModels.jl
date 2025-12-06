# ------------------------------------------------------------------------------
# Discretized optimal control problem
# ------------------------------------------------------------------------------
# Helpers
function (builder::ADNLPSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return builder.f(nlp_solution)
end

function (builder::ExaSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return builder.f(nlp_solution)
end

# Problem
function ocp_model(prob::DiscretizedOptimalControlProblem)
    return prob.optimal_control_problem
end

function get_adnlp_model_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :adnlp
            return builders.model
        end
    end
    throw(ArgumentError("no :adnlp model builder registered"))
end

function get_exa_model_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :exa
            return builders.model
        end
    end
    throw(ArgumentError("no :exa model builder registered"))
end

function get_adnlp_solution_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :adnlp
            return builders.solution
        end
    end
    throw(ArgumentError("no :adnlp solution builder registered"))
end

function get_exa_solution_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :exa
            return builders.solution
        end
    end
    throw(ArgumentError("no :exa solution builder registered"))
end