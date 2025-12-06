# ------------------------------------------------------------------------------
# Discretized optimal control problem
# ------------------------------------------------------------------------------
# Helpers
abstract type AbstractOCPSolutionBuilder <: AbstractSolutionBuilder end

struct ADNLPSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end
function (builder::ADNLPSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return builder.f(nlp_solution)
end

struct ExaSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end
function (builder::ExaSolutionBuilder)(nlp_solution::SolverCore.AbstractExecutionStats)
    return builder.f(nlp_solution)
end

struct OCPBackendBuilders{TM<:AbstractModelBuilder,TS<:AbstractOCPSolutionBuilder}
    model::TM
    solution::TS
end

# Problem
struct DiscretizedOptimalControlProblem{TO<:AbstractOptimalControlProblem,TB<:NamedTuple} <:
       AbstractOptimizationProblem
    optimal_control_problem::TO
    backend_builders::TB
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::TO, backend_builders::TB
    ) where {TO<:AbstractOptimalControlProblem,TB<:NamedTuple}
        return new{TO,TB}(optimal_control_problem, backend_builders)
    end
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::AbstractOptimalControlProblem,
        backend_builders::Tuple{Vararg{Pair{Symbol,<:OCPBackendBuilders}}},
    )
        return DiscretizedOptimalControlProblem(
            optimal_control_problem, (; backend_builders...)
        )
    end
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::AbstractOptimalControlProblem,
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