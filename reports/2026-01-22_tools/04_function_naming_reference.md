# Strategies Function Naming Reference

**Date**: 2026-01-22  
**Status**: Working Document - Updated with metadata types

---

## Core Types

### 1. `StrategyMetadata` - Option specifications (Type-level)

**Description**: Wraps a `NamedTuple` of `OptionSpecification` describing all possible options for a tool type.

**Structure**:
```julia
struct StrategyMetadata
    specs::NamedTuple{Names, <:Tuple{Vararg{OptionSpecification}}}
end

# Make it indexable
Base.getindex(tm::StrategyMetadata, key::Symbol) = tm.specs[key]
Base.keys(tm::StrategyMetadata) = keys(tm.specs)
Base.values(tm::StrategyMetadata) = values(tm.specs)
Base.pairs(tm::StrategyMetadata) = pairs(tm.specs)
Base.iterate(tm::StrategyMetadata, state...) = iterate(tm.specs, state...)
```

**Display** (automatic via `Base.show`):
```julia
function Base.show(io::IO, ::MIME"text/plain", tm::StrategyMetadata)
    println(io, "Tool Metadata:")
    for (name, spec) in pairs(tm.specs)
        print(io, "  • ", name, " :: ", spec.type === missing ? "Any" : spec.type)
        if spec.default !== missing
            print(io, " = ", spec.default)
        end
        println(io)
        if spec.description !== missing
            println(io, "    ", spec.description)
        end
    end
end
```

**Usage**:
```julia
meta = metadata(ADNLPModeler)
# Automatic display:
# Tool Metadata:
#   • show_time :: Bool = false
#     Whether to show timing information
#   • backend :: Symbol = :optimized
#     AD backend used by ADNLPModels

# Indexable:
meta[:show_time]  # Returns OptionSpecification(...)
```

---

### 2. `StrategyOptions` - Configured options (Instance-level)

**Description**: Contains the effective option values and their provenance for a tool instance.

**Structure**:
```julia
struct StrategyOptions
    values::NamedTuple
    sources::NamedTuple  # :ct_default or :user
end

# Make it indexable (returns value, not source)
Base.getindex(to::StrategyOptions, key::Symbol) = to.values[key]
Base.keys(to::StrategyOptions) = keys(to.values)
Base.values(to::StrategyOptions) = values(to.values)
Base.pairs(to::StrategyOptions) = pairs(to.values)
Base.iterate(to::StrategyOptions, state...) = iterate(to.values, state...)
```

**Display** (automatic via `Base.show`):
```julia
function Base.show(io::IO, ::MIME"text/plain", to::StrategyOptions)
    println(io, "Configured Options:")
    for name in keys(to.values)
        val = to.values[name]
        src = to.sources[name]
        src_str = src === :user ? "user" : "default"
        println(io, "  • ", name, " = ", val, " (", src_str, ")")
    end
end
```

**Usage**:
```julia
tool = ADNLPModeler(backend=:sparse)
opts = options(tool)
# Automatic display:
# Configured Options:
#   • show_time = false (default)
#   • backend = :sparse (user)

# Indexable:
opts[:backend]  # Returns :sparse
```

---

## Naming Conventions

### Core Rules

