# Strategies Contract Design - Summary

**Date**: 2026-01-22  
**Status**: Validated with user

---

## Core Principle: Type vs Instance Separation

The Strategies contract is split into two clear levels:

### Type-Level Contract (Static Metadata)

**Required methods**:
```julia
# REQUIRED: Symbolic identifier
symbol(::Type{<:MyTool}) = :mytool

# REQUIRED: Option specifications (can be empty ())
metadata(::Type{<:MyTool}) = (
    max_iter = OptionSpec(type=Int, default=100, description="Maximum iterations"),
    tol = OptionSpec(type=Float64, default=1e-6, description="Tolerance"),
)
```

**Optional methods**:
```julia
# OPTIONAL: Package name for display
package_name(::Type{<:MyTool}) = "MyPackage"
```

**Why on the type?**
- Static information that doesn't depend on instance configuration
- Used for registration and routing before instantiation
- Enables efficient introspection without creating instances
- Aligns with Julia's dispatch system

### Instance-Level Contract (Configured State)

**Required structure**:
```julia
struct MyTool <: AbstractStrategy
    options::StrategyOptions  # Unified structure with values + sources
end

# REQUIRED: Access to configured options
options(tool::MyTool) = tool.options
```

**Why on the instance?**
- Options are dynamic and vary per instance
- Each instance has different user-supplied configuration
- Contains effective state (values + provenance)

---

## StrategyOptions Structure

Replaces the previous two-field approach (`options_values`, `options_sources`):

```julia
struct StrategyOptions
    values::NamedTuple      # Effective option values
    sources::NamedTuple     # Provenance (:ct_default or :user)
end
```

**Benefits**:
- Single source of truth for option state
- Clearer semantics
- Easier to pass around and manipulate

---

## Flexible Implementation

Users have two options:

**Option A: Standard field-based** (recommended):
```julia
struct MyTool <: AbstractStrategy
    options::StrategyOptions
end

# options() uses default implementation
```

**Option B: Custom getter**:
```julia
struct MyTool <: AbstractStrategy
    config::Dict  # Custom internal structure
end

# Override getter
function options(tool::MyTool)
    # Convert custom structure to StrategyOptions
    StrategyOptions(...)
end
```

---

## Error Handling

All required methods have default implementations using `CTBase.NotImplemented`:

```julia
function symbol(::Type{T}) where {T<:AbstractStrategy}
    throw(CTBase.NotImplemented(
        "symbol(::Type{<:$T}) must be implemented"
    ))
end

function metadata(::Type{T}) where {T<:AbstractStrategy}
    throw(CTBase.NotImplemented(
        "metadata(::Type{<:$T}) must be implemented. " *
        "Return a NamedTuple of OptionSpec, or () if no options."
    ))
end

function options(tool::T) where {T<:AbstractStrategy}
    if hasfield(T, :options)
        return getfield(tool, :options)
    else
        throw(CTBase.NotImplemented(
            "Tool $T must either have an `options::StrategyOptions` field " *
            "or implement options(::$T)"
        ))
    end
end
```

---

## Naming Conventions

| Concept | Function Name | Level |
|---------|---------------|-------|
| Symbolic identifier | `symbol` | Type |
| Option specifications | `metadata` | Type |
| Package name | `package_name` | Type |
| Configured options | `options` | Instance |
| Build options | `build_strategy_options` | Constructor helper |

---

## Constructor Pattern

Standard pattern for tool constructors:

```julia
function MyTool(; kwargs...)
    options = build_strategy_options(MyTool; kwargs..., strict_keys=true)
    return MyTool(options)
end
```

Where `build_strategy_options`:
- Validates user input against `metadata`
- Merges defaults with user-supplied values
- Tracks provenance (`:ct_default` vs `:user`)
- Returns `StrategyOptions` struct
- `strict_keys=true` by default (rejects unknown options with helpful suggestions)

---

## Tool Families

The design supports hierarchical tool families:

```julia
# Family
abstract type AbstractOptimizationModeler <: AbstractStrategy end

# Family members
struct ADNLPModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end

struct ExaModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end

# Each implements the contract independently
symbol(::Type{<:ADNLPModeler}) = :adnlp
symbol(::Type{<:ExaModeler}) = :exa

metadata(::Type{<:ADNLPModeler}) = (...)
metadata(::Type{<:ExaModeler}) = (...)
```

---

## Validation

For debugging and testing:

```julia
validate_tool_contract(MyTool)  # Checks all required methods are implemented
```

This function will be provided in `src/ocptools/validation.jl`.

---

## Complete Example

```julia
using CTModels.Strategies

# Define tool
struct MyTool <: AbstractStrategy
    options::StrategyOptions
end

# Type-level contract
symbol(::Type{<:MyTool}) = :mytool

metadata(::Type{<:MyTool}) = (
    max_iter = OptionSpec(
        type = Int,
        default = 100,
        description = "Maximum number of iterations"
    ),
    tol = OptionSpec(
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
)

package_name(::Type{<:MyTool}) = "MyToolPackage"

# Constructor
function MyTool(; kwargs...)
    options = build_strategy_options(MyTool; kwargs..., strict_keys=true)
    return MyTool(options)
end

# Usage
tool = MyTool(max_iter=200)  # tol uses default
symbol(tool)  # => :mytool
options(tool).values.max_iter  # => 200
options(tool).sources.max_iter  # => :user
options(tool).sources.tol  # => :ct_default
```
