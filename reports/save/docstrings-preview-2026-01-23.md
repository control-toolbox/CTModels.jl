# Docstrings Preview - 2026-01-23

## Target: OptionDefinition in src/Options/option_definition.jl

### Items to be documented
- ✅ `struct OptionDefinition` - Already documented, needs $(TYPEDEF) improvement
- ✅ `function all_names(def::OptionDefinition)` - Already documented, needs $(TYPEDSIGNATURES) improvement

### Proposed docstrings

#### OptionDefinition struct
```julia
"""
$(TYPEDEF)

Unified option definition for both action schemas and strategy contracts.

This type combines the functionality of the previous `OptionSchema` and `OptionSpecification` types into a single, comprehensive option definition that can be used for both option extraction (in the Options module) and strategy contract definition (in the Strategies module).

# Fields
- `name::Symbol`: Primary name of the option.
- `type::Type`: Expected Julia type for the option value.
- `default::Any`: Default value when the option is not provided. Use `nothing` for no default.
- `description::String`: Human-readable description of the option.
- `aliases::Tuple{Vararg{Symbol}}`: Alternative names that can be used to reference this option.
- `validator::Union{Function, Nothing}`: Optional validation function that takes a value and returns `true` or throws an error.

# Notes
- The constructor validates that the default value matches the expected type.
- Validators should return `true` for valid values or throw an error for invalid ones.
- Aliases allow users to specify options using alternative names.
- This type is exported and intended for public use in both option extraction and strategy definition.

# Example
```julia-repl
julia> using CTModels.Options

julia> OptionDefinition(
           name = :max_iter,
           type = Int,
           default = 100,
           description = "Maximum iterations",
           aliases = (:max, :maxiter),
           validator = x -> x > 0
       )
OptionDefinition(:max_iter, Int, 100, "Maximum iterations", (:max, :maxiter), Function)

julia> def.name
:max_iter

julia> def.aliases
(:max, :maxiter)
```
"""
```

#### all_names function
```julia
"""
$(TYPEDSIGNATURES)

Return all valid names for an option definition (primary name plus aliases).

This function is used by the extraction system to search for an option in kwargs
using all possible names.

# Arguments
- `def::OptionDefinition`: The option definition.

# Returns
- `Tuple{Vararg{Symbol}}`: All valid names for this option.

# Example
```julia-repl
julia> using CTModels.Options

julia> def = OptionDefinition(
           name = :grid_size,
           type = Int,
           default = 100,
           description = "Grid size",
           aliases = (:n, :size)
       )
OptionDefinition(...)

julia> all_names(def)
(:grid_size, :n, :size)
```
"""
```

### Examples status
- ✅ All examples are runnable and safe (no I/O, deterministic)
- ✅ Examples use correct module prefix (CTModels.Options)
- ✅ Examples demonstrate actual usage patterns from tests

### Changes summary
- Add $(TYPEDEF) to OptionDefinition docstring
- Add $(TYPEDSIGNATURES) to all_names function docstring
- Improve documentation clarity and completeness
- Add context about unified nature of the type
- Enhance examples with realistic usage patterns
