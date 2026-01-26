# Exa Modeler
#
# Implementation of ExaModeler using the AbstractStrategy contract.
# This modeler converts discretized optimal control problems to ExaModels.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
    ExaModeler{BaseType<:AbstractFloat}

Modeler for building ExaModels from discretized optimal control problems.

This modeler uses the ExaModels.jl package to create NLP models with
support for various execution backends (CPU, GPU) and floating-point types.

# Type Parameters
- `BaseType`: Floating-point type for the model (default: `Float64`)

# Options
- `base_type::Type{<:AbstractFloat}`: Floating-point type (default: `Float64`)
- `minimize::Union{Bool, Nothing}`: Whether to minimize (default: `nothing` from problem)
- `backend`: Execution backend (default: `nothing` for CPU)

# Example
```julia
modeler = ExaModeler{Float32}(backend=CUDABackend())
nlp_model = modeler(problem, initial_guess)
```
"""
struct ExaModeler{BaseType<:AbstractFloat} <: AbstractOptimizationModeler
    options::Strategies.StrategyOptions
end

# Strategy identification
Strategies.id(::Type{<:ExaModeler}) = :exa

# Strategy metadata with option definitions
function Strategies.metadata(::Type{<:ExaModeler})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=Float64,
            description="Base floating-point type used by ExaModels"
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Union{Bool, Nothing},
            default=nothing,
            description="Whether to minimize (true) or maximize (false) the objective"
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Any,
            default=nothing,
            description="Execution backend for ExaModels (CPU, GPU, etc.)"
        )
    )
end

# Constructor with type parameter handling
function ExaModeler(; kwargs...)
    opts = Strategies.build_strategy_options(
        ExaModeler; kwargs...
    )
    
    # Extract base_type to set as type parameter
    BaseType = opts[:base_type]
    
    # Filter out base_type from stored options (it's now in the type)
    filtered_opts_nt = Strategies.filter_options(opts.options, (:base_type,))
    filtered_opts = Strategies.StrategyOptions(filtered_opts_nt)
    
    return ExaModeler{BaseType}(filtered_opts)
end

# Convenience constructor with explicit type
function ExaModeler{BaseType}(; kwargs...) where {BaseType<:AbstractFloat}
    # Set base_type in kwargs if not provided
    if !haskey(kwargs, :base_type)
        kwargs = (kwargs..., base_type=BaseType)
    end
    
    opts = Strategies.build_strategy_options(
        ExaModeler{BaseType}; kwargs...
    )
    
    # Filter out base_type from stored options
    filtered_opts_nt = Strategies.filter_options(opts.options, (:base_type,))
    filtered_opts = Strategies.StrategyOptions(filtered_opts_nt)
    
    return ExaModeler{BaseType}(filtered_opts)
end

# Access to strategy options
Strategies.options(m::ExaModeler) = m.options

# Model building interface
function (modeler::ExaModeler{BaseType})(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ExaModels.ExaModel{BaseType} where {BaseType<:AbstractFloat}
    opts = Strategies.options(modeler)
    
    # Get the appropriate builder for this problem type
    builder = get_exa_model_builder(prob)
    
    # Extract raw values from OptionValue wrappers and filter out nothing values
    raw_opts_dict = Dict{Symbol, Any}()
    for (k, v) in pairs(opts.options)
        val = v isa Options.OptionValue ? v.value : v
        if val !== nothing
            raw_opts_dict[k] = val
        end
    end
    raw_opts = NamedTuple(raw_opts_dict)
    
    # Build the ExaModel passing BaseType and all options generically
    return builder(BaseType, initial_guess; raw_opts...)
end

# Solution building interface
function (modeler::ExaModeler{BaseType})(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats
) where {BaseType<:AbstractFloat}
    # Get the appropriate solution builder for this problem type
    builder = get_exa_solution_builder(prob)
    return builder(nlp_solution)
end
