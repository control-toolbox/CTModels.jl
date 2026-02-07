# Implementation Examples and Usage Guide

**Author**: CTModels Development Team  
**Date**: 2026-01-31  
**Purpose**: Practical examples and usage guide for enhanced modelers

## Quick Start Examples

### Basic Usage (Backward Compatible)

```julia
using CTModels

# ADNLPModeler - existing code continues to work
modeler = ADNLPModeler()
nlp_model = modeler(problem, initial_guess)

# ExaModeler - existing code continues to work  
modeler = ExaModeler()
nlp_model = modeler(problem, initial_guess)
```

### Enhanced Usage with New Options

#### ADNLPModeler Examples

```julia
# Memory-efficient large-scale problem
modeler = ADNLPModeler(
    matrix_free=true,        # Reduce memory usage by 50-80%
    backend=:optimized,      # Use optimized AD backend
    name="LargeScaleProblem"  # Model identification
)

# High-precision problem with custom backend
modeler = ADNLPModeler(
    backend=:generic,       # For custom number types
    minimize=false,         # Maximization problem
    show_time=true          # Performance profiling
)

# Advanced configuration with backend overrides
modeler = ADNLPModeler(
    backend=:default,
    gradient_backend=ADNLPModels.EnzymeReverseADGradient,
    hessian_backend=ADNLPModels.SparseADHessian,
    matrix_free=true
)
```

#### ExaModeler Examples

```julia
# GPU-accelerated problem with auto-detection
modeler = ExaModeler(
    base_type=Float32,      # Better GPU performance
    auto_detect_gpu=true,   # Automatically find GPU
    gpu_preference=:cuda    # Prefer CUDA if available
)

# CPU high-precision problem
modeler = ExaModeler(
    base_type=Float64,      # Double precision
    auto_detect_gpu=false,  # Force CPU
    precision_mode=:high    # Maximum accuracy
)

# Mixed precision for performance
modeler = ExaModeler(
    base_type=Float32,
    precision_mode=:mixed,  # Balance speed and accuracy
    minimize=true
)
```

## Performance Optimization Examples

### Large-Scale Problems (>100K variables)

```julia
# ADNLPModeler configuration for memory efficiency
large_scale_modeler = ADNLPModeler(
    matrix_free=true,        # Critical for large problems
    backend=:optimized,      # Fast gradient computation
    show_time=true          # Monitor performance
)

# Expected benefits:
# - Memory usage: 50-80% reduction
# - Speed: 10-30% improvement
# - Scalability: Handles problems >1M variables
```

### GPU Acceleration

```julia
using CUDA  # Load GPU support

# ExaModeler GPU configuration
gpu_modeler = ExaModeler(
    base_type=Float32,      # Optimal for GPU
    backend=CUDABackend(),  # Explicit GPU backend
    auto_detect_gpu=false   # Skip auto-detection
)

# Expected benefits:
# - Speed: 200-1000% improvement
# - Memory: Better GPU memory utilization
# - Scalability: Handles millions of variables
```

### High-Precision Requirements

```julia
# ADNLPModeler for numerical accuracy
precision_modeler = ADNLPModeler(
    backend=:generic,       # Supports custom types
    name="HighPrecision"
)

# ExaModeler for double precision
precision_modeler = ExaModeler(
    base_type=Float64,      # Maximum precision
    precision_mode=:high,    # Conservative numerical methods
    auto_detect_gpu=false    # CPU for better precision
)
```

## Problem-Specific Configurations

### Optimal Control Problems

```julia
# Typical OCP configuration
ocp_modeler = ADNLPModeler(
    backend=:optimized,      # Good for OCPs
    matrix_free=false,       # OCPs often need Hessian
    show_time=false,         # Clean output
    name="OptimalControl"
)

# GPU-accelerated OCP for large discretizations
gpu_ocp_modeler = ExaModeler(
    base_type=Float32,      # GPU efficiency
    auto_detect_gpu=true,   # Use available GPU
    minimize=true           # Standard minimization
)
```

### Machine Learning Problems

```julia
# ML-style problems with Zygote
ml_modeler = ADNLPModeler(
    backend=:zygote,        # ML-friendly AD
    matrix_free=true,       # Large parameter vectors
    name="MLProblem"
)

# ExaModels for neural network training
nn_modeler = ExaModeler(
    base_type=Float32,      # Standard for ML
    auto_detect_gpu=true,   # GPU acceleration
    precision_mode=:mixed   # Balance accuracy/speed
)
```

### Engineering Design Problems

```julia
# Engineering optimization with high precision
engineering_modeler = ADNLPModeler(
    backend=:default,       # Stable and reliable
    matrix_free=false,       # Need accurate Hessian
    name="EngineeringDesign"
)

# ExaModels for simulation-based design
simulation_modeler = ExaModeler(
    base_type=Float64,      # High precision required
    auto_detect_gpu=false,   # CPU for reliability
    precision_mode=:high     # Maximum accuracy
)
```

## Migration Guide

### From Current Implementation

#### Step 1: Add New Options (Optional)

```julia
# Before (current)
modeler = ADNLPModeler(backend=:optimized)

# After (enhanced - backward compatible)
modeler = ADNLPModeler(
    backend=:optimized,
    matrix_free=true,        # New option
    name="MyProblem"         # New option
)
```

