# Strategies Module - Complete Contract Specification

**Date**: 2026-01-22  
**Status**: ✅ **REFERENCE** - Final Contract Definition

---

## TL;DR

**Ce document définit le contrat** que chaque stratégie doit implémenter. Il sépare clairement le **Type-Level Contract** (métadonnées statiques) du **Instance-Level Contract** (état configuré).

**Méthodes requises** :

- ✅ `symbol(::Type{<:MyStrategy})` - ID unique (ex: `:adnlp`)
- ✅ `metadata(::Type{<:MyStrategy})` - Retourne un `StrategyMetadata`
- ✅ `options(strategy)` - Retourne un `StrategyOptions`
- ✅ `MyStrategy(; kwargs...)` - Constructeur obligatoire (via `build_strategy_options`)

**Concepts clés** :

- **Aliases** : Noms alternatifs pour les options (ex: `init` pour `initial_guess`)
- **Validators** : Fonctions de validation (ex: `x -> x > 0`)

**Voir aussi** :

- [abstract_strategy.jl](code/Strategies/contract/abstract_strategy.jl) - Contrat de base
- [metadata.jl](code/Strategies/contract/metadata.jl) - `StrategyMetadata`
- [option_specification.jl](code/Strategies/contract/option_specification.jl) - `OptionSpecification`

---

## Core Principle: Type vs Instance Separation

The Strategies contract is split into two clear levels to separate static descriptions from active configuration.

### Type-Level Contract (Static Metadata)

This level contains information that is common to all instances of a strategy type.

**Why on the type?**

- **Optimstration** : Permet l'introspection et la validation sans créer d'instances.
- **Routing** : Utilisé par `OptimalControl.jl` pour décider quelle stratégie utiliser à partir d'un symbole.
- **Dispatch** : Aligné avec le système de dispatch de Julia où le type porte la sémantique.

### Instance-Level Contract (Configured State)

This level contains the effective configuration of a specific strategy instance.

**Why on the instance?**

- **Dynamisme** : Un utilisateur peut créer deux instances de la même stratégie avec des réglages différents.
- **Provenance** : Chaque instance suit l'origine de ses options (`:user` vs `:default`).
- **Encapsulation** : L'état configuré appartient à l'objet qui va l'exécuter.

---

## Strategy Contract

Every strategy **must** implement the following contract to work with the Strategies module and registration system.

---

## Type-Level Contract (Static Metadata)

### Required Methods

#### 1. `symbol(::Type{<:MyStrategy}) -> Symbol`

**Purpose**: Returns the unique identifier for the strategy type.

**Requirements**:

- Must return a `Symbol` (e.g., `:adnlp`, `:ipopt`)
- Must be **unique within the strategy's family**
- Should be short and memorable

**Example**:

```julia
symbol(::Type{<:ADNLPModeler}) = :adnlp
```

---

#### 2. `metadata(::Type{<:MyStrategy}) -> StrategyMetadata`

**Purpose**: Returns the option specifications for the strategy.

**Requirements**:

- Must return a `StrategyMetadata` wrapping a `NamedTuple` of `OptionSpecification`
- Can return empty metadata: `StrategyMetadata(NamedTuple())`

**Example**:

```julia
metadata(::Type{<:ADNLPModeler}) = StrategyMetadata((
    backend = OptionSpecification(
        type = Symbol,
        default = :optimized,
        description = "AD backend used by ADNLPModels",
        aliases = (:alg, :method)  # Aliases for better UX
    ),
    show_time = OptionSpecification(
        type = Bool,
        default = false,
        description = "Whether to show timing information"
    ),
    grid_size = OptionSpecification(
        type = Int,
        default = 100,
        description = "Grid size for discretization",
        validator = x -> x > 0  # Custom validator
    ),
))
```

---

### Optional Methods

#### 3. `package_name(::Type{<:MyStrategy}) -> Union{String, Missing}`

**Purpose**: Returns the Julia package name for display purposes.

**Default**: Returns `missing`

**Example**:

```julia
package_name(::Type{<:ADNLPModeler}) = "ADNLPModels"
```

---

## Instance-Level Contract (Configured State)

### Required Field or Getter

#### 4. `options(strategy::MyStrategy) -> StrategyOptions`

**Purpose**: Returns the configured options for the strategy instance.

**Requirements**:

- Either have an `options::StrategyOptions` field (recommended)
- Or implement a custom `options()` getter

**Default implementation**: Accesses `.options` field

---

## Flexible Implementation

Users have two options for the instance-level contract:

**Option A: Standard field-based** (recommended):

```julia
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end

# options() uses default implementation that accesses the .options field
```

**Option B: Custom getter**:

```julia
struct MyStrategy <: AbstractStrategy
    config::Dict  # Custom internal structure
end

# Override getter to convert internal state to StrategyOptions on the fly
function options(strategy::MyStrategy)
    return StrategyOptions(NamedTuple(strategy.config), ...)
end
```

---

## Tool Families

The design supports hierarchical tool families to organize registration:

```julia
# 1. Define the family
abstract type AbstractOptimizationModeler <: AbstractStrategy end

# 2. Define family members
struct ADNLPModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end

struct ExaModeler <: AbstractOptimizationModeler
    options::StrategyOptions
end

# 3. Each implements the contract independently
symbol(::Type{<:ADNLPModeler}) = :adnlp
symbol(::Type{<:ExaModeler}) = :exa
```

---

## Error Handling

