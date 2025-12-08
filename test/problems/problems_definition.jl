# Helper optimization problem and solution-builder types used by benchmark test problems.
# Helper types
abstract type AbstractNLPSolutionBuilder <: CTModels.AbstractSolutionBuilder end
struct ADNLPSolutionBuilder <: AbstractNLPSolutionBuilder end
struct ExaSolutionBuilder <: AbstractNLPSolutionBuilder end

#
struct OptimizationProblem <: CTModels.AbstractOptimizationProblem
    build_adnlp_model::CTModels.ADNLPModelBuilder
    build_exa_model::CTModels.ExaModelBuilder
    adnlp_solution_builder::ADNLPSolutionBuilder
    exa_solution_builder::ExaSolutionBuilder
end

function CTModels.get_adnlp_model_builder(prob::OptimizationProblem)
    return prob.build_adnlp_model
end

function CTModels.get_exa_model_builder(prob::OptimizationProblem)
    return prob.build_exa_model
end

function (builder::ADNLPSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return nlp_solution
end

function (builder::ExaSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return nlp_solution
end

function CTModels.get_adnlp_solution_builder(prob::OptimizationProblem)
    return prob.adnlp_solution_builder
end

function CTModels.get_exa_solution_builder(prob::OptimizationProblem)
    return prob.exa_solution_builder
end

#
struct DummyProblem <: CTModels.AbstractOptimizationProblem end