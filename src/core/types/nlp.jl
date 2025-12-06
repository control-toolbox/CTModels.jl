# ------------------------------------------------------------------------------ #
# NLP backends and optimization problem types
# (tools, builders, modelers, discretized optimal control problem)
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for configurable tools in CTModels (backends, discretizers,
solvers, etc.).

Subtypes of `AbstractOCPTool` are expected to follow a common options
interface so they can be configured and introspected in a uniform way.

# Interface contract

Concrete subtypes `T <: AbstractOCPTool` are expected to:

- store two fields
  - `options_values::NamedTuple`  — current option values.
  - `options_sources::NamedTuple` — provenance for each option
    (`:ct_default` or `:user`).
- optionally provide option metadata by specializing
  [`_option_specs(::Type{T})`](@ref), returning a `NamedTuple` of
  [`OptionSpec`](@ref) values.
- typically define a keyword-only constructor
  `T(; kwargs...)` implemented using [`_build_ocp_tool_options`](@ref), so
  that user-supplied keywords are validated and merged with tool defaults.

Most helper functions in the options schema (see `nlp/options_schema.jl`)
operate generically on any subtype that satisfies this contract.
"""
abstract type AbstractOCPTool end

"""
$(TYPEDEF)

Metadata for a single named option of an [`AbstractOCPTool`](@ref).

Each field describes one aspect of the option:

- `type`        — expected Julia type for the option value, or `missing` if
  no static type information is available.
- `default`     — default value when the option is not supplied by the user,
  or `missing` if there is no default.
- `description` — short human-readable description of the option, or
  `missing` if it is not yet documented.

Instances of `OptionSpec` are typically returned from `_option_specs(::Type)`
in a `NamedTuple`, one field per option name.
"""
struct OptionSpec
    type::Any         # Expected Julia type for the option value, or `missing` if unknown.
    default::Any
    description::Any  # Short English description (String) or `missing` if not documented yet.
end

"""
$(TYPEDEF)

Common supertype for builder objects used in the NLP back-end
infrastructure.

`AbstractBuilder` itself does not impose a concrete calling interface;
specialized subtypes such as [`AbstractModelBuilder`](@ref) and
[`AbstractOCPSolutionBuilder`](@ref) define looser contracts that are
documented on their own abstract types and concrete implementations.
"""
abstract type AbstractBuilder end

"""
$(TYPEDEF)

Abstract base type for builders that construct NLP back-end models from
an [`AbstractOptimizationProblem`](@ref).

Concrete subtypes (for example [`ADNLPModelBuilder`](@ref) and
[`ExaModelBuilder`](@ref)) are expected to be callable objects that
encapsulate the logic for building a model for a specific NLP back-end.
The exact call signature is back-end dependent and therefore not fixed at
the level of `AbstractModelBuilder`.
"""
abstract type AbstractModelBuilder <: AbstractBuilder end

"""
$(TYPEDEF)

Builder for constructing back-end NLP models from an
[`AbstractOptimizationProblem`](@ref).

Concrete implementations such as [`ADNLPModelBuilder`](@ref) and
[`ExaModelBuilder`](@ref) are typically returned by high-level
optimization modeling interfaces, and are not created directly by users.
"""
struct ADNLPModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

"""
$(TYPEDEF)

Builder for constructing ExaModels-based NLP models from an
[`AbstractOptimizationProblem`](@ref).

See also: [`ADNLPModelBuilder`](@ref).
"""
struct ExaModelBuilder{T<:Function} <: AbstractModelBuilder
    f::T
end

"""
$(TYPEDEF)

Abstract base type for builders that transform NLP solutions into other
representations (for example, solutions of an optimal control problem).

Subtypes are expected to be callable, but the abstract type does not fix
the argument types. More specific contracts are documented on
[`AbstractOCPSolutionBuilder`](@ref) and related concrete types.
"""
abstract type AbstractSolutionBuilder <: AbstractBuilder end

"""
$(TYPEDEF)

Abstract base type for optimization problems built from optimal control
problems.

