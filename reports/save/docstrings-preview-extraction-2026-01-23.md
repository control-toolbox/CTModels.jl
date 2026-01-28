# Docstrings Preview - Extraction API - 2026-01-23

## Target: src/Options/extraction.jl

### Items to be documented
- ✅ `function extract_option(kwargs::NamedTuple, def::OptionDefinition)` - Well documented, needs OptionDefinition context
- ✅ `function extract_options(kwargs::NamedTuple, defs::Vector{OptionDefinition})` - Well documented, needs OptionDefinition context
- ✅ `function extract_options(kwargs::NamedTuple, defs::NamedTuple)` - Well documented, needs OptionDefinition context

### Proposed docstrings

#### extract_option function
```julia
"""
$(TYPEDSIGNATURES)

Extract a single option from a NamedTuple using its definition, with support for aliases.

This function searches through all valid names (primary name + aliases) in the definition
to find the option value in the provided kwargs. If found, it validates the value,
checks the type, and returns an `OptionValue` with `:user` source. If not found,
returns the default value with `:default` source.

# Arguments
- `kwargs::NamedTuple`: NamedTuple containing potential option values.
- `def::OptionDefinition`: Definition defining the option to extract.

# Returns
- `(OptionValue, NamedTuple)`: Tuple containing the extracted option value and the remaining kwargs.

# Notes
- If a validator is provided in the definition, it will be called on the extracted value.
- Type mismatches generate warnings but do not prevent extraction.
- The function removes the found option from the returned kwargs.
- This function works with the unified `OptionDefinition` type that replaces both `OptionSchema` and `OptionSpecification`.

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

julia> kwargs = (n=200, tol=1e-6, max_iter=1000)
(n = 200, tol = 1.0e-6, max_iter = 1000)

julia> opt_value, remaining = extract_option(kwargs, def)
(200 (user), (tol = 1.0e-6, max_iter = 1000))

julia> opt_value.value
200

julia> opt_value.source
:user
```
```

#### extract_options (Vector version)
```julia
"""
$(TYPEDSIGNATURES)

Extract multiple options from a NamedTuple using a vector of definitions.

This function iteratively applies `extract_option` for each definition in the vector,
building a dictionary of extracted options while progressively removing processed
options from the kwargs.

# Arguments
- `kwargs::NamedTuple`: NamedTuple containing potential option values.
- `defs::Vector{OptionDefinition}`: Vector of definitions defining options to extract.

# Returns
- `(Dict{Symbol, OptionValue}, NamedTuple)`: Dictionary mapping option names to their values, and remaining kwargs.

# Notes
- The extraction order follows the order of definitions in the vector.
- Each definition's primary name is used as the dictionary key.
- Options not found in kwargs use their definition default values.
- This function works with the unified `OptionDefinition` type that replaces both `OptionSchema` and `OptionSpecification`.

# Example
```julia-repl
julia> using CTModels.Options

julia> defs = [
           OptionDefinition(name = :grid_size, type = Int, default = 100, description = "Grid size"),
           OptionDefinition(name = :tol, type = Float64, default = 1e-6, description = "Tolerance")
       ]
2-element Vector{OptionDefinition}:

julia> kwargs = (grid_size=200, max_iter=1000)
(grid_size = 200, max_iter = 1000)

julia> extracted, remaining = extract_options(kwargs, defs)
(Dict(:grid_size => 200 (user), :tol => 1.0e-6 (default)), (max_iter = 1000,))

julia> extracted[:grid_size]
200 (user)

julia> extracted[:tol]
1.0e-6 (default)
```
```

#### extract_options (NamedTuple version)
```julia
"""
$(TYPEDSIGNATURES)

Extract multiple options from a NamedTuple using a NamedTuple of definitions.

This function is similar to the Vector version but returns a NamedTuple instead
of a Dict for convenience when the definition structure is known at compile time.

# Arguments
- `kwargs::NamedTuple`: NamedTuple containing potential option values.
- `defs::NamedTuple`: NamedTuple of definitions defining options to extract.

# Returns
- `(NamedTuple, NamedTuple)`: NamedTuple of extracted options and remaining kwargs.

# Notes
- The extraction order follows the order of definitions in the NamedTuple.
- Each definition's primary name is used as the key in the returned NamedTuple.
- Options not found in kwargs use their definition default values.
- This function works with the unified `OptionDefinition` type that replaces both `OptionSchema` and `OptionSpecification`.

# Example
```julia-repl
julia> using CTModels.Options

julia> defs = (
           grid_size = OptionDefinition(name = :grid_size, type = Int, default = 100, description = "Grid size"),
           tol = OptionDefinition(name = :tol, type = Float64, default = 1e-6, description = "Tolerance")
       )

julia> kwargs = (grid_size=200, max_iter=1000)
(grid_size = 200, max_iter = 1000)

julia> extracted, remaining = extract_options(kwargs, defs)
((grid_size = 200 (user), tol = 1.0e-6 (default)), (max_iter = 1000))

julia> extracted.grid_size
200 (user)

julia> extracted.tol
1.0e-6 (default)
```
```

### Examples status
- ✅ All examples are runnable and safe (no I/O, deterministic)
- ✅ Examples use correct module prefix (CTModels.Options)
- ✅ Examples demonstrate actual usage patterns with OptionDefinition
- ✅ Examples show realistic return types (OptionValue, Dict, NamedTuple)

### Changes summary
- Add OptionDefinition context to all docstrings
- Clarify that OptionDefinition replaces OptionSchema and OptionSpecification
- Update examples to use OptionDefinition instead of OptionSchema
- Add notes about unified type system
- Maintain existing functionality documentation
