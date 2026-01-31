# Validation Functions for Enhanced Modelers
#
# This module provides validation functions for the enhanced ADNLPModeler and ExaModeler
# options. These functions provide robust error checking and user guidance.
#
# Author: CTModels Development Team
# Date: 2026-01-31

"""
    validate_adnlp_backend(backend::Symbol)

Validate that the specified ADNLPModels backend is supported and available.

# Arguments
- `backend::Symbol`: The backend symbol to validate

# Throws
- `ArgumentError`: If the backend is not supported

# Examples
```julia
julia> validate_adnlp_backend(:optimized)
:optimized

julia> validate_adnlp_backend(:invalid_backend)
ERROR: ArgumentError: Invalid backend: :invalid_backend. Valid options: (:default, :optimized, :generic, :enzyme, :zygote)
```
"""
function validate_adnlp_backend(backend::Symbol)
    valid_backends = (:default, :optimized, :generic, :enzyme, :zygote)
    
    if backend ∉ valid_backends
        throw(ArgumentError(
            "Invalid backend: $backend. Valid options: $(valid_backends)"
        ))
    end
    
    # Check package availability with helpful warnings
    if backend == :enzyme
        if !isdefined(Main, :Enzyme)
            @warn "Enzyme.jl not loaded. Enzyme backend will not work correctly. " *
                  "Load with `using Enzyme` before creating the modeler."
        end
    end
    
    if backend == :zygote
        if !isdefined(Main, :Zygote)
            @warn "Zygote.jl not loaded. Zygote backend will not work correctly. " *
                  "Load with `using Zygote` before creating the modeler."
        end
    end
    
    return backend
end

"""
    validate_exa_base_type(T::Type)

Validate that the specified base type is appropriate for ExaModels.

# Arguments
- `T::Type`: The type to validate

# Throws
- `ArgumentError`: If the type is not a valid floating-point type

# Examples
```julia
julia> validate_exa_base_type(Float64)
Float64

julia> validate_exa_base_type(Float32)
Float32

julia> validate_exa_base_type(Int)
ERROR: ArgumentError: base_type must be a subtype of AbstractFloat, got: Int
```
"""
function validate_exa_base_type(T::Type)
    if !(T <: AbstractFloat)
        throw(ArgumentError(
            "base_type must be a subtype of AbstractFloat, got: $T"
        ))
    end
    
    # # Performance recommendations
    # if T == Float32
    #     @info "Float32 is recommended for GPU backends for better performance and memory usage"
    # elseif T == Float64
    #     @info "Float64 provides higher precision but may be slower on GPU backends"
    # end
    
    return T
end

"""
    validate_gpu_preference(preference::Symbol)

Validate the GPU backend preference.

# Arguments
- `preference::Symbol`: Preferred GPU backend

# Throws
- `ArgumentError`: If the preference is invalid

# Examples
```julia
julia> validate_gpu_preference(:cuda)
:cuda

julia> validate_gpu_preference(:invalid)
ERROR: ArgumentError: Invalid GPU preference: :invalid. Valid options: (:cuda, :rocm, :oneapi)
```
"""
function validate_gpu_preference(preference::Symbol)
    valid_preferences = (:cuda, :rocm, :oneapi)
    
    if preference ∉ valid_preferences
        throw(ArgumentError(
            "Invalid GPU preference: $preference. Valid options: $(valid_preferences)"
        ))
    end
    
    return preference
end

"""
    validate_precision_mode(mode::Symbol)

Validate the precision mode setting.

# Arguments
- `mode::Symbol`: Precision mode (:standard, :high, :mixed)

# Throws
- `ArgumentError`: If the mode is invalid

# Examples
```julia
julia> validate_precision_mode(:standard)
:standard

julia> validate_precision_mode(:invalid)
ERROR: ArgumentError: Invalid precision mode: :invalid. Valid options: (:standard, :high, :mixed)
```
"""
function validate_precision_mode(mode::Symbol)
    valid_modes = (:standard, :high, :mixed)
    
    if mode ∉ valid_modes
        throw(ArgumentError(
            "Invalid precision mode: $mode. Valid options: $(valid_modes)"
        ))
    end
    
    # Provide guidance on precision modes
    if mode == :high
        @info "High precision mode may impact performance. Use for problems requiring high numerical accuracy."
    elseif mode == :mixed
        @info "Mixed precision mode can improve performance while maintaining accuracy for many problems."
    end
    
    return mode
