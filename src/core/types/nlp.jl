# ------------------------------------------------------------------------------ #
# NLP backends and optimization problem types
# (tools, builders, modelers, discretized optimal control problem)
# ------------------------------------------------------------------------------ #
abstract type AbstractOCPTool end

struct OptionSpec
    type::Any         # Expected Julia type for the option value, or `missing` if unknown.
    default::Any
    description::Any  # Short English description (String) or `missing` if not documented yet.
end

abstract type AbstractBuilder end
abstract type AbstractModelBuilder <: AbstractBuilder end

struct ADNLPModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

struct ExaModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

abstract type AbstractSolutionBuilder <: AbstractBuilder end

abstract type AbstractOptimizationProblem end

abstract type AbstractOptimizationModeler <: AbstractOCPTool end

struct ADNLPModeler{Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

struct ExaModeler{BaseType<:AbstractFloat,Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

abstract type AbstractOCPSolutionBuilder <: AbstractSolutionBuilder end

struct ADNLPSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end

struct ExaSolutionBuilder{T<:Function} <: AbstractOCPSolutionBuilder
    f::T
end

struct OCPBackendBuilders{TM<:AbstractModelBuilder,TS<:AbstractOCPSolutionBuilder}
    model::TM
    solution::TS
end

struct DiscretizedOptimalControlProblem{TO<:AbstractModel,TB<:NamedTuple} <:
       AbstractOptimizationProblem
    optimal_control_problem::TO
    backend_builders::TB
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::TO, backend_builders::TB
    ) where {TO<:AbstractModel,TB<:NamedTuple}
        return new{TO,TB}(optimal_control_problem, backend_builders)
    end
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::AbstractModel,
        backend_builders::Tuple{Vararg{Pair{Symbol,<:OCPBackendBuilders}}},
    )
        return DiscretizedOptimalControlProblem(
            optimal_control_problem, (; backend_builders...)
        )
    end
    function DiscretizedOptimalControlProblem(
        optimal_control_problem::AbstractModel,
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
