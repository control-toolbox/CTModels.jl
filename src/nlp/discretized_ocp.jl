# ------------------------------------------------------------------------------ #
# Discretized optimal control problem
#
# This file implements helper methods that operate on
# [`DiscretizedOptimalControlProblem`](@ref) and its associated
# back-end builders (`ADNLPSolutionBuilder`, `ExaSolutionBuilder`,
# `OCPBackendBuilders`), which are part of the
# [`AbstractOCPTool`](@ref)-based optimization interface.
# ------------------------------------------------------------------------------ #
# Helpers
"""
$(TYPEDSIGNATURES)

Invoke the ADNLPModels solution builder to convert NLP execution statistics
into an optimal control solution.
"""
function (builder::ADNLPSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return builder.f(nlp_solution)
end

"""
$(TYPEDSIGNATURES)

Invoke the ExaModels solution builder to convert NLP execution statistics
into an optimal control solution.
"""
function (builder::ExaSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return builder.f(nlp_solution)
end

# Problem
"""
$(TYPEDSIGNATURES)

Return the original optimal control problem from a discretised problem.

# Arguments

- `prob::DiscretizedOptimalControlProblem`: The discretised problem.

# Returns

- The underlying [`Model`](@ref) (optimal control problem).
"""
function ocp_model(prob::DiscretizedOptimalControlProblem)
    return prob.optimal_control_problem
end

"""
$(TYPEDSIGNATURES)

Retrieve the ADNLPModels model builder from a discretised problem.

Throws `ArgumentError` if no `:adnlp` backend is registered.
"""
function get_adnlp_model_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :adnlp
            return builders.model
        end
    end
    throw(ArgumentError("no :adnlp model builder registered"))
end

"""
$(TYPEDSIGNATURES)

Retrieve the ExaModels model builder from a discretised problem.

Throws `ArgumentError` if no `:exa` backend is registered.
"""
function get_exa_model_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :exa
            return builders.model
        end
    end
    throw(ArgumentError("no :exa model builder registered"))
end

"""
$(TYPEDSIGNATURES)

Retrieve the ADNLPModels solution builder from a discretised problem.

Throws `ArgumentError` if no `:adnlp` backend is registered.
"""
function get_adnlp_solution_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :adnlp
            return builders.solution
        end
    end
    throw(ArgumentError("no :adnlp solution builder registered"))
end

"""
$(TYPEDSIGNATURES)

Retrieve the ExaModels solution builder from a discretised problem.

Throws `ArgumentError` if no `:exa` backend is registered.
"""
function get_exa_solution_builder(prob::DiscretizedOptimalControlProblem)
    for (name, builders) in pairs(prob.backend_builders)
        if name === :exa
            return builders.solution
        end
    end
    throw(ArgumentError("no :exa solution builder registered"))
end