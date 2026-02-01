# Validation Functions for Enhanced Modelers
#
# This file contains validation functions for the enhanced ADNLPModeler and ExaModeler
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
        else
            # Additional Enzyme-specific validation could go here
            try
                Enzyme.Core.CompilerEnzyme  # Test if Enzyme is properly loaded
            catch e
                @warn "Enzyme.jl may not be properly configured. Error: $e"
            end
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
    validate_adnlp_backend_override(backend_type::Union{Nothing, Type}, operation::String)

Validate that a backend override type is appropriate for the specified operation.

# Arguments
- `backend_type::Union{Nothing, Type}`: The backend type to validate (nothing for default)
- `operation::String`: Description of the operation for error messages

# Throws
- `ArgumentError`: If the backend type is invalid

# Examples
```julia
julia> validate_adnlp_backend_override(ADNLPModels.ForwardDiffADGradient, "gradient")
ADNLPModels.ForwardDiffADGradient

julia> validate_adnlp_backend_override(String, "gradient")
ERROR: ArgumentError: Invalid gradient backend: String. Must be a concrete AD backend type or nothing
```
"""
function validate_adnlp_backend_override(backend_type::Union{Nothing, Type}, operation::String)
    if backend_type === nothing
        return nothing
    end
    
    if !isa(backend_type, Type) || !isconcretetype(backend_type)
        throw(ArgumentError(
            "Invalid $operation backend: $backend_type. " *
            "Must be a concrete AD backend type or nothing"
        ))
    end
    
    # Additional validation could check if the type is actually an AD backend
    # This would require checking against known AD backend types
    
    return backend_type
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
    
    # Performance recommendations
    if T == Float32
        @info "Float32 is recommended for GPU backends for better performance and memory usage"
    elseif T == Float64
        @info "Float64 provides higher precision but may be slower on GPU backends"
    end
    
    return T
end

"""
    detect_available_gpu_backends()

Detect which GPU backends are available and functional.

# Returns
- `Vector{Symbol}`: List of available GPU backend symbols

# Examples
```julia
julia> detect_available_gpu_backends()
[:cuda]

julia> detect_available_gpu_backends()
[:cuda, :rocm]
```
"""
function detect_available_gpu_backends()
    backends = Symbol[]
    
    # Check CUDA
    if isdefined(Main, :CUDA)
        try
            if CUDA.functional()
                push!(backends, :cuda)
            end
        catch e
            @warn "CUDA.jl loaded but GPU not functional: $e"
        end
    end
    
    # Check AMDGPU (ROCm)
    if isdefined(Main, :AMDGPU)
        try
            if AMDGPU.functional()
                push!(backends, :cuda)  # AMDGPU uses CUDA backend interface
            end
        catch e
            @warn "AMDGPU.jl loaded but GPU not functional: $e"
        end
    end
    
    # Check oneAPI (Intel)
    if isdefined(Main, :oneAPI)
        try
            # oneAPI availability check
            push!(backends, :oneapi)
        catch e
            @warn "oneAPI.jl loaded but may not be functional: $e"
        end
    end
    
    return backends
end

"""
    select_best_gpu_backend(available::Vector{Symbol}, preference::Symbol)

Select the best GPU backend from available options based on preference.

# Arguments
- `available::Vector{Symbol}`: List of available backends
- `preference::Symbol`: User preference (:cuda, :rocm, :oneapi)

# Returns
- `Union{Symbol, Nothing}`: Selected backend or nothing if none available

# Examples
```julia
julia> select_best_gpu_backend([:cuda, :rocm], :rocm)
:rocm

julia> select_best_gpu_backend([:cuda], :rocm)
:cuda
```
"""
function select_best_gpu_backend(available::Vector{Symbol}, preference::Symbol)
    if preference in available
        return preference
    elseif !isempty(available)
        @info "Preferred GPU backend :$preference not available. Using :$(first(available)) instead."
        return first(available)
    else
        return nothing
    end
end

"""
    validate_exa_backend(backend, auto_detect::Bool, gpu_preference::Symbol)

Validate and potentially auto-detect the best ExaModels backend.

# Arguments
- `backend`: User-specified backend or nothing
- `auto_detect::Bool`: Whether to auto-detect GPU backends
- `gpu_preference::Symbol`: Preferred GPU backend

# Returns
- The validated or auto-detected backend

