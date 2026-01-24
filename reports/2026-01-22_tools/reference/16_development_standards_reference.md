# Development Standards & Best Practices Reference

**Version**: 1.0  
**Date**: 2026-01-24  
**Status**: 📘 Reference Documentation  
**Author**: CTModels Development Team

---

## Table of Contents

1. [Introduction](#introduction)
2. [Exception Handling](#exception-handling)
3. [Documentation Standards](#documentation-standards)
4. [Type Stability](#type-stability)
5. [Architecture & Design](#architecture--design)
6. [Testing Standards](#testing-standards)
7. [Code Conventions](#code-conventions)
8. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
9. [Development Workflow](#development-workflow)
10. [Quality Checklist](#quality-checklist)
11. [Related Resources](#related-resources)

---

## Introduction

This document defines the development standards and best practices for CTModels.jl, with a focus on the **Options** and **Strategies** modules. These standards ensure code quality, maintainability, and consistency across the control-toolbox ecosystem.

### Purpose

- Provide clear guidelines for contributors
- Ensure consistency with CTBase and control-toolbox standards
- Maintain high code quality and performance
- Facilitate code review and maintenance

### Scope

This document covers:
- Exception handling with CTBase exceptions
- Documentation with DocStringExtensions
- Type stability and performance
- Testing with `@inferred` and Test.jl
- Architecture patterns and design principles

---

## Exception Handling

### CTBase Exception Hierarchy

All custom exceptions in CTModels must use **CTBase exceptions** to maintain consistency across the control-toolbox ecosystem.

#### Available Exceptions

**1. `CTBase.IncorrectArgument`**

Use when an individual argument is invalid or violates a precondition.

```julia
# ✅ CORRECT
function create_registry(pairs::Pair...)
    for pair in pairs
        family, strategies = pair
        if !(family isa DataType && family <: AbstractStrategy)
            throw(CTBase.IncorrectArgument(
                "Family must be a subtype of AbstractStrategy, got: $family"
            ))
        end
    end
end
```

**2. `CTBase.AmbiguousDescription`**

Use when a description (tuple of Symbols) cannot be matched or is ambiguous.

⚠️ **Important**: This exception expects a `Tuple{Vararg{Symbol}}`, not a `String`.

```julia
# ✅ CORRECT - Use IncorrectArgument for string messages
throw(CTBase.IncorrectArgument(
    "Multiple IDs $hits for family $family found in method $method"
))

# ❌ INCORRECT - AmbiguousDescription expects Tuple{Symbol}
throw(CTBase.AmbiguousDescription(
    "Multiple IDs found"  # String not accepted!
))
```

**3. `CTBase.NotImplemented`**

Use to mark interface points that must be implemented by concrete subtypes.

```julia
# ✅ CORRECT
abstract type AbstractStrategy end

function id(::Type{<:AbstractStrategy})
    throw(CTBase.NotImplemented("id() must be implemented for each strategy type"))
end
```

#### Rules

✅ **DO:**
- Use `CTBase.IncorrectArgument` for invalid arguments
- Provide clear, informative error messages
- Include context (what was expected, what was received)
- Suggest available alternatives when applicable

❌ **DON'T:**
- Use generic `error()` calls
- Use `ErrorException` without context
- Throw exceptions with unclear messages
- Use `AmbiguousDescription` with String messages

#### Examples

```julia
# ✅ GOOD - Clear, informative error
if !haskey(registry.families, family)
    available_families = collect(keys(registry.families))
    throw(CTBase.IncorrectArgument(
        "Family $family not found in registry. Available families: $available_families"
    ))
end

# ❌ BAD - Generic error
if !haskey(registry.families, family)
    error("Family not found")
end
```

---

## Documentation Standards

### DocStringExtensions Macros

All public functions and types must use **DocStringExtensions** for consistent documentation.

#### For Functions

```julia
"""
$(TYPEDSIGNATURES)

Brief one-line description of what the function does.

Longer description with more details about the function's purpose,
behavior, and any important notes.

# Arguments
- `param1::Type`: Description of the first parameter
- `param2::Type`: Description of the second parameter
- `kwargs...`: Optional keyword arguments

# Returns
- `ReturnType`: Description of what is returned

# Throws
- `CTBase.IncorrectArgument`: When the argument is invalid
- `CTBase.NotImplemented`: When the method is not implemented

# Example
\`\`\`julia-repl
julia> result = my_function(arg1, arg2)
expected_output

julia> my_function(invalid_arg)
ERROR: CTBase.IncorrectArgument: ...
\`\`\`

See also: [`related_function`](@ref), [`RelatedType`](@ref)
"""
function my_function(param1::Type1, param2::Type2; kwargs...)
    # Implementation
end
```

#### For Types (Structs)

```julia
"""
$(TYPEDEF)

Brief description of the type's purpose.

Detailed explanation of what this type represents, when to use it,
and any important invariants or constraints.

# Fields
- `field1::Type`: Description of the first field
- `field2::Type`: Description of the second field

# Example
\`\`\`julia-repl
julia> obj = MyType(value1, value2)
MyType(...)

julia> obj.field1
value1
\`\`\`

See also: [`related_type`](@ref), [`constructor_function`](@ref)
"""
struct MyType{T}
    field1::T
    field2::String
end
```

#### Rules

✅ **DO:**
- Use `$(TYPEDSIGNATURES)` for functions
- Use `$(TYPEDEF)` for types
- Provide clear, concise descriptions
- Include examples with `julia-repl` code blocks
- Document all parameters, returns, and exceptions
- Link to related functions/types with `[`name`](@ref)`

❌ **DON'T:**
- Omit docstrings for public API
- Use vague descriptions like "does something"
- Forget to document exceptions
- Skip examples for complex functions

---

## Type Stability

### Importance

Type stability is crucial for Julia performance. The compiler can generate optimized code only when it can infer types at compile time.

### Testing with `@inferred`

The `@inferred` macro from Test.jl verifies that a function call is type-stable.

#### Correct Usage

```julia
# ✅ CORRECT - @inferred on a function call
function get_max_iter(meta::StrategyMetadata)
    return meta.specs.max_iter
end

@testset "Type stability" begin
    meta = StrategyMetadata(...)
    @inferred get_max_iter(meta)  # ✅ Function call
end
```

#### Common Mistakes

```julia
# ❌ INCORRECT - @inferred on direct field access
@testset "Type stability" begin
    meta = StrategyMetadata(...)
    @inferred meta.specs.max_iter  # ❌ Not a function call!
end
```

**Solution**: Wrap field accesses in helper functions for testing.

### Type-Stable Structures

#### Use NamedTuple Instead of Dict

```julia
# ✅ GOOD - Type-stable with NamedTuple
struct StrategyMetadata{NT <: NamedTuple}
    specs::NT
end

# ❌ BAD - Type-unstable with Dict
struct StrategyMetadata
    specs::Dict{Symbol, OptionDefinition}  # Type of values unknown!
end
```

#### Parametric Types

```julia
# ✅ GOOD - Parametric type
struct OptionDefinition{T}
    name::Symbol
    type::Type{T}
    default::T  # Type-stable!
end

# ❌ BAD - Non-parametric with Any
struct OptionDefinition
    name::Symbol
    type::Type
    default::Any  # Type-unstable!
end
```

#### Rules

✅ **DO:**
- Use parametric types when fields have varying types
- Prefer `NamedTuple` over `Dict` for known keys
- Test type stability with `@inferred`
- Use `@code_warntype` to detect instabilities

❌ **DON'T:**
- Use `Any` unless absolutely necessary
- Use `Dict` when keys are known at compile time
- Ignore type instability warnings

---

## Architecture & Design

### Module Organization

CTModels follows a layered architecture:

```
Options (Low-level)
  ↓
Strategies (Middle-layer)
  ↓
Orchestration (Top-level)
```

#### Responsibilities

**Options Module:**
- Low-level option handling
- Extraction with alias resolution
- Validation
- Provenance tracking (`:user`, `:default`, `:computed`)

**Strategies Module:**
- Strategy contract (`AbstractStrategy`)
- Registry management
- Metadata and options for strategies
- Builder functions
- Introspection API

**Orchestration Module:**
- High-level routing
- Multi-strategy coordination
- `solve` API integration

### Adaptation Pattern

When implementing from reference code:

1. **Read** the reference implementation
2. **Identify** dependencies on existing structures
3. **Adapt** to use existing APIs (`extract_options`, `StrategyOptions`, etc.)
4. **Maintain** consistency with architecture
5. **Test** integration with existing code

#### Example

```julia
# Reference code (hypothetical)
function build_strategy(id, family; kwargs...)
    T = lookup_type(id, family)
    return T(; kwargs...)
end

# Adapted code (actual)
function build_strategy(id, family, registry; kwargs...)
    T = type_from_id(id, family, registry)  # Use existing function
    return T(; kwargs...)  # Delegates to strategy constructor
end

# Strategy constructor adapts to Options API
function MyStrategy(; kwargs...)
    meta = metadata(MyStrategy)
    defs = collect(values(meta.specs))
    extracted, _ = extract_options((; kwargs...), defs)  # Use Options API
    opts = StrategyOptions(dict_to_namedtuple(extracted))
    return MyStrategy(opts)
end
```

### Design Principles

See [Design Principles Reference](./design-principles-reference.md) for detailed SOLID principles and quality objectives.

Key principles:
- **Single Responsibility**: Each function/type has one clear purpose
- **Open/Closed**: Extensible via abstract types and multiple dispatch
- **Liskov Substitution**: Subtypes honor parent contracts
- **Interface Segregation**: Small, focused interfaces
- **Dependency Inversion**: Depend on abstractions, not concretions

---

## Testing Standards

### Test Organization

```julia
function test_my_feature()
    Test.@testset "My Feature" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # Unit tests
        Test.@testset "Unit Tests" begin
            Test.@testset "Basic functionality" begin
                result = my_function(input)
                Test.@test result == expected
            end
            
            Test.@testset "Error handling" begin
                Test.@test_throws CTBase.IncorrectArgument my_function(invalid_input)
            end
        end
        
        # Integration tests
        Test.@testset "Integration Tests" begin
            # Test full pipeline
        end
        
        # Type stability tests
        Test.@testset "Type Stability" begin
            @inferred my_function(input)
        end
    end
end
```

### Test Coverage

Each feature should have:

1. **Unit tests** - Test individual functions in isolation
2. **Integration tests** - Test interactions between components
3. **Error tests** - Test exception handling with `@test_throws`
4. **Type stability tests** - Test with `@inferred` for critical paths
5. **Edge cases** - Test boundary conditions

### Rules

✅ **DO:**
- Test both success and failure cases
- Use descriptive test set names
- Test with `@inferred` for performance-critical code
- Use typed exceptions in `@test_throws`
- Group related tests in nested `@testset`

❌ **DON'T:**
- Use generic `ErrorException` in `@test_throws`
- Skip error case testing
- Ignore type stability for hot paths
- Write tests without clear descriptions

See [Julia Testing Workflow](./test-julia.md) for detailed testing guidelines.

---

## Code Conventions

### Naming

- **Functions**: `snake_case`
  ```julia
  function build_strategy(...)
  function extract_id_from_method(...)
  ```

- **Types**: `PascalCase`
  ```julia
  struct StrategyMetadata{NT}
  abstract type AbstractStrategy
  ```

- **Constants**: `UPPER_CASE`
  ```julia
  const MAX_ITERATIONS = 1000
  ```

- **Private/Internal**: Prefix with `_`
  ```julia
  function _internal_helper(...)
  ```

### Comments

❌ **DON'T** add/remove comments unless explicitly requested:
- Preserve existing comments
- Use docstrings for public documentation
- Only add comments for complex algorithms when necessary

### Code Style

- **Line length**: Prefer < 92 characters
- **Indentation**: 4 spaces (no tabs)
- **Whitespace**: Follow Julia style guide
- **Imports**: Group by package, alphabetically

---

## Common Pitfalls & Solutions

### 1. `extract_options` Returns a Tuple

**Problem**: Forgetting that `extract_options` returns `(extracted, remaining)`.

```julia
# ❌ WRONG
extracted = extract_options(kwargs, defs)
# extracted is a Tuple, not a Dict!

# ✅ CORRECT
extracted, remaining = extract_options(kwargs, defs)
# or
extracted, _ = extract_options(kwargs, defs)
```

### 2. Dict to NamedTuple Conversion

**Problem**: `NamedTuple(dict)` doesn't work directly.

```julia
# ❌ WRONG
nt = NamedTuple(dict)  # Error!

# ✅ CORRECT
function dict_to_namedtuple(d::Dict{Symbol, <:Any})
    return (; (k => v for (k, v) in d)...)
end
nt = dict_to_namedtuple(dict)
```

### 3. `@inferred` Requires Function Call

**Problem**: Using `@inferred` on expressions instead of function calls.

```julia
# ❌ WRONG
@inferred obj.field.subfield

# ✅ CORRECT
function get_subfield(obj)
    return obj.field.subfield
end
@inferred get_subfield(obj)
```

### 4. Exception Type Mismatch

**Problem**: Using wrong exception type in tests after refactoring.

```julia
# ❌ WRONG - After changing to CTBase exceptions
@test_throws ErrorException my_function(invalid)

# ✅ CORRECT
@test_throws CTBase.IncorrectArgument my_function(invalid)
```

### 5. AmbiguousDescription with String

**Problem**: `AmbiguousDescription` expects `Tuple{Vararg{Symbol}}`, not `String`.

```julia
# ❌ WRONG
throw(CTBase.AmbiguousDescription("Error message"))

# ✅ CORRECT - Use IncorrectArgument for string messages
throw(CTBase.IncorrectArgument("Error message"))
```

---

## Development Workflow

### Standard Workflow

1. **Plan**
   - Read reference code/specifications
   - Identify dependencies and integration points
   - Create implementation plan

2. **Implement**
   - Follow architecture patterns
   - Use existing APIs where possible
   - Apply type stability best practices
   - Write comprehensive docstrings

3. **Test**
   - Write unit tests
   - Write integration tests
   - Add type stability tests
   - Test error cases

4. **Verify**
   - Run all tests
   - Check type stability with `@code_warntype`
   - Verify exception types
   - Review documentation

5. **Refine**
   - Address test failures
   - Fix type instabilities
   - Update exception handling
   - Improve documentation

6. **Commit**
   - Write clear commit message
   - Reference related issues/PRs
   - Push to feature branch

### Iterative Refinement

It's normal to iterate on:
- Exception types (generic → CTBase)
- Type stability (Any → parametric types)
- Test assertions (ErrorException → CTBase exceptions)
- Documentation (incomplete → comprehensive)

**Don't be discouraged by initial failures** - refining code is part of the process!

---

## Quality Checklist

Use this checklist before committing code:

### Code Quality

- [ ] All functions have docstrings with `$(TYPEDSIGNATURES)` or `$(TYPEDEF)`
- [ ] All types have docstrings with field descriptions
- [ ] Exceptions use CTBase types (`IncorrectArgument`, etc.)
- [ ] Error messages are clear and informative
- [ ] Code follows naming conventions

### Type Stability

- [ ] Parametric types used where appropriate
- [ ] `NamedTuple` used instead of `Dict` for known keys
- [ ] `Any` avoided unless necessary
- [ ] Critical paths tested with `@inferred`
- [ ] No type instability warnings from `@code_warntype`

### Testing

- [ ] Unit tests for all functions
- [ ] Integration tests for pipelines
- [ ] Error cases tested with `@test_throws`
- [ ] Exception types are specific (not `ErrorException`)
- [ ] Type stability tests for performance-critical code
- [ ] All tests pass

### Architecture

- [ ] Code adapted to existing structures
- [ ] Existing APIs used where available
- [ ] Responsibilities clearly separated
- [ ] Design principles followed (SOLID)

### Documentation

- [ ] Examples in docstrings work
- [ ] Cross-references use `[@ref]` syntax
- [ ] All parameters documented
- [ ] All exceptions documented
- [ ] Return values documented

---

## Related Resources

### Internal Documentation

- [Design Principles Reference](./design-principles-reference.md) - SOLID principles and quality objectives
- [Julia Docstrings Workflow](./doc-julia.md) - Detailed docstring guidelines
- [Julia Testing Workflow](./test-julia.md) - Comprehensive testing guide
- [Complete Contract Specification](./08_complete_contract_specification.md) - Strategy contract details
- [Option Definition Unification](./15_option_definition_unification.md) - Options architecture

### External Resources

- [CTBase.jl Documentation](https://control-toolbox.org/CTBase.jl/stable/) - Exception handling
- [DocStringExtensions.jl](https://github.com/JuliaDocs/DocStringExtensions.jl) - Documentation macros
- [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/) - Official style guide
- [Julia Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/) - Type stability

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-24 | Initial version documenting standards for Options and Strategies modules |

---

**Maintainers**: CTModels Development Team  
**Last Review**: 2026-01-24  
**Next Review**: As needed when standards evolve
