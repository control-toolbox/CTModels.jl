# ADNLP Modeler
#
# Implementation of ADNLPModeler using the AbstractStrategy contract.
# This modeler converts discretized optimal control problems to ADNLPModels.
#
# Author: CTModels Development Team
# Date: 2026-01-25

# Default option values
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
    ADNLPModeler

Modeler for building ADNLPModels from discretized optimal control problems.

This modeler uses the ADNLPModels.jl package to create NLP models with
automatic differentiation support. It provides configurable options for
timing information and AD backend selection.

# Options
- `show_time::Bool`: Whether to show timing information (default: `false`)
- `backend::Symbol`: AD backend to use (default: `:optimized`)

# Example
```julia
modeler = ADNLPModeler(show_time=true, backend=:forwarddiff)
nlp_model = modeler(problem, initial_guess)
```
"""
struct ADNLPModeler <: AbstractOptimizationModeler
    options::Strategies.StrategyOptions
end

# Strategy identification
Strategies.id(::Type{<:ADNLPModeler}) = :adnlp

# Strategy metadata with option definitions
function Strategies.metadata(::Type{<:ADNLPModeler})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name=:show_time,
            type=Bool,
            default=__adnlp_model_show_time(),
            description="Whether to show timing information while building the ADNLP model"
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Symbol,
            default=__adnlp_model_backend(),
            description="Automatic differentiation backend used by ADNLPModels"
        )
    )
end

# Constructor with option validation
function ADNLPModeler(; kwargs...)
    opts = Strategies.build_strategy_options(
        ADNLPModeler; kwargs...
    )
    return ADNLPModeler(opts)
end

# Access to strategy options
Strategies.options(m::ADNLPModeler) = m.options

# Model building interface
function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ADNLPModels.ADNLPModel
    opts = Strategies.options(modeler)
    
    # Get the appropriate builder for this problem type
    builder = get_adnlp_model_builder(prob)
    
    # Extract raw values from OptionValue wrappers and filter out nothing values
    raw_opts_dict = Dict{Symbol, Any}()
    for (k, v) in pairs(opts.options)
        val = v isa Options.OptionValue ? v.value : v
        if val !== nothing
            raw_opts_dict[k] = val
        end
    end
    raw_opts = NamedTuple(raw_opts_dict)
    
    # Build the ADNLP model passing all options generically
    return builder(initial_guess; raw_opts...)
end

# Solution building interface
function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    # Get the appropriate solution builder for this problem type
    builder = get_adnlp_solution_builder(prob)
    return builder(nlp_solution)
end
