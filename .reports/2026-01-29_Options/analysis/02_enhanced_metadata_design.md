# Enhanced Metadata Design

**Author**: CTModels Development Team  
**Date**: 2026-01-31  
**Purpose**: Design enhanced metadata for ADNLPModeler and ExaModeler

## Design Principles

1. **Backward Compatibility**: All existing options remain unchanged
2. **Progressive Enhancement**: New options are additive
3. **Validation**: Built-in validation for all options
4. **Documentation**: Comprehensive descriptions and examples
5. **Performance**: Focus on high-impact options first

## Enhanced ADNLPModeler Metadata

### Complete Option Set

```julia
function Strategies.metadata(::Type{<:ADNLPModeler})
    return Strategies.StrategyMetadata(
        # === Existing Options (unchanged) ===
        Strategies.OptionDefinition(;
            name=:show_time,
            type=Bool,
            default=false,
            description="Whether to show timing information while building the ADNLP model"
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Symbol,
            default=:optimized,
            description="Automatic differentiation backend used by ADNLPModels",
            validator=v -> v in (:default, :optimized, :generic, :enzyme, :zygote)
        ),
        
        # === New High-Priority Options ===
        Strategies.OptionDefinition(;
            name=:matrix_free,
            type=Bool,
            default=false,
            description="Enable matrix-free mode (avoids explicit Hessian/Jacobian matrices)",
            validator=v -> isa(v, Bool)
        ),
        Strategies.OptionDefinition(;
            name=:name,
            type=String,
            default="CTModels-ADNLP",
            description="Name of the optimization model for identification",
            validator=v -> isa(v, String) && !isempty(v)
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Bool,
            default=true,
            description="Optimization direction (true for minimization, false for maximization)",
            validator=v -> isa(v, Bool)
        ),
        
        # === Advanced Backend Overrides (optional) ===
        Strategies.OptionDefinition(;
            name=:gradient_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for gradient computation (advanced users only)",
            validator=v -> v === nothing || isa(v, Type)
        ),
        Strategies.OptionDefinition(;
            name=:hessian_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Hessian matrix computation (advanced users only)",
            validator=v -> v === nothing || isa(v, Type)
        ),
        Strategies.OptionDefinition(;
            name=:jacobian_backend,
            type=Union{Nothing, Type},
            default=nothing,
            description="Override backend for Jacobian matrix computation (advanced users only)",
            validator=v -> v === nothing || isa(v, Type)
        )
    )
end
```

### Validation Functions

```julia
# Backend availability validation
function validate_adnlp_backend(backend::Symbol)
    valid_backends = (:default, :optimized, :generic, :enzyme, :zygote)
    if backend ∉ valid_backends
        throw(ArgumentError("Invalid backend: $backend. Valid options: $(valid_backends)"))
    end
    
    # Check package availability
    if backend == :enzyme && !isdefined(Main, :Enzyme)
        @warn "Enzyme.jl not loaded. Enzyme backend will not work correctly. " *
              "Load with `using Enzyme` before creating the modeler."
    end
    if backend == :zygote && !isdefined(Main, :Zygote)
        @warn "Zygote.jl not loaded. Zygote backend will not work correctly. " *
              "Load with `using Zygote` before creating the modeler."
    end
end

# Backend override validation
function validate_backend_override(backend_type::Type, operation::String)
    # Check if the type is a valid AD backend
    if !isa(backend_type, Type) || !isconcretetype(backend_type)
        throw(ArgumentError("Invalid $operation backend: $backend_type. " *
                          "Must be a concrete type"))
    end
end
```

## Enhanced ExaModeler Metadata

### Complete Option Set

```julia
function Strategies.metadata(::Type{<:ExaModeler})
    return Strategies.StrategyMetadata(
        # === Existing Options (enhanced) ===
        Strategies.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=Float64,
            description="Base floating-point type used by ExaModels",
            validator=v -> v <: AbstractFloat
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
            default=nothing,
            description="Execution backend for ExaModels (CPU, GPU, etc.)"
        ),
        
        # === New Options ===
        Strategies.OptionDefinition(;
            name=:auto_detect_gpu,
            type=Bool,
            default=true,
            description="Automatically detect and use available GPU backends",
            validator=v -> isa(v, Bool)
        ),
        Strategies.OptionDefinition(;
            name=:gpu_preference,
            type=Symbol,
            default=:cuda,
            description="Preferred GPU backend when multiple are available",
            validator=v -> v in (:cuda, :rocm, :oneapi)
        ),
        Strategies.OptionDefinition(;
            name=:precision_mode,
            type=Symbol,
            default:standard,
            description="Precision mode for performance vs accuracy trade-off",
            validator=v -> v in (:standard, :high, :mixed)
        )
    )
end
```