end

"""
    validate_model_name(name::String)

Validate that the model name is appropriate.

# Arguments
- `name::String`: The model name to validate

# Throws
- `ArgumentError`: If the name is invalid

# Examples
```julia
julia> validate_model_name("MyProblem")
"MyProblem"

julia> validate_model_name("")
ERROR: ArgumentError: Model name cannot be empty
```
"""
function validate_model_name(name::String)
    if !isa(name, String)
        throw(ArgumentError("Model name must be a string, got: $(typeof(name))"))
    end
    
    if isempty(name)
        throw(ArgumentError("Model name cannot be empty"))
    end
    
    # Check for valid characters (alphanumeric, underscore, hyphen)
    if !occursin(r"^[a-zA-Z0-9_-]+$", name)
        @warn "Model name contains special characters. Consider using only letters, numbers, underscores, and hyphens."
    end
    
    return name
end

"""
    validate_matrix_free(matrix_free::Bool, problem_size::Int = 1000)

Validate matrix-free mode setting and provide recommendations.

# Arguments
- `matrix_free::Bool`: Whether to use matrix-free mode
- `problem_size::Int`: Size of the optimization problem (default: 1000)

# Returns
- `Bool`: Validated matrix-free setting

# Examples
```julia
julia> validate_matrix_free(true, 10000)
true

julia> validate_matrix_free(false, 1000000)
@info "Consider using matrix_free=true for large problems (n > 100000)"
false
```
"""
function validate_matrix_free(matrix_free::Bool, problem_size::Int = 1000)
    if !isa(matrix_free, Bool)
        throw(ArgumentError("matrix_free must be a boolean, got: $(typeof(matrix_free))"))
    end
    
    # Provide recommendations based on problem size
    if problem_size > 100_000 && !matrix_free
        @info "Consider using matrix_free=true for large problems (n > 100000) " *
              "to reduce memory usage by 50-80%"
    elseif problem_size < 1_000 && matrix_free
        @info "matrix_free=true may have overhead for small problems. " *
              "Consider matrix_free=false for problems with n < 1000"
    end
    
    return matrix_free
end

"""
    validate_optimization_direction(minimize::Bool)

Validate that the optimization direction is a boolean value.

# Arguments
- `minimize::Bool`: The optimization direction to validate

# Throws
- `ArgumentError`: If the value is not a boolean

# Examples
```julia
julia> validate_optimization_direction(true)
true

julia> validate_optimization_direction(false)
false
```
"""
function validate_optimization_direction(minimize::Bool)
    if !isa(minimize, Bool)
        throw(ArgumentError("Optimization direction must be a boolean (true for minimization, false for maximization)"))
    end
    return minimize
end

"""
    validate_backend_override(backend)

Validate that a backend override is either nothing or a valid type.

# Arguments
- `backend`: The backend type to validate (any type accepted)

# Throws
- `IncorrectArgument`: If the backend is not nothing or a valid type

# Examples
```julia
julia> validate_backend_override(nothing)
nothing

julia> validate_backend_override(ForwardDiffADGradient)
ForwardDiffADGradient

julia> validate_backend_override("invalid")
ERROR: IncorrectArgument: Backend override must be a Type or nothing
```
"""
function validate_backend_override(backend)
    if backend !== nothing && !isa(backend, Type)
        throw(IncorrectArgument(
            "Backend override must be a Type or nothing",
            got=string(typeof(backend)),
            expected="Type or nothing",
            suggestion="Use nothing for default backend or provide a valid backend Type"
        ))
    end
    return backend
end