1. **No `get_` prefix** - Follow Julia idiom (getters without side effects don't need `get_`)
2. **Consistent argument order** - Always `(tool_or_type, key)` for functions taking a key
3. **Singular/Plural pattern**:
   - `option_X(tool, key)` - operates on ONE option (singular)
   - `option_Xs(tool)` - operates on ALL options (plural)
4. **Action verbs first** - `build_`, `validate_`, `filter_`, `suggest_`
5. **Type/Instance overloading** - Same function name, different signatures
6. **Automatic display** - Use `Base.show` instead of `show_*` functions

### Pattern Examples

```julia
# ONE option (singular) - always with key argument
option_type(tool, :max_iter)         # Returns: Int
option_description(tool, :max_iter)  # Returns: "Maximum iterations"
option_default(tool, :max_iter)      # Returns: 100

# ALL options (plural) - no key argument
option_names(tool)                   # Returns: (:max_iter, :tol)
option_defaults(tool)                # Returns: (max_iter=100, tol=1e-6)

# Metadata and options (dedicated types with auto-display)
metadata(ADNLPModeler)               # Returns: StrategyMetadata (auto-displays)
options(tool)                        # Returns: StrategyOptions (auto-displays)

# Type/Instance overloading - consistent argument order
option_default(::Type, key)          # Base implementation
option_default(tool, key)            # Convenience → option_default(typeof(tool), key)
```

### Key Insight: Two Function Families

**Family A** - Metadata about ONE option (requires `key`):
- Pattern: `option_X(tool_or_type, key::Symbol)`
- Examples: `option_type`, `option_description`, `option_default`

**Family B** - Metadata about ALL options (no `key`):
- Pattern: `option_Xs(tool_or_type)` (plural)
- Examples: `option_names`, `option_defaults`

---

## Complete Function Reference

### A. Developer Contract (Type-level)

Functions that tool developers **must** implement.

#### 1. `symbol` - Tool symbolic identifier

**Description**: Returns the unique symbol identifying the tool type (`:adnlp`, `:ipopt`, etc.)

**Signatures**:
```julia
symbol(::Type{<:AbstractStrategy}) -> Symbol  # REQUIRED to implement
symbol(tool::AbstractStrategy) -> Symbol      # Convenience → symbol(typeof(tool))
```

**Usage**: Registration, routing in OptimalControl.jl

**Current name**: `get_symbol`

**Decision**: ✅ `symbol` (clear, concise, no `get_` prefix)

---

#### 2. `metadata` - Option metadata

**Description**: Returns a `StrategyMetadata` wrapping a `NamedTuple` of `OptionSpecification` describing all possible options

**Signatures**:
```julia
metadata(::Type{<:AbstractStrategy}) -> StrategyMetadata  # REQUIRED to implement
metadata(tool::AbstractStrategy) -> StrategyMetadata      # Convenience
```

**Usage**: Validation, introspection, documentation generation, automatic display

**Current name**: `_option_specs`

**Decision**: ✅ `metadata` (clear, concise, better than "specifications")

**Display**: Automatic via `Base.show(::StrategyMetadata)` - no need for `show_metadata()`

**Example**:
```julia
meta = metadata(ADNLPModeler)
# Auto-displays:
# Tool Metadata:
#   • show_time :: Bool = false
#     Whether to show timing information
#   • backend :: Symbol = :optimized
#     AD backend used by ADNLPModels

# Indexable:
meta[:show_time].type      # Returns: Bool
meta[:show_time].default   # Returns: false
```

---

#### 3. `package_name` - Associated package

**Description**: Returns the Julia package name associated with the tool (for display purposes)

**Signatures**:
```julia
package_name(::Type{<:AbstractStrategy}) -> Union{String, Missing}  # OPTIONAL to implement
package_name(tool::AbstractStrategy) -> Union{String, Missing}      # Convenience
```

**Usage**: Display in OptimalControl.jl solve output

**Current name**: `tool_package_name`

**Decision**: ✅ `package_name` (clear in Strategies context)

---

### B. Developer Contract (Instance-level)

#### 4. `options` - Configured options

**Description**: Returns the `StrategyOptions` struct containing values and sources

**Signatures**:
```julia
options(tool::AbstractStrategy) -> StrategyOptions  # REQUIRED (field or getter)
```

**Usage**: Access to the effective configuration of an instance

**Current name**: `get_options`

**Decision**: ✅ `options` (simple, clear, returns the complete StrategyOptions struct)

**Display**: Automatic via `Base.show(::StrategyOptions)` - no need for `show_options()`

**Example**:
```julia
tool = ADNLPModeler(backend=:sparse)
opts = options(tool)
# Auto-displays:
# Configured Options:
#   • show_time = false (default)
#   • backend = :sparse (user)

# Indexable:
opts[:backend]  # Returns: :sparse
```

---

### C. Introspection API (Public)

Functions for discovering what a tool can do.

#### 5. `option_names` - List available options

**Description**: Returns a tuple of all option names

**Signatures**:
```julia
option_names(::Type{<:AbstractStrategy}) -> Tuple{Vararg{Symbol}}
option_names(tool::AbstractStrategy) -> Tuple{Vararg{Symbol}}
```

**Usage**: Discovery of available options

**Current name**: `options_keys` (inconsistent plural/order)

**Decision**: ✅ `option_names` (plural, follows `option_Xs` pattern)

---

#### 6. `option_type` - Expected type for an option

**Description**: Returns the Julia type expected for a specific option

**Signatures**:
```julia
option_type(::Type{<:AbstractStrategy}, key::Symbol) -> Type
option_type(tool::AbstractStrategy, key::Symbol) -> Type
```

**Usage**: Validation, documentation

**Current name**: `option_type`

**Decision**: ✅ `option_type` (already correct, consistent argument order)

---

#### 7. `option_description` - Human-readable description

**Description**: Returns the textual description of an option

**Signatures**:
```julia
option_description(::Type{<:AbstractStrategy}, key::Symbol) -> Union{String, Missing}
option_description(tool::AbstractStrategy, key::Symbol) -> Union{String, Missing}
```

**Usage**: Help, documentation generation

**Current name**: `option_description`

**Decision**: ✅ `option_description` (already correct, consistent argument order)

---

#### 8. `option_default` - Default value for ONE option

**Description**: Returns the default value for a specific option

**Signatures**:
```julia
option_default(::Type{<:AbstractStrategy}, key::Symbol) -> Any
option_default(tool::AbstractStrategy, key::Symbol) -> Any
```

**Usage**: Documentation, comparison with effective value

**Current name**: `option_default` (base function) + `get_option_default` (wrapper)

**Decision**: ✅ `option_default` (singular, consistent with `option_type`, `option_description`)

**⚠️ To remove**: `get_option_default(tool, key)` - inconsistent wrapper that just calls `option_default`

---

#### 9. `option_defaults` - All default values

**Description**: Returns a `NamedTuple` of ALL default values (only options with non-missing defaults)

**Signatures**:
```julia
option_defaults(::Type{<:AbstractStrategy}) -> NamedTuple
option_defaults(tool::AbstractStrategy) -> NamedTuple
```

**Usage**: Construction, reset to defaults

**Current name**: `default_options` (inverted order)

**Decision**: ✅ `option_defaults` (plural, follows `option_Xs` pattern)

**Rationale**: Consistent with `option_default` (singular) vs `option_defaults` (plural). The pattern is clear and predictable.

---

### D. Configuration & Access API (Public/Integration)

Functions used by solver engines and constructors.

#### 10. `build_strategy_options` - Construct validated options

**Description**: Validates user kwargs, merges with defaults, tracks provenance, returns `StrategyOptions`

**Signatures**:
```julia
build_strategy_options(::Type{<:AbstractStrategy}; strict_keys::Bool=true, kwargs...) -> StrategyOptions
```

**Usage**: Tool constructors

**Current name**: `_build_ocp_tool_options`

**Decision**: ✅ `build_strategy_options` (clear action verb, concise)

---

#### 11. `option_value` - Effective value of an option

**Description**: Returns the configured value of an option on an instance

**Signatures**:
```julia
option_value(tool::AbstractStrategy, key::Symbol) -> Any
```

**Usage**: Access to effective configuration

**Current name**: `get_option_value`

**Decision**: ✅ `option_value` (consistent with `option_type`, `option_default`)

**Note**: Can also use `options(tool)[key]` for direct access

---

#### 12. `option_source` - Provenance of an option value

**Description**: Returns `:ct_default` or `:user` indicating where the value came from

**Signatures**:
```julia
option_source(tool::AbstractStrategy, key::Symbol) -> Symbol
```

**Usage**: Traceability, debugging, display

**Current name**: `get_option_source`

**Decision**: ✅ `option_source` (consistent pattern, no `get_`)

---

### E. Internal Utilities (Non-exported)

Helper functions for internal use.

#### 13. `validate_options` - Validate user input

**Description**: Checks that kwargs respect metadata (types, known keys)

**Signatures**:
```julia
validate_options(user_nt::NamedTuple, ::Type{<:AbstractStrategy}; strict_keys::Bool) -> Nothing
```

**Usage**: Called by `build_strategy_options`

**Current name**: `_validate_option_kwargs`

**Decision**: ✅ `validate_options` (clear action, no underscore needed if non-exported)

---

#### 14. `filter_options` - Remove specific keys

**Description**: Filters a `NamedTuple` by excluding specified keys

**Signatures**:
```julia
filter_options(nt::NamedTuple, exclude) -> NamedTuple
```

**Usage**: Internal utility (e.g., removing `base_type` in ExaModeler)

**Current name**: `_filter_options`

**Decision**: ✅ `filter_options` (standard Julia verb)

---

#### 15. `suggest_options` - Find similar option names

**Description**: Suggests similar option names for an unknown key (Levenshtein distance)

**Signatures**:
```julia
suggest_options(key::Symbol, ::Type{<:AbstractStrategy}; max_suggestions::Int=3) -> Vector{Symbol}
```

**Usage**: Error messages with helpful suggestions

**Current name**: `_suggest_option_keys`

**Decision**: ✅ `suggest_options` (clear action, plural because suggests multiple)

---

## Summary Table

| Category | Function | Current | Proposed | Returns |
|----------|----------|---------|----------|---------|
| **Type Contract** | Symbolic ID | `get_symbol` | `symbol` | `Symbol` |
| | Option metadata | `_option_specs` | `metadata` | `StrategyMetadata` |
| | Package name | `tool_package_name` | `package_name` | `String/Missing` |
| **Instance Contract** | Options struct | `get_options` | `options` | `StrategyOptions` |
| **Introspection** | List names | `options_keys` | `option_names` | `Tuple{Symbol}` |
| | One type | `option_type` | `option_type` ✓ | `Type` |
| | One description | `option_description` | `option_description` ✓ | `String/Missing` |
| | One default | `option_default` | `option_default` ✓ | `Any` |
| | | `get_option_default` | ❌ Remove | - |
| | All defaults | `default_options` | `option_defaults` | `NamedTuple` |
| **Configuration** | Build | `_build_ocp_tool_options` | `build_strategy_options` | `StrategyOptions` |
| | Get value | `get_option_value` | `option_value` | `Any` |
| | Get source | `get_option_source` | `option_source` | `Symbol` |
| **Internal** | Validate | `_validate_option_kwargs` | `validate_options` | `Nothing` |
| | Filter | `_filter_options` | `filter_options` | `NamedTuple` |
| | Suggest | `_suggest_option_keys` | `suggest_options` | `Vector{Symbol}` |

---

## Key Changes Summary

### New Types
- ✅ `StrategyMetadata` - wraps metadata NamedTuple, indexable, auto-displays
- ✅ `StrategyOptions` - already exists, make indexable, add auto-display

### To Remove
- ❌ `get_option_default(tool, key)` - inconsistent wrapper
- ❌ `show_options()` - replaced by automatic `Base.show(::StrategyMetadata)`

### To Rename (11 functions)
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

### Already Correct (3 functions)
- ✅ `option_type`
- ✅ `option_description`
- ✅ `option_default`

---

## Design Rationale

### Why `StrategyMetadata` instead of just `NamedTuple`?

**Benefits**:
1. **Type safety** - Clear distinction between metadata and other NamedTuples
2. **Automatic display** - Can override `Base.show` for nice formatting
3. **Indexable** - Can make it behave like a NamedTuple with `Base.getindex`
4. **Extensible** - Can add methods later without breaking changes

### Why `metadata` instead of `specifications`?

**Reasons**:
- Shorter and clearer
- "Metadata" is a common term in programming
- Avoids confusion with "specs" (could mean specifications or spectral)
- More general: could include non-option metadata in the future

### Why automatic display via `Base.show`?

**Julia idiom**: Types display themselves automatically in the REPL

**Benefits**:
- No need for `show_metadata()` or `show_options()` functions
- Consistent with Julia ecosystem
- Users can still customize display if needed
- Works automatically in notebooks, REPL, logging

**Example**:
```julia
# Just typing the variable shows it
meta = metadata(ADNLPModeler)
# Automatically displays nicely formatted output

# vs old way
show_options(ADNLPModeler)  # Explicit function call
```

### Why make types indexable?

**Convenience**: Access like a NamedTuple without `.specs` or `.values`

```julia
# With indexing
meta[:show_time]     # Clean
opts[:backend]       # Clean

# Without indexing
meta.specs[:show_time]   # Verbose
opts.values[:backend]    # Verbose
```

---

## Migration Notes

All renamed functions will need updates in:
- `src/ocptools/` (new module)
- `src/nlp/nlp_backends.jl` (ADNLPModeler, ExaModeler)
- `test/nlp/test_options_schema.jl` (test suite)
- CTDirect.jl (discretizers)
- CTSolvers.jl (solvers)
- OptimalControl.jl (usage)

New types to implement:
- `StrategyMetadata` with `Base.show`, `Base.getindex`, etc.
- Update `StrategyOptions` to add `Base.show`, `Base.getindex`, etc.
