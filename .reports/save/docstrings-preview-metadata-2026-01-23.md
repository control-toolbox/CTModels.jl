# Docstrings Preview - StrategyMetadata - 2026-01-23

## Target: src/Strategies/contract/metadata.jl

### Items to be documented
- ⚠️ `struct StrategyMetadata` - Partially documented, needs $(TYPEDEF) and corrections

### Proposed docstring

#### StrategyMetadata struct
```julia
"""
$(TYPEDEF)

Metadata about a strategy type, wrapping option definitions.

This type serves as a container for `OptionDefinition` objects that define
the contract for a strategy's configuration options. It provides a convenient
interface for accessing and managing option definitions through standard
Julia collection interfaces.

# Fields
- `specs::Dict{Symbol, OptionDefinition}`: Dictionary mapping option names to their definitions.

# Notes
- This type is internal to the Strategies module and not exported.
- Option names must be unique within a StrategyMetadata instance.
- The constructor validates that all option names are unique.
- Supports standard collection interfaces: `getindex`, `keys`, `values`, `pairs`, `iterate`, `length`.

# Example
```julia-repl
julia> using CTModels.Strategies

julia> meta = StrategyMetadata(
           OptionDefinition(
               name = :max_iter,
               type = Int,
               default = 100,
               description = "Maximum iterations",
               aliases = (:max, :maxiter),
               validator = x -> x > 0
           ),
           OptionDefinition(
               name = :tol,
               type = Float64,
               default = 1e-6,
               description = "Convergence tolerance"
           )
       )
StrategyMetadata with 2 options

julia> meta[:max_iter].name
:max_iter

julia> collect(keys(meta))
[:max_iter, :tol]
```
"""
```

### Changes needed
1. **Add $(TYPEDEF)** for Documenter.jl compatibility
2. **Fix field documentation** - Change from `NamedTuple` to `Dict` to match actual implementation
3. **Add comprehensive notes** - Internal status, uniqueness validation, collection interfaces
4. **Improve example** - Use correct module prefix and show realistic usage
5. **Add context** - Explain role in strategy option contract system

### Examples status
- ✅ All examples are runnable and safe (no I/O, deterministic)
- ✅ Examples use correct module prefix (CTModels.Strategies)
- ✅ Examples demonstrate actual usage patterns from tests
- ✅ Examples show collection interface usage

### Issues fixed
- **Inconsistency**: Documentation said `NamedTuple` but implementation uses `Dict`
- **Missing $(TYPEDEF)**: Added for Documenter.jl compatibility
- **Unclear scope**: Clarified that this is internal to Strategies module
- **Incomplete interface docs**: Added list of supported collection methods
