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

"""
$(TYPEDSIGNATURES)

Return the default value for the `auto_detect_gpu` option of [`ExaModeler`](@ref).

Default is `true`.
"""
__exa_model_auto_detect_gpu() = true

"""
$(TYPEDSIGNATURES)

Return the default GPU backend preference for [`ExaModeler`](@ref).

Default is `:cuda`.
"""
__exa_model_gpu_preference() = :cuda

"""
$(TYPEDSIGNATURES)

Return the default precision mode for [`ExaModeler`](@ref).

Default is `:standard`.
"""
__exa_model_precision_mode() = :standard

"""
    ExaModeler{BaseType<:AbstractFloat}

Modeler for building ExaModels from discretized optimal control problems.

This modeler uses the ExaModels.jl package to create NLP models with
support for various execution backends (CPU, GPU) and floating-point types.
It provides automatic GPU detection, precision control, and performance
optimization features.

# Type Parameters
- `BaseType`: Floating-point type for the model (default: `Float64`)

# Options
- `base_type::Type{<:AbstractFloat}`: Floating-point type (default: `Float64`)
- `minimize::Union{Bool, Nothing}`: Whether to minimize (default: `nothing` from problem)
- `backend`: Execution backend (default: `nothing` for CPU)
- `auto_detect_gpu::Bool`: Automatically detect and use available GPU backends (default: `true`)
- `gpu_preference::Symbol`: Preferred GPU backend when multiple are available (default: `:cuda`)
- `precision_mode::Symbol`: Precision mode for performance vs accuracy trade-off (default: `:standard`)

# Example
```julia
# Auto-detect GPU with optimal settings
modeler = ExaModeler(
    base_type=Float32,
    auto_detect_gpu=true,
    gpu_preference=:cuda,
    precision_mode=:mixed
)

# Manual GPU selection
modeler = ExaModeler{Float32}(backend=CUDABackend())
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
        # === Existing Options (enhanced) ===
        Strategies.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=__exa_model_base_type(),
            description="Base floating-point type used by ExaModels",
            validator=validate_exa_base_type
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Union{Bool, Nothing},
            default=nothing,
            description="Whether to minimize (true) or maximize (false) the objective"
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Union{Nothing, Any},  # More permissive for various backend types
            default=__exa_model_backend(),
            description="Execution backend for ExaModels (CPU, GPU, etc.)"
        ),
        
        # === New Options ===
        Strategies.OptionDefinition(;
            name=:auto_detect_gpu,
            type=Bool,
            default=__exa_model_auto_detect_gpu(),
            description="Automatically detect and use available GPU backends",
            validator=v -> isa(v, Bool)
        ),
        Strategies.OptionDefinition(;
            name=:gpu_preference,
            type=Symbol,
            default=__exa_model_gpu_preference(),
            description="Preferred GPU backend when multiple are available",
            validator=validate_gpu_preference
        ),
        Strategies.OptionDefinition(;
            name=:precision_mode,
            type=Symbol,
            default=__exa_model_precision_mode(),
            description="Precision mode for performance vs accuracy trade-off",
            validator=validate_precision_mode
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
    raw_opts = Options.extract_raw_options(opts.options)
    
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
