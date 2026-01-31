# Strategies Module - Design Decisions Summary

**Date**: 2026-01-22  
**Status**: Final - Ready for Implementation

---

## Executive Summary

This document summarizes all design decisions for the new `Strategies` module in CTModels, which replaces the current `AbstractOCPTool` system with a cleaner, more consistent architecture.

---

## 1. Core Naming Decisions

### Module and Types

| Concept | Old Name | New Name | Rationale |
|---------|----------|----------|-----------|
| Module | `OCPTools` | `Strategies` | More general, not OCP-specific |
| Base type | `AbstractOCPTool` | `AbstractStrategy` | Pattern Strategy, clearer intent |
| Metadata wrapper | N/A (NamedTuple) | `StrategyMetadata` | Type safety, auto-display |
| Options wrapper | `ToolOptions` | `StrategyOptions` | Consistency with base type |
| Option spec | `OptionSpec` | `OptionSpecification` | More explicit |

### Function Names

| Category | Function | Old Name | New Name |
|----------|----------|----------|----------|
| **Type Contract** | Symbol | `get_symbol` | `symbol` |
| | Metadata | `_option_specs` | `metadata` |
| | Package | `tool_package_name` | `package_name` |
| **Instance Contract** | Options | `get_options` | `options` |
| **Introspection** | Names | `options_keys` | `option_names` |
| | Type | `option_type` | `option_type` ✓ |
| | Description | `option_description` | `option_description` ✓ |
| | One default | `option_default` | `option_default` ✓ |
| | All defaults | `default_options` | `option_defaults` |
| **Configuration** | Build | `_build_ocp_tool_options` | `build_strategy_options` |
| | Value | `get_option_value` | `option_value` |
| | Source | `get_option_source` | `option_source` |

---

## 2. Naming Conventions

### Core Rules

1. **No `get_` prefix** - Follow Julia idiom
2. **Consistent argument order** - Always `(strategy_or_type, key)`
3. **Singular/Plural pattern**:
   - `option_X(strategy, key)` - ONE option
   - `option_Xs(strategy)` - ALL options
4. **Action verbs first** - `build_`, `validate_`, `filter_`
5. **Automatic display** - Use `Base.show` instead of `show_*` functions

### Pattern Families

**Family A** - ONE option (with key):
```julia
option_type(strategy, :max_iter)
option_description(strategy, :max_iter)
option_default(strategy, :max_iter)
option_value(strategy, :max_iter)
option_source(strategy, :max_iter)
```

**Family B** - ALL options (no key):
```julia
option_names(strategy)      # (:max_iter, :tol)
option_defaults(strategy)   # (max_iter=100, tol=1e-6)
```

---

## 3. Type Architecture

### Core Types

```julia
# Base type
abstract type AbstractStrategy end

# Metadata wrapper (indexable, auto-displays)
struct StrategyMetadata
    specs::NamedTuple{Names, <:Tuple{Vararg{OptionSpecification}}}
end

# Options wrapper (indexable, auto-displays)
struct StrategyOptions
    values::NamedTuple
    sources::NamedTuple  # :ct_default or :user
end
```

### Indexability

Both `StrategyMetadata` and `StrategyOptions` implement:
- `Base.getindex` - access like a NamedTuple
- `Base.keys`, `Base.values`, `Base.pairs`
- `Base.iterate` - for iteration

```julia
meta = metadata(IpoptSolver)
meta[:max_iter]  # Returns OptionSpecification

opts = options(solver)
opts[:max_iter]  # Returns value (e.g., 1000)
```

### Automatic Display

Both types implement `Base.show(::MIME"text/plain", ...)` for nice REPL display.

---

## 4. Contract Design

### Type-Level Contract (Static Metadata)

**Required**:
```julia
symbol(::Type{<:MyStrategy}) -> Symbol
metadata(::Type{<:MyStrategy}) -> StrategyMetadata
```

**Optional**:
```julia
package_name(::Type{<:MyStrategy}) -> Union{String, Missing}
```

### Instance-Level Contract (Configured State)

**Required**:
```julia
options(strategy::MyStrategy) -> StrategyOptions
```

**Default implementation**: Accesses `.options` field or throws `CTBase.NotImplemented`

---

## 5. Module Structure

### File Organization

```
src/strategies/
├── Strategies.jl          # Module definition, exports, includes
├── types.jl               # Type definitions only (no methods)
├── contract.jl            # Interface methods to implement
├── display.jl             # Base.show and indexability
├── introspection.jl       # Public API for querying metadata
├── configuration.jl       # Building and accessing options
├── validation.jl          # Internal validation functions
├── utilities.jl           # Generic helpers
├── registration.jl        # @register_strategies macro
└── README.md              # Developer guide
```

### File Responsibilities

| File | Purpose | Exports | Dependencies |
|------|---------|---------|--------------|
| `types.jl` | Type definitions | Types | None |
| `contract.jl` | Interface to implement | No | `types.jl` |
| `display.jl` | Auto-display, indexing | No (Base.show) | `types.jl` |
| `utilities.jl` | Generic helpers | No | None |
| `validation.jl` | Validation logic | No | `utilities.jl` |
| `introspection.jl` | Public query API | Yes | `contract.jl` |
| `configuration.jl` | Build/access options | Yes | `validation.jl` |
| `registration.jl` | Registration macro | Yes (macro) | `contract.jl` |