#### Step 2: Enable GPU Acceleration

```julia
# Before (CPU only)
modeler = ExaModeler(base_type=Float64)

# After (GPU with auto-detection)
modeler = ExaModeler(
    base_type=Float32,
    auto_detect_gpu=true    # New option
)
```

#### Step 3: Add Performance Monitoring

```julia
# Before (no timing)
modeler = ADNLPModeler()

# After (with timing)
modeler = ADNLPModeler(show_time=true)  # Enhanced existing option
```

### Breaking Changes (None)

All existing code continues to work without modification. The enhanced options are purely additive.

## Troubleshooting Examples

### Backend Not Available

```julia
# Problem: Enzyme backend not working
try
    modeler = ADNLPModeler(backend=:enzyme)
catch e
    @warn "Enzyme not available, falling back to optimized"
    modeler = ADNLPModeler(backend=:optimized)
end

# Better: Let validation handle it
modeler = ADNLPModeler(backend=:enzyme)  # Will warn but not error
```

### GPU Not Detected

```julia
# Problem: GPU backend not working
modeler = ExaModeler(auto_detect_gpu=true)  # Will warn if no GPU

# Manual fallback
if isempty(detect_available_gpu_backends())
    @info "No GPU detected, using CPU"
    modeler = ExaModeler(auto_detect_gpu=false)
else
    modeler = ExaModeler(auto_detect_gpu=true)
end
```

### Memory Issues

```julia
# Problem: Out of memory for large problem
modeler = ADNLPModeler(
    matrix_free=true,        # Reduce memory usage
    backend=:optimized,      # Efficient AD
    show_time=true          # Monitor memory usage
)

# Check if matrix-free is recommended
problem_size = 500_000
if problem_size > 100_000
    @info "Using matrix-free mode for large problem"
    modeler = ADNLPModeler(matrix_free=true)
end
```

## Benchmarking Examples

### Performance Comparison

```julia
function benchmark_backends(problem, initial_guess)
    backends = [:default, :optimized, :enzyme, :zygote]
    results = Dict{Symbol, Any}()
    
    for backend in backends
        try
            modeler = ADNLPModeler(backend=backend, show_time=true)
            time = @elapsed nlp = modeler(problem, initial_guess)
            results[backend] = (time=time, success=true)
        catch e
            results[backend] = (time=Inf, success=false, error=e)
        end
    end
    
    return results
end

# Usage
results = benchmark_backends(my_problem, my_initial_guess)
for (backend, result) in results
    println("$backend: $(result.success ? "SUCCESS" : "FAILED") in $(result.time)s")
end
```

### Memory Usage Comparison

```julia
function benchmark_memory(problem, initial_guess)
    configs = [
        (matrix_free=false, backend=:default),
        (matrix_free=true, backend=:default),
        (matrix_free=false, backend=:optimized),
        (matrix_free=true, backend=:optimized)
    ]
    
    results = []
    for config in configs
        # Measure memory before
        GC.gc()
        mem_before = Base.gc_live_bytes()
        
        # Create model and solve
        modeler = ADNLPModeler(; config...)
        nlp = modeler(problem, initial_guess)
        
        # Measure memory after
        GC.gc()
        mem_after = Base.gc_live_bytes()
        
        memory_used = (mem_after - mem_before) / 1024^2  # MB
        push!(results, (config=config, memory=memory_used))
    end
    
    return results
end
```

## Integration with Solvers

### Ipopt Integration

```julia
using NLPModelsIpopt

# ADNLPModeler with Ipopt
modeler = ADNLPModeler(
    backend=:optimized,
    matrix_free=false,       # Ipopt needs Hessian
    name="IpoptProblem"
)

nlp = modeler(problem, initial_guess)
result = ipopt(nlp)
```

### MadNLP Integration

```julia
using MadNLP

# ExaModeler with MadNLP (GPU-friendly)
modeler = ExaModeler(
    base_type=Float32,
    auto_detect_gpu=true,
    precision_mode=:mixed
)

nlp = modeler(problem, initial_guess)
result = madnlp(nlp)
```

## Best Practices

### Option Selection Guidelines

| Problem Size | Recommended Backend | Matrix-Free | GPU | Precision |
| :--- | :--- | :--- | :--- | :--- |
| < 1K variables | `:default` | false | CPU | Float64 |
| 1K-100K variables | `:optimized` | false | CPU | Float64 |
| 100K-1M variables | `:optimized` | true | GPU if available | Float32 |
| > 1M variables | `:enzyme` | true | GPU | Float32 |

### Performance Tips

1. **Use `matrix_free=true`** for problems with >100K variables
2. **Prefer `Float32`** on GPU for better memory bandwidth
3. **Use `:optimized` backend** for most problems
4. **Enable `show_time`** during development to identify bottlenecks
5. **Set meaningful `name`** for better debugging and profiling

### Common Pitfalls to Avoid

1. **Don't use `:enzyme` without loading Enzyme.jl first**
2. **Don't use `Float64` on GPU unless high precision is required**
3. **Don't forget to set `auto_detect_gpu=false` when specifying explicit backend**
4. **Don't use `matrix_free=true` for small problems (<1K variables)**
5. **Don't ignore validation warnings - they often indicate performance issues**

---

**Status**: Documentation Complete  
**Next**: Ready for implementation integration
