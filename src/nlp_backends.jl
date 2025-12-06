# ------------------------------------------------------------------------------
# Model backends
# ------------------------------------------------------------------------------
abstract type AbstractOptimizationModeler <: AbstractOCPTool end

# ------------------------------------------------------------------------------
# ADNLPModels
# ------------------------------------------------------------------------------
struct ADNLPModeler{Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

__adnlp_model_show_time() = false
__adnlp_model_backend() = :optimized

function _option_specs(::Type{<:ADNLPModeler})
    return (
        show_time=OptionSpec(;
            type=Bool,
            default=__adnlp_model_show_time(),
            description="Whether to show timing information while building the ADNLP model.",
        ),
        backend=OptionSpec(;
            type=Symbol,
            default=__adnlp_model_backend(),
            description="Automatic differentiation backend used by ADNLPModels.",
        ),
    )
end

function ADNLPModeler(; kwargs...)
    values, sources = _build_ocp_tool_options(ADNLPModeler; kwargs..., strict_keys=false)
    return ADNLPModeler{typeof(values),typeof(sources)}(values, sources)
end

function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem, initial_guess
)::ADNLPModels.ADNLPModel
    vals = _options_values(modeler)
    builder = get_adnlp_model_builder(prob)
    return builder(initial_guess; vals...)
end

function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem, nlp_solution::SolverCore.AbstractExecutionStats
)
    builder = get_adnlp_solution_builder(prob)
    return builder(nlp_solution)
end

# ------------------------------------------------------------------------------
# ExaModels
# ------------------------------------------------------------------------------
struct ExaModeler{BaseType<:AbstractFloat,Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

__exa_model_base_type() = Float64
__exa_model_backend() = nothing

function _option_specs(::Type{<:ExaModeler})
    return (
        base_type=OptionSpec(;
            type=Type{<:AbstractFloat},
            default=__exa_model_base_type(),
            description="Base floating-point type used by ExaModels.",
        ),
        minimize=OptionSpec(;
            type=Bool,
            default=missing,
            description="Whether to minimize (true) or maximize (false) the objective.",
        ),
        backend=OptionSpec(;
            type=Union{Nothing,KernelAbstractions.Backend},
            default=__exa_model_backend(),
            description="Execution backend for ExaModels (CPU, GPU, etc.).",
        ),
    )
end

function ExaModeler(; kwargs...)
    values, sources = _build_ocp_tool_options(ExaModeler; kwargs..., strict_keys=true)
    BaseType = values.base_type

    # base_type is only needed to fix the type parameter; it does not need to
    # remain part of the exposed options NamedTuples.
    filtered_vals = _filter_options(values, (:base_type,))
    filtered_srcs = _filter_options(sources, (:base_type,))

    return ExaModeler{BaseType,typeof(filtered_vals),typeof(filtered_srcs)}(
        filtered_vals, filtered_srcs
    )
end

function (modeler::ExaModeler{BaseType})(
    prob::AbstractOptimizationProblem, initial_guess
)::ExaModels.ExaModel{BaseType} where {BaseType<:AbstractFloat}
    vals = _options_values(modeler)
    backend = vals.backend
    builder = get_exa_model_builder(prob)
    return builder(BaseType, initial_guess; backend=backend, vals...)
end

function (modeler::ExaModeler)(
    prob::AbstractOptimizationProblem, nlp_solution::SolverCore.AbstractExecutionStats
)
    builder = get_exa_solution_builder(prob)
    return builder(nlp_solution)
end

# ------------------------------------------------------------------------------
# Registration
# ------------------------------------------------------------------------------

get_symbol(::Type{<:ADNLPModeler}) = :adnlp
get_symbol(::Type{<:ExaModeler}) = :exa

tool_package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
tool_package_name(::Type{<:ExaModeler}) = "ExaModels"

const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)

registered_modeler_types() = REGISTERED_MODELERS

modeler_symbols() = Tuple(get_symbol(T) for T in REGISTERED_MODELERS)

function _modeler_type_from_symbol(sym::Symbol)
    for T in REGISTERED_MODELERS
        if get_symbol(T) === sym
            return T
        end
    end
    msg = "Unknown NLP model symbol $(sym). Supported symbols: $(modeler_symbols())."
    throw(CTBase.IncorrectArgument(msg))
end

function build_modeler_from_symbol(sym::Symbol; kwargs...)
    T = _modeler_type_from_symbol(sym)
    return T(; kwargs...)
end