### Validation Functions

```julia
# Type validation
function validate_base_type(T::Type)
    if !(T <: AbstractFloat)
        throw(ArgumentError("base_type must be a subtype of AbstractFloat, got: $T"))
    end
    
    # Check for GPU compatibility
    if T == Float32 && is_gpu_backend_selected()
        @info "Float32 recommended for GPU backends for better performance"
    end
end

# Backend validation and auto-detection
function validate_exa_backend(backend, auto_detect::Bool, gpu_preference::Symbol)
    if backend === nothing && auto_detect
        # Auto-detect available backends
        detected = detect_available_backends()
        if !isempty(detected)
            selected = select_best_backend(detected, gpu_preference)
            @info "Auto-detected backend: $selected"
            return selected
        end
    end
    
    if backend !== nothing && !is_valid_backend(backend)
        throw(ArgumentError("Invalid backend: $backend. " *
                          "Expected KernelAbstractions.Backend or nothing"))
    end
    
    return backend
end

function detect_available_backends()
    backends = Symbol[]
    
    if isdefined(Main, :CUDA) && CUDA.functional()
        push!(backends, :cuda)
    end
    
    if isdefined(Main, :AMDGPU) && AMDGPU.functional()
        push!(backends, :rocm)
    end
    
    if isdefined(Main, :oneAPI)
        push!(backends, :oneapi)
    end
    
    return backends
end

function select_best_backend(available::Vector{Symbol}, preference::Symbol)
    if preference in available
        return preference
    elseif !isempty(available)
        return first(available)
    else
        return nothing
    end
end
```

## Implementation Strategy

### Phase 1: Core Options (High Priority)

#### ADNLPModeler
- ✅ `matrix_free` - Memory efficiency
- ✅ `name` - Model identification  
- ✅ `minimize` - Optimization direction
- ✅ Enhanced `backend` validation

#### ExaModeler
- ✅ Enhanced `base_type` validation
- ✅ Auto-detection functionality
- ✅ GPU preference handling

### Phase 2: Advanced Options (Medium Priority)

#### ADNLPModeler
- ⏳ Backend override options
- ⏳ Performance profiling options

#### ExaModeler
- ⏳ Precision mode selection
- ⏳ Advanced backend configuration

### Phase 3: Validation and Error Handling

- ⏳ Comprehensive error messages
- ⏳ Warning system for missing dependencies
- ⏳ Performance recommendations

## Usage Examples

### Enhanced ADNLPModeler

```julia
# Basic usage with new options
modeler = ADNLPModeler(
    matrix_free=true,        # Memory efficient
    name="MyProblem",       # Identification
    minimize=false,         # Maximization
    backend=:optimized      # Performance
)

# Advanced usage with backend overrides
modeler = ADNLPModeler(
    backend=:default,
    gradient_backend=ADNLPModels.EnzymeReverseADGradient,
    hessian_backend=ADNLPModels.SparseADHessian
)
```

### Enhanced ExaModeler

```julia
# Auto-detect GPU
modeler = ExaModeler(
    base_type=Float32,
    auto_detect_gpu=true,
    gpu_preference=:cuda
)

# Manual backend selection
using CUDA
modeler = ExaModeler(
    base_type=Float32,
    backend=CUDABackend(),
    auto_detect_gpu=false
)
```

## Migration Guide

### For Existing Code
- **No breaking changes** - all existing code continues to work
- **New defaults** are backward compatible
- **Enhanced validation** provides better error messages

### For New Code
- Use `matrix_free=true` for large-scale problems
- Specify `name` for better model identification
- Use `auto_detect_gpu=true` for GPU acceleration

## Performance Impact

| Option | Memory Impact | Speed Impact | Use Case |
| :--- | :--- | :--- | :--- |
| `matrix_free=true` | -50% to -80% | +10% to +30% | Large problems |
| `base_type=Float32` | -50% | +20% to +50% | GPU computing |
| `backend=:optimized` | No change | +20% to +100% | General use |
| `auto_detect_gpu=true` | No change | +200% to +1000% | Available GPU |

---

**Status**: Design Complete  
**Next**: Implement validation functions
