# Exa Modeler
#
# Implementation of ExaModeler using the AbstractStrategy contract.
# This modeler converts discretized optimal control problems to ExaModels.
#
# Author: CTModels Development Team
# Date: 2026-01-25

# Default option values
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

# NOTE: GPU options removed - not relevant for current implementation
# __exa_model_auto_detect_gpu() = true
# __exa_model_gpu_preference() = :cuda
# __exa_model_precision_mode() = :standard

"""
    ExaModeler

Modeler for building ExaModels from discretized optimal control problems.

This modeler uses the ExaModels.jl package to create NLP models with
support for various execution backends (CPU, GPU) and floating-point types.

# Options
- `base_type::Type{<:AbstractFloat}`: Floating-point type (default: `Float64`)
- `backend`: Execution backend (default: `nothing` for CPU)

# Example
```julia
# Basic usage
modeler = ExaModeler()

# With specific type
modeler = ExaModeler(base_type=Float32)

# With backend
modeler = ExaModeler(backend=CUDABackend())
```
"""
struct ExaModeler <: AbstractOptimizationModeler
    options::Strategies.StrategyOptions
end

# Strategy identification
Strategies.id(::Type{<:ExaModeler}) = :exa

# Strategy metadata with option definitions
function Strategies.metadata(::Type{<:ExaModeler})
    return Strategies.StrategyMetadata(
        # === Existing Options (enhanced) ===
        Strategies.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=__exa_model_base_type(),
            description="Base floating-point type used by ExaModels",
            validator=validate_exa_base_type
        ),
        # NOTE: minimize option is commented out as it will be automatically set
        # when building the model based on the problem structure
        # Strategies.OptionDefinition(;
        #     name=:minimize,
        #     type=Bool,
        #     default=Options.NotProvided,
        #     description="Whether to minimize (true) or maximize (false) the objective"
        # ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Union{Nothing, KernelAbstractions.Backend},  # More permissive for various backend types
            default=__exa_model_backend(),
            description="Execution backend for ExaModels (CPU, GPU, etc.)"
        )
    )
end

# Simple constructor
function ExaModeler(; kwargs...)
    opts = Strategies.build_strategy_options(
        ExaModeler; kwargs...
    )
    
    return ExaModeler(opts)
end

# Access to strategy options
Strategies.options(m::ExaModeler) = m.options

# Model building interface
function (modeler::ExaModeler)(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ExaModels.ExaModel
    opts = Strategies.options(modeler)
    
    # Get the appropriate builder for this problem type
    builder = get_exa_model_builder(prob)
    
    # Extract BaseType from options
    BaseType = opts[:base_type]
    
    # Extract raw values from OptionValue wrappers and filter out nothing values
    raw_opts = Options.extract_raw_options(opts.options)
    
    # Filter out base_type from raw_opts to avoid passing it as named argument
    filtered_opts = Strategies.filter_options(raw_opts, :base_type)
    
    # Build the ExaModel passing BaseType as first argument and remaining options as named arguments
    return builder(BaseType, initial_guess; filtered_opts...)
end

# Solution building interface
function (modeler::ExaModeler)(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    # Get the appropriate solution builder for this problem type
    builder = get_exa_solution_builder(prob)
    return builder(nlp_solution)
end
