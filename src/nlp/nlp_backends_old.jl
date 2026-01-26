# ------------------------------------------------------------------------------
# Model backends
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ADNLPModels
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the default value for the `show_time` option of [`ADNLPModeler`](@ref).

Default is `false`.
"""
__adnlp_model_show_time() = false

"""
$(TYPEDSIGNATURES)

Return the default automatic differentiation backend for [`ADNLPModeler`](@ref).

Default is `:optimized`.
"""
__adnlp_model_backend() = :optimized

"""
$(TYPEDSIGNATURES)

Return the option specifications for [`ADNLPModeler`](@ref).

Defines options: `show_time` (Bool) and `backend` (Symbol).
"""
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

"""
$(TYPEDSIGNATURES)

Construct an [`ADNLPModeler`](@ref) with the given options.

# Keyword Arguments

- `show_time::Bool`: Whether to show timing information (default: `false`).
- `backend::Symbol`: AD backend to use (default: `:optimized`).

# Returns

- `ADNLPModeler`: A configured modeler instance.
"""
function ADNLPModeler(; kwargs...)
    values, sources = _build_ocp_tool_options(ADNLPModeler; kwargs..., strict_keys=false)
    return ADNLPModeler{typeof(values),typeof(sources)}(values, sources)
end

"""
$(TYPEDSIGNATURES)

Build an ADNLPModel from an optimisation problem and initial guess.
"""
function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem, initial_guess
)::ADNLPModels.ADNLPModel
    vals = _options_values(modeler)
    builder = get_adnlp_model_builder(prob)
    return builder(initial_guess; vals...)
end

"""
$(TYPEDSIGNATURES)

Build an OCP solution from NLP execution statistics using ADNLPModels.
"""
function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem, nlp_solution::SolverCore.AbstractExecutionStats
)
    builder = get_adnlp_solution_builder(prob)
    return builder(nlp_solution)
end

# ------------------------------------------------------------------------------
# ExaModels
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the default floating-point type for [`ExaModeler`](@ref).

Default is `Float64`.
"""
__exa_model_base_type() = Float64

"""
$(TYPEDSIGNATURES)

Return the default execution backend for [`ExaModeler`](@ref).

Default is `nothing` (CPU).
"""
__exa_model_backend() = nothing

"""
$(TYPEDSIGNATURES)

Return the option specifications for [`ExaModeler`](@ref).

Defines options: `base_type`, `minimize`, and `backend`.
"""
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

"""
$(TYPEDSIGNATURES)

Construct an [`ExaModeler`](@ref) with the given options.

# Keyword Arguments

- `base_type::Type{<:AbstractFloat}`: Floating-point type (default: `Float64`).
- `minimize::Bool`: Whether to minimise (default from problem).
- `backend`: Execution backend (default: `nothing` for CPU).

# Returns

- `ExaModeler`: A configured modeler instance.
"""
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

"""
$(TYPEDSIGNATURES)

Build an ExaModel from an optimisation problem and initial guess.
"""
function (modeler::ExaModeler{BaseType})(
    prob::AbstractOptimizationProblem, initial_guess
)::ExaModels.ExaModel{BaseType} where {BaseType<:AbstractFloat}
    vals = _options_values(modeler)
    backend = vals.backend
    builder = get_exa_model_builder(prob)
    return builder(BaseType, initial_guess; backend=backend, vals...)
end

"""
$(TYPEDSIGNATURES)

Build an OCP solution from NLP execution statistics using ExaModels.
"""
function (modeler::ExaModeler)(
    prob::AbstractOptimizationProblem, nlp_solution::SolverCore.AbstractExecutionStats
)
    builder = get_exa_solution_builder(prob)
    return builder(nlp_solution)
end

# ------------------------------------------------------------------------------
# Registration
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Return the symbol identifier for [`ADNLPModeler`](@ref).

Returns `:adnlp`.
"""
get_symbol(::Type{<:ADNLPModeler}) = :adnlp

"""
$(TYPEDSIGNATURES)

Return the symbol identifier for [`ExaModeler`](@ref).

Returns `:exa`.
"""
get_symbol(::Type{<:ExaModeler}) = :exa

"""
$(TYPEDSIGNATURES)

Return the package name for [`ADNLPModeler`](@ref).

Returns `"ADNLPModels"`.
"""
tool_package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"

"""
$(TYPEDSIGNATURES)

Return the package name for [`ExaModeler`](@ref).

Returns `"ExaModels"`.
"""
tool_package_name(::Type{<:ExaModeler}) = "ExaModels"

"""
Tuple of all registered modeler types.

Currently contains `(ADNLPModeler, ExaModeler)`.
"""
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)

"""
$(TYPEDSIGNATURES)

Return the tuple of all registered modeler types.
"""
registered_modeler_types() = REGISTERED_MODELERS

"""
$(TYPEDSIGNATURES)

Return a tuple of symbols for all registered modelers.

Returns `(:adnlp, :exa)`.
"""
modeler_symbols() = Tuple(get_symbol(T) for T in REGISTERED_MODELERS)

"""
$(TYPEDSIGNATURES)

Look up a modeler type from its symbol identifier.

Throws `CTBase.IncorrectArgument` if the symbol is unknown.
"""
function _modeler_type_from_symbol(sym::Symbol)
    for T in REGISTERED_MODELERS
        if get_symbol(T) === sym
            return T
        end
    end
    msg = "Unknown NLP model symbol $(sym). Supported symbols: $(modeler_symbols())."
    throw(CTBase.IncorrectArgument(msg))
end

"""
$(TYPEDSIGNATURES)

Construct a modeler from its symbol identifier.

# Arguments

- `sym::Symbol`: The modeler symbol (`:adnlp` or `:exa`).
- `kwargs...`: Options to pass to the modeler constructor.

# Returns

- An instance of the corresponding modeler type.

# Example

```julia-repl
julia> using CTModels

julia> modeler = CTModels.build_modeler_from_symbol(:adnlp)
```
"""
function build_modeler_from_symbol(sym::Symbol; kwargs...)
    T = _modeler_type_from_symbol(sym)
    return T(; kwargs...)
end
