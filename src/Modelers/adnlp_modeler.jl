# ADNLP Modeler Strategy
#
# Implementation of ADNLPModelerStrategy using the new AbstractStrategy contract.
# This strategy converts discretized optimal control problems to ADNLPModels.
#
# Author: CTModels Development Team
# Date: 2026-01-25

# Note: AbstractOptimizationProblem will be available as CTModels.AbstractOptimalControlProblem
# when the module is used in the parent context

"""
    ADNLPModelerStrategy

Strategy for building ADNLPModels from discretized optimal control problems.

This strategy uses the ADNLPModels.jl package to create NLP models with
automatic differentiation support. It provides configurable options for
timing information and AD backend selection.

# Options
- `show_time::Bool`: Whether to show timing information (default: `false`)
- `backend::Symbol`: AD backend to use (default: `:optimized`)

# Example
```julia
modeler = ADNLPModelerStrategy(show_time=true, backend=:forwarddiff)
nlp_model = modeler(problem, initial_guess)
```
"""
struct ADNLPModelerStrategy <: AbstractModeler
    options::Strategies.StrategyOptions
end

# Strategy identification
Strategies.id(::Type{<:ADNLPModelerStrategy}) = :adnlp

# Strategy metadata with option definitions
function Strategies.metadata(::Type{<:ADNLPModelerStrategy})
    return Strategies.StrategyMetadata(
        Options.OptionDefinition(;
            name=:show_time,
            type=Bool,
            default=false,
            description="Whether to show timing information while building the ADNLP model"
        ),
        Options.OptionDefinition(;
            name=:backend,
            type=Symbol,
            default=:optimized,
            description="Automatic differentiation backend used by ADNLPModels"
        )
    )
end

# Constructor with option validation
function ADNLPModelerStrategy(; kwargs...)
    opts = Strategies.build_strategy_options(
        ADNLPModelerStrategy; kwargs...
    )
    return ADNLPModelerStrategy(opts)
end

# Access to strategy options
Strategies.options(m::ADNLPModelerStrategy) = m.options

# Model building interface
function (modeler::ADNLPModelerStrategy)(
    prob,
    initial_guess
)::ADNLPModels.ADNLPModel
    opts = Strategies.options(modeler)
    show_time = opts[:show_time]
    backend = opts[:backend]
    
    # Get the appropriate builder for this problem type
    builder = get_adnlp_model_builder(prob)
    
    # Build the ADNLP model with extracted options
    return builder(initial_guess; show_time=show_time, backend=backend)
end

# Solution building interface
function (modeler::ADNLPModelerStrategy)(
    prob,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    # Get the appropriate solution builder for this problem type
    builder = get_adnlp_solution_builder(prob)
    return builder(nlp_solution)
end
