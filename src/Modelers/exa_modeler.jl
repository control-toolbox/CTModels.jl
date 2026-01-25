# Exa Modeler Strategy
#
# Implementation of ExaModelerStrategy using the new AbstractStrategy contract.
# This strategy converts discretized optimal control problems to ExaModels.
#
# Author: CTModels Development Team
# Date: 2026-01-25

# Note: AbstractOptimizationProblem will be available as CTModels.AbstractOptimalControlProblem
# when the module is used in the parent context

"""
    ExaModelerStrategy{BaseType<:AbstractFloat}

Strategy for building ExaModels from discretized optimal control problems.

This strategy uses the ExaModels.jl package to create NLP models with
support for various execution backends (CPU, GPU) and floating-point types.

# Type Parameters
- `BaseType`: Floating-point type for the model (default: `Float64`)

# Options
- `base_type::Type{<:AbstractFloat}`: Floating-point type (default: `Float64`)
- `minimize::Bool`: Whether to minimize (default: `missing` from problem)
- `backend`: Execution backend (default: `nothing` for CPU)

# Example
```julia
modeler = ExaModelerStrategy{Float32}(backend=CUDABackend())
nlp_model = modeler(problem, initial_guess)
```
"""
struct ExaModelerStrategy{BaseType<:AbstractFloat} <: AbstractModeler
    options::Strategies.StrategyOptions
end

# Strategy identification
Strategies.id(::Type{<:ExaModelerStrategy}) = :exa

# Strategy metadata with option definitions
function Strategies.metadata(::Type{<:ExaModelerStrategy})
    return Strategies.StrategyMetadata(
        Options.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=Float64,
            description="Base floating-point type used by ExaModels"
        ),
        Options.OptionDefinition(;
                name=:minimize,
                type=Union{Bool, Nothing},
                default=nothing,
                description="Whether to minimize (true) or maximize (false) the objective"
            ),
        Options.OptionDefinition(;
                name=:backend,
                type=Any,
                default=nothing,
                description="Execution backend for ExaModels (CPU, GPU, etc.)"
            )
    )
end

# Constructor with type parameter handling
function ExaModelerStrategy(; kwargs...)
    opts = Strategies.build_strategy_options(
        ExaModelerStrategy; kwargs...
    )
    
    # Extract base_type to set as type parameter
    BaseType = opts[:base_type]
    
    # Filter out base_type from stored options (it's now in the type)
    filtered_opts_nt = Strategies.filter_options(opts.options, (:base_type,))
    filtered_opts = Strategies.StrategyOptions(filtered_opts_nt)
    
    return ExaModelerStrategy{BaseType}(filtered_opts)
end

# Convenience constructor with explicit type
function ExaModelerStrategy{BaseType}(; kwargs...) where {BaseType<:AbstractFloat}
    # Set base_type in kwargs if not provided
    if !haskey(kwargs, :base_type)
        kwargs = (kwargs..., base_type=BaseType)
    end
    
    opts = Strategies.build_strategy_options(
        ExaModelerStrategy{BaseType}; kwargs...
    )
    
    # Filter out base_type from stored options
    filtered_opts_nt = Strategies.filter_options(opts.options, (:base_type,))
    filtered_opts = Strategies.StrategyOptions(filtered_opts_nt)
    
    return ExaModelerStrategy{BaseType}(filtered_opts)
end

# Access to strategy options
Strategies.options(m::ExaModelerStrategy) = m.options

# Model building interface
function (modeler::ExaModelerStrategy{BaseType})(
    prob,
    initial_guess
)::ExaModels.ExaModel{BaseType} where {BaseType}
    opts = Strategies.options(modeler)
    backend = opts[:backend]
    minimize = opts[:minimize]
    
    # Get the appropriate builder for this problem type
    builder = get_exa_model_builder(prob)
    
    # Build the ExaModel with extracted options and type parameter
    return builder(BaseType, initial_guess; backend=backend, minimize=minimize)
end

# Solution building interface
function (modeler::ExaModelerStrategy)(
    prob,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    # Get the appropriate solution builder for this problem type
    builder = get_exa_solution_builder(prob)
    return builder(nlp_solution)
end