Subtypes of `AbstractOptimizationProblem` are typically paired with
[`AbstractModelBuilder`](@ref) and [`AbstractSolutionBuilder`](@ref)
implementations that know how to construct and interpret NLP back-end
models and solutions.
"""
abstract type AbstractOptimizationProblem end

"""
$(TYPEDEF)

Abstract base type for NLP modelers built on top of
[`AbstractOptimizationProblem`](@ref).

Subtypes of `AbstractOptimizationModeler` are also `AbstractOCPTool`s
and therefore follow the generic options interface: they store
`options_values` and `options_sources` fields and are typically
constructed using [`_build_ocp_tool_options`](@ref).

Concrete modelers such as [`ADNLPModeler`](@ref) and
[`ExaModeler`](@ref) dispatch on an `AbstractOptimizationProblem` to
build NLP models and map NLP solutions back to OCP solutions.
"""
abstract type AbstractOptimizationModeler <: AbstractOCPTool end

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOptimizationModeler`](@ref).

Concrete modelers are expected to specialize this call to build an NLP
model from an [`AbstractOptimizationProblem`](@ref) and an initial
guess. The default implementation throws a
`CTBase.NotImplemented` error.
"""
function (modeler::AbstractOptimizationModeler)(
    prob::AbstractOptimizationProblem,
    initial_guess;
    kwargs...,
)
    throw(
        CTBase.NotImplemented(
            "model-building call not implemented for $(typeof(modeler))",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOptimizationModeler`](@ref).

Concrete modelers may specialize this call to map an NLP back-end
solution (for example `SolverCore.AbstractExecutionStats`) back to a
solution associated with the original
[`AbstractOptimizationProblem`](@ref). The default implementation throws
`CTBase.NotImplemented`.
"""
function (modeler::AbstractOptimizationModeler)(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats;
    kwargs...,
)
    throw(
        CTBase.NotImplemented(
            "solution-building call not implemented for $(typeof(modeler))",
        ),
    )
end

"""
$(TYPEDEF)

Concrete [`AbstractOptimizationModeler`](@ref) based on
`ADNLPModels.jl`.

`ADNLPModeler` implements the [`AbstractOCPTool`](@ref) options
interface: it stores `options_values` and `options_sources`, defines an
`_option_specs` specialization describing its options, and is
constructed via [`_build_ocp_tool_options`](@ref).
"""
struct ADNLPModeler{Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

"""
$(TYPEDEF)

Concrete [`AbstractOptimizationModeler`](@ref) based on `ExaModels.jl`.

Like [`ADNLPModeler`](@ref), this type follows the
[`AbstractOCPTool`](@ref) options interface and is configured via
[`_build_ocp_tool_options`](@ref). It additionally fixes a
`BaseType<:AbstractFloat` parameter that controls the floating-point
type of the underlying ExaModel.
"""
struct ExaModeler{BaseType<:AbstractFloat,Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

"""
$(TYPEDEF)

Abstract base type for builders that turn NLP back-end execution
statistics into objects associated with a discretized optimal control
problem (for example, an OCP solution or intermediate representation).

Concrete subtypes are expected to be callable on a
`SolverCore.AbstractExecutionStats` value. A generic fallback method is
provided (see below) that throws `CTBase.NotImplemented` if a concrete
builder does not implement the call.

See also: [`ADNLPSolutionBuilder`](@ref), [`ExaSolutionBuilder`](@ref).
"""
abstract type AbstractOCPSolutionBuilder <: AbstractSolutionBuilder end

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOCPSolutionBuilder`](@ref).

Concrete OCP solution builders are expected to specialize this method to
convert NLP execution statistics into an appropriate representation. The
default implementation throws a `CTBase.NotImplemented` error.
"""
function (builder::AbstractOCPSolutionBuilder)(
    nlp_solution::SolverCore.AbstractExecutionStats;
    kwargs...,
)
    throw(
        CTBase.NotImplemented(
            "OCP solution builder not implemented for $(typeof(builder))",
        ),
    )
end

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
