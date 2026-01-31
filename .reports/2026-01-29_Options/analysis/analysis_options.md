# Analysis of Options for ADNLPModels and ExaModels

This document analyzes the available options for creating `ADNLPModels` and `ExaModels` within the context of `CTModels.jl`. The goal is to provide a comprehensive list of these options to facilitate their formal definition, validation, and exposure via the `Strategies` interface.

## 1. ADNLPModels Options

The options for `ADNLPModels` are derived from the `ADNLPModel` constructors and the `ADModelBackend` configuration.

### 1.1. Model Constructor Options

These options are passed directly to `ADNLPModel(...)`.

| Option Name | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `name` | `String` | `"Generic"` | The name of the model. |
| `minimize` | `Bool` | `true` | Indicates whether the problem is a minimization (`true`) or maximization (`false`) problem. |
| `y0` | `AbstractVector` | `zeros(...)` | Initial estimate for the Lagrangian multipliers (only for constrained problems). |

### 1.2. Backend Options (ADModelBackend)

These options are passed as `kwargs` to the constructor and subsequently to `ADModelBackend`. They control the automatic differentiation strategy.

#### General Backend Configuration

| Option Name | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `backend` | `Symbol` | `:default` | Selects a predefined set of AD backends. Valid values: `:default`, `:optimized`, `:generic`, `:enzyme`, `:zygote`. |
| `matrix_free` | `Bool` | `false` | If `true`, avoids forming explicit matrices for second-order derivatives (returns `EmptyADbackend` for Hessian/Jacobian backends). |
| `show_time` | `Bool` | `false` | If `true`, prints the time taken to generate each backend component during initialization. |

#### Specific Backend Overrides

It is possible to override specific parts of the AD backend by passing the following keys. Each accepts a type subtype of `ADBackend` or `AbstractNLPModel`.

| Option Name | Description | Default (depends on `backend` symbol) |
| :--- | :--- | :--- |
| `gradient_backend` | Backend for Gradient computation | e.g. `ForwardDiffADGradient` |
| `hprod_backend` | Backend for Hessian-vector product | e.g. `ForwardDiffADHvprod` |
| `jprod_backend` | Backend for Jacobian-vector product | e.g. `ForwardDiffADJprod` |
| `jtprod_backend` | Backend for Transpose Jacobian-vector product | e.g. `ForwardDiffADJtprod` |
| `jacobian_backend` | Backend for Jacobian matrix | e.g. `SparseADJacobian` |
| `hessian_backend` | Backend for Hessian matrix | e.g. `SparseADHessian` |
| `ghjvprod_backend` | Backend for $g^T \nabla^2 c(x) v$ | `ForwardDiffADGHjvprod` |
| `hprod_residual_backend` | H-prod for residuals (NLS) | e.g. `ForwardDiffADHvprod` |
| `jprod_residual_backend` | J-prod for residuals (NLS) | e.g. `ForwardDiffADJprod` |
| `jtprod_residual_backend`| Jt-prod for residuals (NLS) | e.g. `ForwardDiffADJtprod` |
| `jacobian_residual_backend`| Jacobian for residuals (NLS) | e.g. `SparseADJacobian` |
| `hessian_residual_backend`| Hessian for residuals (NLS) | e.g. `SparseADHessian` |

### 1.3. Predefined Backend Mappings

The `backend` symbol maps to a dictionary of default types. Here is the mapping:

*   **`:default`**: Uses `ForwardDiff` for everything (sparse where appropriate).
*   **`:optimized`**: Uses `ReverseDiff` for gradient and Hessian products, `ForwardDiff` for Jacobian products.
*   **`:generic`**: Uses `GenericForwardDiff` (useful for non-standard number types).
*   **`:enzyme`**: Uses `Enzyme` (reverse) for gradient, products, and sparse matrices.
*   **`:zygote`**: Uses `Zygote` for gradient, Jacobian, Hessian, and products (some fallbacks to `ForwardDiff` for hprod).

## 2. ExaModels Options

The options for `ExaModels` are identified from the `ExaModeler` implementation.

| Option Name | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `base_type` | `DataType` (`<:AbstractFloat`) | `Float64` | The floating-point precision to be used for the model (e.g., `Float32`, `Float64`). |
| `minimize` | `Union{Bool, Nothing}` | `nothing` | Objective direction. If `nothing`, it typically inherits from the problem definition. |
| `backend` | `Union{Nothing, Backend}` | `nothing` | The computing backend (from `KernelAbstractions`). `nothing` implies CPU. Other examples include `CUDABackend()` or `ROCBackend()`. |

*Note: ExaModels is designed for high-performance usage on GPUs/multi-threaded CPUs. The `backend` and `base_type` are critical for performance tuning.*

## 3. Proposal for Extended Definitions

To fully leverage the `Strategies` module in `CTModels.jl`, we should define `StrategyMetadata` for `ADNLPModeler` encompassing all the identified options above.

### Suggested ADNLPModeler Metadata

```julia
function Strategies.metadata(::Type{<:ADNLPModeler})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name=:name,
            type=String,
            default="Generic",
            description="Name of the model"
        ),
        Strategies.OptionDefinition(;
            name=:minimize,
            type=Bool,
            default=true,
            description="Optimization direction (true for minimization)"
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Symbol,
            default=:default,
            description="Predefined AD backend set (:default, :optimized, :enzyme, :zygote, :generic)",
            validator=v -> v in (:default, :optimized, :enzyme, :zygote, :generic)
        ),
        Strategies.OptionDefinition(;
            name=:matrix_free,
            type=Bool,
            default=false,
            description="Enable matrix-free mode (avoids forming explicit Hessian/Jacobian)"
        ),
        # ... Add definitions for optional backend overrides if necessary
    )
end
```

This structure ensures valid inputs are provided to the constructors and allows for better user guidance.
