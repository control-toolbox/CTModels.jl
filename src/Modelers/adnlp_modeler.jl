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
$(TYPEDSIGNATURES)

Return the default value for the `matrix_free` option of [`ADNLPModeler`](@ref).

Default is `false`.
"""
__adnlp_model_matrix_free() = false

"""
$(TYPEDSIGNATURES)

Return the default value for the `name` option of [`ADNLPModeler`](@ref).

Default is `"CTModels-ADNLP"`.
"""
__adnlp_model_name() = "CTModels-ADNLP"

"""
$(TYPEDSIGNATURES)

Return the default value for the `minimize` option of [`ADNLPModeler`](@ref).

Default is `true`.
"""
__adnlp_model_minimize() = true

"""
    ADNLPModeler

Modeler for building ADNLPModels from discretized optimal control problems.

This modeler uses the ADNLPModels.jl package to create NLP models with
automatic differentiation support. It provides configurable options for
timing information, AD backend selection, memory optimization, and model
identification.

# Options
- `show_time::Bool`: Whether to show timing information (default: `false`)
- `backend::Symbol`: AD backend to use (default: `:optimized`)
- `matrix_free::Bool`: Enable matrix-free mode for memory efficiency (default: `false`)
- `name::String`: Model name for identification (default: `"CTModels-ADNLP"`)
- `minimize::Bool`: Optimization direction (default: `true`)

# Example
```julia
modeler = ADNLPModeler(
    show_time=true, 
    backend=:optimized,
    matrix_free=true,
    name="MyProblem",
    minimize=true
)
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
        # === Existing Options (unchanged) ===
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
            description="Automatic differentiation backend used by ADNLPModels",
            validator=validate_adnlp_backend
        ),
        
        # === New High-Priority Options ===
        Strategies.OptionDefinition(;
            name=:matrix_free,
            type=Bool,
            default=__adnlp_model_matrix_free(),
            description="Enable matrix-free mode (avoids explicit Hessian/Jacobian matrices)",
            validator=validate_matrix_free
        ),
        Strategies.OptionDefinition(;
            name=:name,
            type=String,
            default=__adnlp_model_name(),
            description="Name of the optimization model for identification",
            validator=validate_model_name
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Bool,
            default=__adnlp_model_minimize(),
            description="Optimization direction (true for minimization, false for maximization)",
            validator=validate_optimization_direction
        ),
        
        # === Advanced Backend Overrides (expert users) ===
        Strategies.OptionDefinition(;
            name=:gradient_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for gradient computation (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:hprod_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Hessian-vector product (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:jprod_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Jacobian-vector product (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:jtprod_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for transpose Jacobian-vector product (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:jacobian_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Jacobian matrix computation (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:hessian_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Hessian matrix computation (advanced users only)",
            validator=validate_backend_override
        ),
        
        # === Advanced Backend Overrides for NLS (expert users) ===
        Strategies.OptionDefinition(;
            name=:ghjvprod_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for g^T ∇²c(x)v computation (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:hprod_residual_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Hessian-vector product of residuals (NLS) (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:jprod_residual_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Jacobian-vector product of residuals (NLS) (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:jtprod_residual_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for transpose Jacobian-vector product of residuals (NLS) (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:jacobian_residual_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Jacobian matrix of residuals (NLS) (advanced users only)",
            validator=validate_backend_override
        ),
        Strategies.OptionDefinition(;
            name=:hessian_residual_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Hessian matrix of residuals (NLS) (advanced users only)",
            validator=validate_backend_override
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
    raw_opts = Options.extract_raw_options(opts.options)
    
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
