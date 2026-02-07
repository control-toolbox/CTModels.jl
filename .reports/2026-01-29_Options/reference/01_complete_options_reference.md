# Complete Reference for ADNLPModels and ExaModels Options

**Author**: CTModels Development Team  
**Date**: 2026-01-31  
**Purpose**: Comprehensive documentation of available options for ADNLPModels and ExaModels integration in CTModels.jl

## Table of Contents

1. [ADNLPModels Options](#1-adnlpmodels-options)
   - [Model Constructor Options](#11-model-constructor-options)
   - [Backend Configuration Options](#12-backend-configuration-options)
   - [Predefined Backend Mappings](#13-predefined-backend-mappings)
2. [ExaModels Options](#2-examodels-options)
   - [ExaCore Constructor Options](#21-exacore-constructor-options)
   - [ExaModel Constructor Options](#22-examodel-constructor-options)
3. [Integration with CTModels.jl](#3-integration-with-ctmodelsjl)
   - [ADNLPModeler Implementation](#31-adnlpmodeler-implementation)
   - [ExaModeler Implementation](#32-examodeler-implementation)
4. [Option Validation](#4-option-validation)
5. [Usage Examples](#5-usage-examples)

---

## 1. ADNLPModels Options

ADNLPModels provides comprehensive options for automatic differentiation backend configuration and model construction.

### 1.1. Model Constructor Options

These options are passed directly to `ADNLPModel(...)` constructors.

| Option Name | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `name` | `String` | `"Generic"` | The name of the model |
| `minimize` | `Bool` | `true` | Optimization direction (true for minimization, false for maximization) |
| `y0` | `AbstractVector` | `zeros(...)` | Initial estimate for Lagrangian multipliers (constrained problems only) |

### 1.2. Backend Configuration Options

These options control the automatic differentiation strategy via `ADModelBackend`.

#### General Backend Configuration

| Option Name | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `backend` | `Symbol` | `:default` | Predefined AD backend set. Valid values: `:default`, `:optimized`, `:generic`, `:enzyme`, `:zygote` |
| `matrix_free` | `Bool` | `false` | Enable matrix-free mode (avoids explicit Hessian/Jacobian matrices) |
| `show_time` | `Bool` | `false` | Display timing information for backend component initialization |

#### Specific Backend Overrides

These options allow fine-grained control over individual derivative computations:

| Option Name | Description | Default (depends on `backend`) |
| :--- | :--- | :--- |
| `gradient_backend` | Backend for gradient computation | `ForwardDiffADGradient` |
| `hprod_backend` | Backend for Hessian-vector product | `ForwardDiffADHvprod` |
| `jprod_backend` | Backend for Jacobian-vector product | `ForwardDiffADJprod` |
| `jtprod_backend` | Backend for transpose Jacobian-vector product | `ForwardDiffADJtprod` |
| `jacobian_backend` | Backend for Jacobian matrix | `SparseADJacobian` |
| `hessian_backend` | Backend for Hessian matrix | `SparseADHessian` |
| `ghjvprod_backend` | Backend for $g^T \nabla^2 c(x) v$ | `ForwardDiffADGHjvprod` |
| `hprod_residual_backend` | Hessian-vector product for residuals (NLS) | `ForwardDiffADHvprod` |
| `jprod_residual_backend` | Jacobian-vector product for residuals (NLS) | `ForwardDiffADJprod` |
| `jtprod_residual_backend` | Transpose Jacobian-vector product for residuals (NLS) | `ForwardDiffADJtprod` |
| `jacobian_residual_backend` | Jacobian matrix for residuals (NLS) | `SparseADJacobian` |
| `hessian_residual_backend` | Hessian matrix for residuals (NLS) | `SparseADHessian` |

### 1.3. Predefined Backend Mappings

The `backend` symbol maps to specific default configurations:

#### `:default` Backend
- **Description**: Uses ForwardDiff for everything (sparse where appropriate)
- **Gradient**: `ForwardDiffADGradient`
- **Hessian**: `SparseADHessian`
- **Jacobian**: `SparseADJacobian`
- **Vector products**: ForwardDiff variants

#### `:optimized` Backend
- **Description**: Uses ReverseDiff for gradient and Hessian products, ForwardDiff for Jacobian products
- **Gradient**: `ReverseDiffADGradient`
- **Hessian-vector**: `ReverseDiffADHvprod`
- **Jacobian-vector**: `ForwardDiffADJprod`
- **Matrices**: Sparse variants

#### `:generic` Backend
- **Description**: Uses GenericForwardDiff for non-standard number types
- **All operations**: `GenericForwardDiff` variants
- **Use case**: Custom number types, extended precision

#### `:enzyme` Backend
- **Description**: Uses Enzyme (reverse mode) for gradient, products, and sparse matrices
- **Gradient**: `EnzymeReverseADGradient`
- **Vector products**: `EnzymeReverse` variants
- **Matrices**: `SparseEnzyme` variants
- **Note**: Requires Enzyme.jl to be loaded first

#### `:zygote` Backend
- **Description**: Uses Zygote for gradient, Jacobian, Hessian, and products
- **Gradient**: `ZygoteADGradient`
- **Jacobian**: `ZygoteADJacobian`
- **Hessian**: `ZygoteADHessian`
- **Vector products**: Zygote variants with ForwardDiff fallbacks
- **Note**: Requires Zygote.jl to be loaded first

---

## 2. ExaModels Options

ExaModels focuses on high-performance optimization with support for various execution backends and floating-point types.

### 2.1. ExaCore Constructor Options

`ExaCore` is the intermediate data structure for building ExaModels.

| Constructor Signature | Description |
| :--- | :--- |
| `ExaCore()` | Default Float64, CPU backend |
| `ExaCore(T::Type)` | Custom floating-point type `T`, CPU backend |
| `ExaCore(; backend=nothing, minimize=true)` | Default Float64 with optional backend |
| `ExaCore(T::Type; backend=nothing, minimize=true)` | Custom type with optional backend |

#### ExaCore Options

| Option Name | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `array_eltype` | `DataType` | `Float64` | Floating-point precision for arrays |
| `backend` | `Union{Nothing, Backend}` | `nothing` | Execution backend (CPU, GPU, etc.) |
| `minimize` | `Bool` | `true` | Optimization direction |

#### Supported Backend Types

| Backend | Package | Description | Requirements |
| :--- | :--- | :--- | :--- |
| `nothing` | - | CPU execution (default) | None |
| `CUDABackend()` | CUDA.jl | NVIDIA GPU execution | CUDA.jl, NVIDIA GPU |
| `ROCBackend()` | AMDGPU.jl | AMD GPU execution | AMDGPU.jl, AMD GPU |
| `oneAPIBackend()` | oneAPI.jl | Intel GPU execution | oneAPI.jl, Intel GPU |

### 2.2. ExaModel Constructor Options

`ExaModel` is the final optimization model object.

| Constructor Signature | Description |
| :--- | :--- |
| `ExaModel(core::ExaCore)` | Create model from ExaCore object |

**Note**: The ExaModel constructor does not accept additional options. All configuration is done through the ExaCore object.

---

## 3. Integration with CTModels.jl

### 3.1. ADNLPModeler Implementation

The `ADNLPModeler` in CTModels.jl provides a simplified interface to ADNLPModels options.

#### Current Implementation

```julia
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
```

#### Default Values
- `show_time`: `false`
- `backend`: `:optimized`

#### Missing Options (Recommended Additions)

The following ADNLPModels options are not currently exposed but should be considered:

| Option | Priority | Reason |
| :--- | :--- | :--- |
| `matrix_free` | Medium | Important for large-scale problems |
| `name` | Low | Model identification |
| `minimize` | Medium | Optimization direction control |
| Backend overrides | Low | Advanced user control |

#### Recommended Enhanced Metadata

```julia
function Strategies.metadata(::Type{<:ADNLPModeler})
    return Strategies.StrategyMetadata(
        # Existing options
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
        # Recommended additions
        Strategies.OptionDefinition(;
            name=:matrix_free,
            type=Bool,
            default=false,
            description="Enable matrix-free mode (avoids explicit Hessian/Jacobian matrices)"
        ),
        Strategies.OptionDefinition(;
            name=:name,
            type=String,
            default="CTModels-ADNLP",
            description="Name of the optimization model"
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Bool,
            default=true,
            description="Optimization direction (true for minimization, false for maximization)"
        )
    )
end
```

### 3.2. ExaModeler Implementation

The `ExaModeler` in CTModels.jl provides access to ExaModels options.

#### Current Implementation

```julia
function Strategies.metadata(::Type{<:ExaModeler})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=__exa_model_base_type(),
            description="Base floating-point type used by ExaModels"
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Union{Bool, Nothing},
            default=Options.NotProvided,
            description="Whether to minimize (true) or maximize (false) the objective"
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Union{Nothing, KernelAbstractions.Backend},
            default=__exa_model_backend(),
            description="Execution backend for ExaModels (CPU, GPU, etc.)"
        )
    )
end
```

#### Default Values
- `base_type`: `Float64`
- `minimize`: `Options.NotProvided` (inherited from problem)
- `backend`: `nothing` (CPU)

#### Recommended Enhancements

```julia
function Strategies.metadata(::Type{<:ExaModeler})
    return Strategies.StrategyMetadata(
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
        )
    )
end
```

---

## 4. Option Validation

### 4.1. ADNLPModels Validation

#### Backend Symbol Validation
```julia
function validate_backend(backend::Symbol)
    valid_backends = (:default, :optimized, :generic, :enzyme, :zygote)
    if backend ∉ valid_backends
        throw(ArgumentError("Invalid backend: $backend. Valid options: $(valid_backends)"))
    end
end
```

#### Backend Availability Validation
```julia
function validate_backend_availability(backend::Symbol)
    if backend == :enzyme && !isdefined(Main, :Enzyme)
        @warn "Enzyme.jl not loaded. Enzyme backend will not work correctly."
    end
    if backend == :zygote && !isdefined(Main, :Zygote)
        @warn "Zygote.jl not loaded. Zygote backend will not work correctly."
    end
end
```

### 4.2. ExaModels Validation

#### Floating-Point Type Validation
```julia
function validate_base_type(T::Type)
    if !(T <: AbstractFloat)
        throw(ArgumentError("base_type must be a subtype of AbstractFloat, got: $T"))
    end
end
```

#### Backend Validation
```julia
function validate_backend(backend)
    if backend !== nothing && !isa(backend, KernelAbstractions.Backend)
        @warn "Invalid backend type: $(typeof(backend)). Expected KernelAbstractions.Backend or nothing."
    end
end
```

---

## 5. Usage Examples

### 5.1. ADNLPModeler Examples

#### Basic Usage
```julia
using CTModels

# Create modeler with default options
modeler = ADNLPModeler()

# Create modeler with custom backend
modeler = ADNLPModeler(backend=:enzyme, show_time=true)

# Build model
nlp_model = modeler(problem, initial_guess)
```

#### Advanced Configuration
```julia
# High-performance configuration
modeler = ADNLPModeler(
    backend=:optimized,
    matrix_free=true,
    show_time=false,
    name="MyOptimizationProblem"
)

# GPU acceleration (if available)
modeler = ADNLPModeler(
    backend=:enzyme,
    show_time=true
)
```

### 5.2. ExaModeler Examples

#### Basic Usage
```julia
using CTModels

# Default CPU configuration
modeler = ExaModeler()

# Custom floating-point type
modeler = ExaModeler(base_type=Float32)

# GPU acceleration
using CUDA
modeler = ExaModeler(base_type=Float32, backend=CUDABackend())
```

#### Multi-Backend Configuration
```julia
# CPU with double precision
cpu_modeler = ExaModeler(base_type=Float64, backend=nothing)

# GPU with single precision
gpu_modeler = ExaModeler(base_type=Float32, backend=CUDABackend())

# Custom optimization direction
max_modeler = ExaModeler(minimize=false)
```

### 5.3. Integration Examples

#### Problem-Specific Configuration
```julia
# For large-scale problems
large_scale_modeler = ADNLPModeler(
    backend=:optimized,
    matrix_free=true,
    show_time=true
)

# For high-precision requirements
precision_modeler = ADNLPModeler(
    backend=:generic,
    name="HighPrecision"
)

# For GPU acceleration
gpu_modeler = ExaModeler(
    base_type=Float32,
    backend=CUDABackend()
)
```

#### Comparative Testing
```julia
# Compare different backends
backends = [:default, :optimized, :enzyme]
models = [ADNLPModeler(backend=b) for b in backends]

results = []
for modeler in models
    nlp = modeler(problem, initial_guess)
    result = solve(nlp, solver)
    push!(results, (backend=modeler.options.backend, result=result))
end
```

---

## 6. Performance Considerations

### 6.1. ADNLPModels Performance

| Backend | Best For | Memory Usage | Speed | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `:default` | General use | Medium | Good | Stable, reliable |
| `:optimized` | Large problems | Medium | Very Good | ReverseDiff for gradients |
| `:generic` | Custom types | Variable | Variable | For non-standard types |
| `:enzyme` | GPU/CPU | Low | Excellent | Requires Enzyme.jl |
| `:zygote` | ML-style | Medium | Good | Requires Zygote.jl |

### 6.2. ExaModels Performance

| Configuration | Best For | Memory | Speed | Requirements |
| :--- | :--- | :--- | :--- | :--- |
| CPU + Float64 | General purpose | High | Good | None |
| CPU + Float32 | Memory-constrained | Medium | Good | None |
| GPU + Float32 | Large-scale | Low | Excellent | CUDA.jl + GPU |
| GPU + Float64 | High-precision GPU | Medium | Very Good | CUDA.jl + GPU |

---

## 7. Troubleshooting

### 7.1. Common Issues

#### ADNLPModels
- **Issue**: Backend not available
- **Solution**: Load required package before creating modeler
  ```julia
  using Enzyme  # For :enzyme backend
  modeler = ADNLPModeler(backend=:enzyme)
  ```

#### ExaModels
- **Issue**: GPU backend not working
- **Solution**: Ensure CUDA.jl is properly installed and GPU is available
  ```julia
  using CUDA
  CUDA.functional()  # Check GPU availability
  modeler = ExaModeler(backend=CUDABackend())
  ```

### 7.2. Debug Options

#### Enable Timing Information
```julia
modeler = ADNLPModeler(show_time=true)
```

#### Check Backend Configuration
```julia
using ADNLPModels
ADNLPModels.predefined_backend[:optimized]  # View backend details
```

---

## 8. Future Enhancements

### 8.1. Recommended CTModels.jl Improvements

1. **Enhanced Option Support**: Add missing ADNLPModels options to `ADNLPModeler`
2. **Automatic Backend Detection**: Detect available packages and suggest optimal backends
3. **Performance Profiling**: Built-in performance comparison tools
4. **Memory Management**: Options for memory-constrained environments
5. **Parallel Execution**: Support for multi-GPU and distributed computing

### 8.2. Integration Opportunities

1. **Hybrid Backends**: Use different backends for different derivative types
2. **Adaptive Selection**: Automatically select backend based on problem characteristics
3. **Caching**: Cache compiled derivative functions for repeated solves
4. **Benchmarking**: Built-in benchmarking suite for backend selection

---

## 9. References

### 9.1. Documentation Links

- [ADNLPModels.jl Documentation](https://juliasmoothoptimizers.github.io/ADNLPModels.jl/)
- [ExaModels.jl Documentation](https://exanauts.github.io/ExaModels.jl/)
- [NLPModels.jl API](https://juliasmoothoptimizers.github.io/NLPModels.jl/)
- [KernelAbstractions.jl](https://github.com/JuliaGPU/KernelAbstractions.jl)

### 9.2. Package Dependencies

#### ADNLPModels Dependencies
- ADTypes.jl
- ForwardDiff.jl
- ReverseDiff.jl (optional)
- Enzyme.jl (optional)
- Zygote.jl (optional)

#### ExaModels Dependencies
- KernelAbstractions.jl
- CUDA.jl (optional, for GPU)
- AMDGPU.jl (optional, for AMD GPU)
- oneAPI.jl (optional, for Intel GPU)

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-31  
**Next Review**: 2026-02-28