### Include Order

```julia
include("types.jl")           # 1. Base types (no dependencies)
include("contract.jl")        # 2. Interface contract (uses types)
include("display.jl")         # 3. Display and indexing (uses types)
include("utilities.jl")       # 4. Generic helpers (no dependencies)
include("validation.jl")      # 5. Validation (uses utilities)
include("introspection.jl")   # 6. Public API (uses contract)
include("configuration.jl")   # 7. Build options (uses validation)
include("registration.jl")    # 8. Registration macro (uses contract)
```

---

## 6. Key Design Principles

### 1. Consistency Over Brevity

- `option_defaults` instead of `default_options` (consistent with `option_default`)
- `option_names` instead of `optionnames` (explicit and clear)

### 2. Julia Idioms

- No `get_` prefix for pure getters
- `Base.show` for automatic display
- Indexable types for ergonomic access

### 3. Type Safety

- Dedicated types (`StrategyMetadata`, `StrategyOptions`) instead of raw `NamedTuple`
- Clear distinction between metadata and configuration

### 4. Separation of Concerns

- **types.jl**: Pure type definitions
- **contract.jl**: Interface methods (what to implement)
- **display.jl**: Presentation logic
- **introspection.jl**: Public query API
- **configuration.jl**: Building and accessing options
- **validation.jl**: Validation logic
- **utilities.jl**: Generic helpers
- **registration.jl**: Optional registration system

### 5. Flexibility

- Support for custom getters (not just field access)
- Tool families via abstract type hierarchy
- Optional metadata (can return empty `()`)

---

## 7. Breaking Changes

### Removed Functions

- ❌ `get_option_default(strategy, key)` - use `option_default(strategy, key)`
- ❌ `show_options()` - automatic via `Base.show(::StrategyMetadata)`

### Renamed Functions (12 total)

- `get_symbol` → `symbol`
- `_option_specs` → `metadata`
- `tool_package_name` → `package_name`
- `get_options` → `options`
- `options_keys` → `option_names`
- `default_options` → `option_defaults`
- `_build_ocp_tool_options` → `build_strategy_options`
- `get_option_value` → `option_value`
- `get_option_source` → `option_source`
- `_validate_option_kwargs` → `validate_options`
- `_filter_options` → `filter_options`
- `_suggest_option_keys` → `suggest_options`

---

## 8. Migration Impact

### Packages to Update

1. **CTModels.jl** - New `Strategies` module
2. **CTDirect.jl** - Discretizers use `AbstractStrategy`
3. **CTSolvers.jl** - Solvers use `AbstractStrategy`
4. **OptimalControl.jl** - Update function calls

### Estimated Effort

- CTModels: ~3-5 days (new module + migration)
- CTDirect: ~1 day (rename types, update calls)
- CTSolvers: ~1 day (rename types, update calls)
- OptimalControl: ~0.5 day (update function calls)

---

## 9. Documentation

### Reference Documents

1. **01_ocptools_restructuring_analysis.md** - Initial analysis and architecture
2. **02_ocptools_contract_design.md** - Contract design details
3. **04_function_naming_reference.md** - Complete function reference (authoritative)
4. **05_design_decisions_summary.md** - This document

### Developer Guide

Location: `src/strategies/README.md`

Contents:
- Quick start guide
- Complete contract explanation
- Examples for each tool category
- Testing guidelines

---

## 10. Next Steps

1. ✅ Design complete - all decisions documented
2. ⏭️ Implement `Strategies` module in CTModels
3. ⏭️ Migrate existing tools (ADNLPModeler, ExaModeler)
4. ⏭️ Update tests
5. ⏭️ Update dependent packages
6. ⏭️ Write comprehensive documentation

---

## Appendix: Quick Reference

### Typical Strategy Implementation

```julia
using CTModels.Strategies

struct MyStrategy <: AbstractStrategy
    options::StrategyOptions
end

# Type contract
symbol(::Type{<:MyStrategy}) = :mystrategy

metadata(::Type{<:MyStrategy}) = StrategyMetadata((
    max_iter = OptionSpecification(
        type = Int,
        default = 100,
        description = "Maximum iterations"
    ),
))

package_name(::Type{<:MyStrategy}) = "MyPackage"

# Constructor
MyStrategy(; kwargs...) = MyStrategy(build_strategy_options(MyStrategy; kwargs...))

# Usage
strategy = MyStrategy(max_iter=200)
symbol(strategy)              # :mystrategy
options(strategy)             # Auto-displays nicely
options(strategy)[:max_iter]  # 200
```

---

## Appendix: File Size Estimates

| File | Lines |
|------|-------|
| `Strategies.jl` | ~45 |
| `types.jl` | ~60 |
| `contract.jl` | ~70 |
| `display.jl` | ~55 |
| `introspection.jl` | ~60 |
| `configuration.jl` | ~50 |
| `validation.jl` | ~65 |
| `utilities.jl` | ~55 |
| `registration.jl` | ~100 |
| `README.md` | ~300 |
| **Total** | **~860 lines** |

Compare to current: 581 lines in one file → Better organized, slightly more code due to documentation and structure.