All required methods have default implementations in `Strategies` that throw `CTBase.NotImplemented` with helpful messages when not overridden.

For example, the default implementation of `options()` is:

```julia
function options(tool::T) where {T<:AbstractStrategy}
    if hasfield(T, :options)
        return getfield(tool, :options)
    else
        throw(CTBase.NotImplemented("Strategy $T must either have an `options::StrategyOptions` field or implement options(::$T)"))
    end
end
```

---

## Constructor Contract

### Required Constructor

#### 5. `MyStrategy(; kwargs...) -> MyStrategy`

**Purpose**: Keyword-only constructor for building strategy instances.

**Requirements**:

- **Must** accept keyword arguments
- **Must** use `build_strategy_options()` to validate and merge options
- **Must** return an instance of the strategy

**Standard pattern**:

```julia
function MyStrategy(; kwargs...)
    options = build_strategy_options(MyStrategy; kwargs...)
    return MyStrategy(options)
end
```

**Why required**: The registration system uses this constructor to build strategies from IDs:

```julia
# This is what build_strategy() does internally:
T = type_from_id(:adnlp, AbstractOptimizationModeler)
return T(; backend=:sparse)  # ← Calls the kwargs constructor
```

---

## Complete Example

```julia
using CTModels.Strategies

# 1. Define the strategy type
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end

# 2. Type-level contract (REQUIRED)
symbol(::Type{<:MyStrategy}) = :mystrategy

metadata(::Type{<:MyStrategy}) = StrategyMetadata((
    max_iter = OptionSpecification(
        type = Int,
        default = 100,
        description = "Maximum number of iterations"
    ),
    tol = OptionSpecification(
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
))

# 3. Package name (OPTIONAL)
package_name(::Type{<:MyStrategy}) = "MyStrategyPackage"

# 4. Constructor (REQUIRED)
function MyStrategy(; kwargs...)
    options = build_strategy_options(MyStrategy; kwargs...)
    return MyStrategy(options)
end

# That's it! The strategy is now fully compliant.
```

---

## Usage

Once a strategy implements the contract, it can be:

### 1. Used directly

```julia
strategy = MyStrategy(max_iter=200, tol=1e-8)
```

### 2. Registered in a family

```julia
# In OptimalControl.jl - Create registry with explicit registration
registry = create_registry(
    AbstractMyStrategyFamily => (MyStrategy, OtherStrategy)
)
```

### 3. Built from ID

```julia
strategy = build_strategy(:mystrategy, AbstractMyStrategyFamily, registry; max_iter=200)
```

### 4. Introspected

```julia
symbol(strategy)                    # => :mystrategy
metadata(strategy)                  # => StrategyMetadata (auto-displays)
options(strategy)                   # => StrategyOptions (auto-displays)
option_names(strategy)              # => (:max_iter, :tol)
option_value(strategy, :max_iter)   # => 200
option_source(strategy, :max_iter)  # => :user
```

---

## Contract Validation

The Strategies module provides a validation function for testing:

```julia
using CTModels.Strategies: validate_strategy_contract

# In tests
@test validate_strategy_contract(MyStrategy)
```

This checks:

- ✅ `symbol()` is implemented
- ✅ `metadata()` is implemented
- ✅ Constructor `MyStrategy(; kwargs...)` exists and works

---

## Summary: Contract Checklist

For a strategy to be fully compliant:

- [ ] **Type-level**:
  - [ ] `symbol(::Type{<:MyStrategy})` implemented
  - [ ] `metadata(::Type{<:MyStrategy})` implemented
  - [ ] `package_name(::Type{<:MyStrategy})` implemented (optional)

- [ ] **Instance-level**:
  - [ ] Has `options::StrategyOptions` field OR implements `options(strategy)`

- [ ] **Constructor**:
  - [ ] `MyStrategy(; kwargs...)` constructor implemented
  - [ ] Uses `build_strategy_options()` for validation

- [ ] **Testing**:
  - [ ] `validate_strategy_contract(MyStrategy)` passes

---

## Migration from Old Contract

### Old (AbstractOCPTool)

```julia
struct MyTool <: AbstractOCPTool
    options_values::NamedTuple
    options_sources::NamedTuple
end

get_symbol(::Type{<:MyTool}) = :mytool
_option_specs(::Type{<:MyTool}) = (...)
tool_package_name(::Type{<:MyTool}) = "MyPackage"

function MyTool(; kwargs...)
    values, sources = _build_ocp_tool_options(MyTool; kwargs...)
    return MyTool(values, sources)
end
```

### New (AbstractStrategy)

```julia
struct MyStrategy <: AbstractStrategy
    options::StrategyOptions  # ← Unified structure
end

symbol(::Type{<:MyStrategy}) = :mystrategy  # ← No get_
metadata(::Type{<:MyStrategy}) = StrategyMetadata(...)  # ← Returns wrapper
package_name(::Type{<:MyStrategy}) = "MyPackage"  # ← No tool_ prefix

function MyStrategy(; kwargs...)
    options = build_strategy_options(MyStrategy; kwargs...)  # ← Unified
    return MyStrategy(options)
end
```

**Key changes**:

1. `options_values` + `options_sources` → `options::StrategyOptions`
2. `get_symbol` → `symbol`
3. `_option_specs` → `metadata` (returns `StrategyMetadata`)
4. `tool_package_name` → `package_name`
5. `_build_ocp_tool_options` → `build_strategy_options`
