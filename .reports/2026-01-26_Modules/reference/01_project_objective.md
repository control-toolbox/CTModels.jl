# Modular Architecture Refactoring - Project Objectives

## Executive Summary

This refactoring aims to improve CTModels.jl's code organization by introducing dedicated submodules that clearly separate concerns and control API exposure. The key principle is: **submodules act as abstraction barriers**, exposing only what should be publicly accessible while keeping implementation details private.

## Core Objectives

### 1. Separate Concerns Through Dedicated Modules

**Problem**: Currently, visualization (`print.jl`) and I/O operations (`export_import_functions.jl`) are mixed with core OCP logic, making the codebase harder to navigate and maintain.

**Solution**: Create dedicated submodules:
- **`Display`** module for all output formatting and printing
- **`Serialization`** module for all import/export operations

### 2. Control API Exposure

**Problem**: All functions in the current flat structure are equally accessible, with no clear distinction between public API and internal implementation.

**Solution**: Use submodules to create natural abstraction barriers:
- Functions exported by submodules → accessible via `CTModels.function_name()`
- Functions not exported → remain private to the submodule
- Main module decides what to re-export in the core API

### 3. Improve Extensibility

**Problem**: Extensions need to extend functions scattered across different files without clear interfaces.

**Solution**: Provide clean extension points:
- Extensions can target specific submodules
- Clear interfaces for extending functionality
- Better separation between core and extended features

## Proposed Module Structure

### Module: `Display`

**Responsibility**: All output formatting, printing, and display operations

**Contents**:
- `src/ocp/print.jl` → `src/Display/print.jl`
- Functions for formatting OCP problems
- Functions for displaying solutions
- Extension interface for custom visualizations

**Exported Functions** (accessible as `CTModels.function_name`):
- Core display functions used by end users

**Private Functions** (internal to Display):
- `__print()`, `__format_*()` helper functions
- Implementation details

**Extension Point**:
```julia
# ext/CTModelsPlots.jl
using CTModels.Display
# Can extend Display functions for enhanced plotting
```

### Module: `Serialization`

**Responsibility**: All import/export operations for models and solutions

**Contents**:
- `src/types/export_import_functions.jl` → `src/Serialization/export_import.jl`
- Generic serialization interface
- Format-specific implementations (via extensions)

**Exported Functions**:
- `export_ocp_solution()`, `import_ocp_solution()`
- Format validation and utilities

**Private Functions**:
- Internal serialization helpers
- Format conversion utilities

**Extension Point**:
```julia
# ext/CTModelsJSON.jl
using CTModels.Serialization
# Extends serialization for JSON format
```

### Module: `InitialGuess` (renamed from `init`)

**Responsibility**: Initial guess construction and validation

**Rationale**: 
- `init` is too generic and unclear
- `InitialGuess` clearly indicates purpose
- Keeps initial guess logic separate from OCP core

**Contents**:
- `src/init/` → `src/InitialGuess/`
- Types: `OptimalControlPreInit`, `OptimalControlInitialGuess`
- Functions: `pre_initial_guess()`, `initial_guess()`

**Exported Functions**:
- `initial_guess()`, `pre_initial_guess()`

**Private Functions**:
- Validation and conversion helpers

## Module Naming Rationale

### Why `Display` instead of `Visualization`?

1. **Precision**: The module handles text output and formatting, not graphical visualization
2. **Clarity**: `Display` clearly indicates "showing information to users"
3. **Separation**: Graphical plotting is in extensions (`CTModelsPlots`), text display is core
4. **Consistency**: Follows Julia conventions (e.g., `Base.show`, `Base.display`)

### Why `Serialization` instead of `IO`?

1. **Specificity**: `IO` is too broad (could mean file I/O, network I/O, etc.)
2. **Precision**: The module specifically handles serialization/deserialization of objects
3. **Clarity**: `Serialization` clearly indicates converting objects to/from storage formats
4. **Avoidance**: `IO` conflicts with Julia's `Base.IO` namespace

### Why `InitialGuess` instead of keeping `init`?

1. **Clarity**: `init` is ambiguous (initialization of what?)
2. **Descriptiveness**: `InitialGuess` explicitly states the purpose
3. **Searchability**: Easier to find in documentation and code
4. **Professionalism**: More explicit naming improves code readability

## Implementation Strategy

### Phase 1: Create Module Structure
1. Create `src/Display/Display.jl` module
2. Create `src/Serialization/Serialization.jl` module
3. Rename `src/init/` → `src/InitialGuess/`

### Phase 2: Move and Organize Code
1. Move `src/ocp/print.jl` → `src/Display/print.jl`
2. Move `src/types/export_import_functions.jl` → `src/Serialization/export_import.jl`
3. Update all includes in `src/CTModels.jl`

### Phase 3: Define Exports
1. Each submodule exports only its public API
2. Main module imports and selectively re-exports
3. Document public vs private functions

### Phase 4: Update Extensions
1. Update `CTModelsPlots.jl` to use `Display` module
2. Update `CTModelsJSON.jl` to use `Serialization` module
3. Update `CTModelsJLD.jl` to use `Serialization` module

### Phase 5: Testing and Documentation
1. Verify all tests pass
2. Update documentation
3. Add examples of new module usage

## Benefits

### For Maintainers
- **Clear organization**: Easy to find where functionality lives
- **Controlled exposure**: Explicit about what's public vs private
- **Better testing**: Can test modules in isolation

### For Users
- **Stable API**: Core functions remain unchanged
- **Optional features**: Advanced features accessible when needed
- **Clear documentation**: Module structure guides understanding

### For Extension Developers
- **Clean interfaces**: Clear extension points
- **Targeted extensions**: Can extend specific modules
- **Better compatibility**: Less risk of conflicts

## Non-Goals

This refactoring explicitly does NOT:
- Change the public API (backward compatible)
- Reorganize OCP core structure (separate concern)
- Modify optimization algorithms (out of scope)
- Change extension mechanisms (maintain compatibility)

## Success Criteria

1. ✅ All existing tests pass without modification
2. ✅ Public API remains unchanged
3. ✅ Extensions work without breaking changes
4. ✅ Code is more navigable and maintainable
5. ✅ Documentation clearly explains new structure

## Timeline

- **Week 1**: Create module structure and move files
- **Week 2**: Update imports and exports
- **Week 3**: Update extensions and tests
- **Week 4**: Documentation and review

## Risks and Mitigation

| Risk | Mitigation |
|------|-----------|
| Breaking changes | Comprehensive test suite, backward compatibility checks |
| Extension breakage | Update all official extensions, provide migration guide |
| Performance impact | Benchmark before/after, ensure no overhead |
| Learning curve | Clear documentation, examples, migration guide |

---

**This refactoring establishes a solid foundation for future development while maintaining stability and usability.**