# Examples
```julia
julia> validate_exa_backend(nothing, true, :cuda)
CUDABackend()

julia> validate_exa_backend(CUDABackend(), false, :cuda)
CUDABackend()
```
"""
function validate_exa_backend(backend, auto_detect::Bool, gpu_preference::Symbol)
    # Auto-detection logic
    if backend === nothing && auto_detect
        available = detect_available_gpu_backends()
        if !isempty(available)
            selected_symbol = select_best_gpu_backend(available, gpu_preference)
            
            # Convert symbol to actual backend object
            if selected_symbol == :cuda && isdefined(Main, :CUDA)
                return CUDA.CUDABackend()
            elseif selected_symbol == :rocm && isdefined(Main, :AMDGPU)
                return AMDGPU.ROCBackend()
            elseif selected_symbol == :oneapi && isdefined(Main, :oneAPI)
                return oneAPI.oneAPIBackend()
            end
        else
            @info "No GPU backends detected. Using CPU backend."
        end
    end
    
    # Validate user-specified backend
    if backend !== nothing
        # Check if it's a valid backend type
        if !isa(backend, KernelAbstractions.Backend) && 
           !isa(backend, Union{typeof(CUDA.CUDABackend()), typeof(AMDGPU.ROCBackend()), typeof(oneAPI.oneAPIBackend())})
            @warn "Invalid backend type: $(typeof(backend)). Expected KernelAbstractions.Backend or specific GPU backend."
        end
    end
    
    return backend
end

"""
    validate_matrix_free(matrix_free::Bool, problem_size::Int)

Validate matrix-free mode setting and provide recommendations.

# Arguments
- `matrix_free::Bool`: Whether to use matrix-free mode
- `problem_size::Int`: Size of the optimization problem

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
function validate_matrix_free(matrix_free::Bool, problem_size::Int)
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
    validate_optimization_direction(minimize::Bool)

Validate the optimization direction setting.

# Arguments
- `minimize::Bool`: Whether to minimize (true) or maximize (false)

# Returns
- `Bool`: Validated optimization direction

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
        throw(ArgumentError("minimize must be a boolean, got: $(typeof(minimize))"))
    end
    
    return minimize
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
    validate_all_options(modeler_type::Type, options::NamedTuple)

Comprehensive validation for all modeler options.

# Arguments
- `modeler_type::Type`: Type of modeler (ADNLPModeler or ExaModeler)
- `options::NamedTuple`: Options to validate

# Examples
```julia
julia> options = (backend=:optimized, matrix_free=true, name="Test")
julia> validate_all_options(ADNLPModeler, options)
(options = (backend = :optimized, matrix_free = true, name = "Test"))
```
"""
function validate_all_options(modeler_type::Type, options::NamedTuple)
    if modeler_type == ADNLPModeler
        return validate_adnlp_options(options)
    elseif modeler_type == ExaModeler
        return validate_exa_options(options)
    else
        throw(ArgumentError("Unknown modeler type: $modeler_type"))
    end
end

"""
    validate_adnlp_options(options::NamedTuple)

Validate all ADNLPModeler options.

# Arguments
- `options::NamedTuple`: ADNLPModeler options

# Returns
- `NamedTuple`: Validated options
"""
function validate_adnlp_options(options::NamedTuple)
    validated_options = Dict{Symbol, Any}()
    
    # Validate each option
    for (key, value) in pairs(options)
        if key == :backend
            validated_options[key] = validate_adnlp_backend(value)
        elseif key == :matrix_free
            validated_options[key] = validate_matrix_free(value, 1000)  # Default size
        elseif key == :name
            validated_options[key] = validate_model_name(value)
        elseif key == :minimize
            validated_options[key] = validate_optimization_direction(value)
        elseif key == :show_time
            validated_options[key] = value  # Simple boolean, no complex validation needed
        elseif key in (:gradient_backend, :hessian_backend, :jacobian_backend)
            operation = string(key)[1:end-8]  # Remove "_backend" suffix
            validated_options[key] = validate_adnlp_backend_override(value, operation)
        else
            validated_options[key] = value  # Pass through unknown options
        end
    end
    
    return (; validated_options...)
end

"""
    validate_exa_options(options::NamedTuple)

Validate all ExaModeler options.

# Arguments
- `options::NamedTuple`: ExaModeler options

# Returns
- `NamedTuple`: Validated options
"""
function validate_exa_options(options::NamedTuple)
    validated_options = Dict{Symbol, Any}()
    
    # Validate each option
    for (key, value) in pairs(options)
        if key == :base_type
            validated_options[key] = validate_exa_base_type(value)
        elseif key == :backend
            auto_detect = get(options, :auto_detect_gpu, true)
            gpu_pref = get(options, :gpu_preference, :cuda)
            validated_options[key] = validate_exa_backend(value, auto_detect, gpu_pref)
        elseif key == :auto_detect_gpu
            validated_options[key] = value
        elseif key == :gpu_preference
            validated_options[key] = validate_gpu_preference(value)
        elseif key == :precision_mode
            validated_options[key] = validate_precision_mode(value)
        elseif key == :minimize
            validated_options[key] = value  # Can be nothing, no complex validation
        else
            validated_options[key] = value  # Pass through unknown options
        end
    end
    
    return (; validated_options...)
end
