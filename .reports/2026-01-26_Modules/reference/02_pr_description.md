# PR Description: Modular Architecture Refactoring

## Overview

This PR introduces a modular architecture for CTModels.jl by creating dedicated submodules that separate concerns and control API exposure. The refactoring improves code organization, maintainability, and extensibility while maintaining full backward compatibility.

## Motivation

**Current Issues:**
- Display logic (`print.jl`) is mixed with OCP core implementation
- Serialization functions (`export_import_functions.jl`) lack clear organization
- No distinction between public API and internal implementation details
- Extensions lack clear interfaces for extending functionality

**Solution:**
Create dedicated submodules that act as abstraction barriers, exposing only what should be publicly accessible while keeping implementation details private.

## Changes

### New Modules

#### 1. `Display` Module (`src/Display/`)

**Purpose:** All output formatting, printing, and display operations

**Migration:**
- `src/ocp/print.jl` → `src/Display/print.jl`

**Public API:**
```julia
# Accessible as CTModels.function_name()
Base.show(io::IO, ::MIME"text/plain", ocp::Model)
Base.show(io::IO, ::MIME"text/plain", sol::Solution)
```

**Private Implementation:**
```julia
# Internal to Display module
__print(e::Expr, io::IO, l::Int)
__print_abstract_definition(io::IO, ocp)
__print_mathematical_definition(io::IO, ...)
```

**Extension Interface:**
```julia
# Extensions can use Display module
using CTModels.Display
# Extend display functions for custom visualizations
```

#### 2. `Serialization` Module (`src/Serialization/`)

**Purpose:** All import/export operations for models and solutions

**Migration:**
- `src/types/export_import_functions.jl` → `src/Serialization/export_import.jl`

**Public API:**
```julia
# Accessible as CTModels.function_name()
export_ocp_solution(sol; format=:JLD, filename="solution")
import_ocp_solution(ocp; format=:JLD, filename="solution")
```

**Private Implementation:**
```julia
# Internal to Serialization module
__format()
__filename_export_import()
```

**Extension Interface:**
```julia
# Extensions implement format-specific serialization
using CTModels.Serialization
function Serialization.export_ocp_solution(::JSON3Tag, sol; filename)
    # JSON-specific implementation
end
```

#### 3. `InitialGuess` Module (renamed from `init`)

**Purpose:** Initial guess construction and validation

**Migration:**
- `src/init/` → `src/InitialGuess/`

**Rationale:** 
- `init` is too generic and ambiguous
- `InitialGuess` clearly indicates purpose
- Improves code searchability and documentation

**Public API:**
```julia
initial_guess(ocp; state=nothing, control=nothing, variable=nothing)
pre_initial_guess(; state=nothing, control=nothing, variable=nothing)
```

### Module Structure

```julia
module CTModels
    # Existing modules (unchanged)
    include("Options/Options.jl")
    include("Strategies/Strategies.jl")
    include("Orchestration/Orchestration.jl")
    include("Optimization/Optimization.jl")
    include("Modelers/Modelers.jl")
    include("DOCP/DOCP.jl")
    
    # New modules
    include("Display/Display.jl")
    include("Serialization/Serialization.jl")
    include("InitialGuess/InitialGuess.jl")
    
    # Import functions into CTModels namespace
    using .Display
    using .Serialization
    using .InitialGuess
    
    # Core API remains unchanged
    export Model, Solution, AbstractModel, AbstractSolution
    export initial_guess, pre_initial_guess
    export export_ocp_solution, import_ocp_solution
end
```

### Extension Updates

#### `CTModelsPlots.jl`
```julia
module CTModelsPlots
    using CTModels
    using CTModels.Display  # Use Display module for integration
    using Plots
    
    # Implement RecipesBase.plot for Solution
    function RecipesBase.plot(sol::CTModels.AbstractSolution, args...; kwargs...)
        # Implementation
    end
end
```

#### `CTModelsJSON.jl`
```julia
module CTModelsJSON
    using CTModels
    using CTModels.Serialization  # Use Serialization module
    using JSON3
    
    # Implement JSON-specific serialization
    function CTModels.Serialization.export_ocp_solution(
        ::CTModels.JSON3Tag, sol; filename
    )
        # JSON export implementation
    end
end
```

#### `CTModelsJLD.jl`
```julia
module CTModelsJLD
    using CTModels
    using CTModels.Serialization  # Use Serialization module
    using JLD2
    
    # Implement JLD2-specific serialization
    function CTModels.Serialization.export_ocp_solution(
        ::CTModels.JLD2Tag, sol; filename
    )
        # JLD2 export implementation
    end
end
```

## Benefits

### For Maintainers
- **Clear Organization:** Easy to locate functionality by module
- **Controlled Exposure:** Explicit distinction between public API and internal implementation
- **Isolated Testing:** Can test modules independently
- **Better Documentation:** Module structure guides understanding

### For Users
- **Stable API:** No breaking changes to existing code
- **Backward Compatible:** All existing code continues to work
- **Optional Features:** Advanced features accessible when needed via qualified access
- **Clear Documentation:** Module structure clarifies functionality

### For Extension Developers
- **Clean Interfaces:** Clear extension points via submodules
- **Targeted Extensions:** Can extend specific modules without affecting others
- **Better Compatibility:** Reduced risk of naming conflicts
- **Improved Maintainability:** Easier to understand extension points

## Backward Compatibility

✅ **Fully Backward Compatible**

All existing code continues to work without modification:

```julia
# Existing code (still works)
using CTModels
ocp = Model(...)
sol = Solution(...)
export_ocp_solution(sol)
```

New qualified access is optional:

```julia
# New optional access patterns
CTModels.Display.show(io, ocp)
CTModels.Serialization.export_ocp_solution(sol)
```

## Testing Strategy

1. **Unit Tests:** All existing tests pass without modification
2. **Integration Tests:** Extensions work correctly with new structure
3. **API Tests:** Public API remains stable
4. **Performance Tests:** No performance regression

## Implementation Phases

### Phase 1: Module Structure ✅
- [x] Create `src/Display/Display.jl`
- [x] Create `src/Serialization/Serialization.jl`
- [x] Rename `src/init/` → `src/InitialGuess/`

### Phase 2: Code Migration
- [ ] Move `src/ocp/print.jl` → `src/Display/print.jl`
- [ ] Move `src/types/export_import_functions.jl` → `src/Serialization/export_import.jl`
- [ ] Update includes in `src/CTModels.jl`

### Phase 3: Export Configuration
- [ ] Define exports in each submodule
- [ ] Configure imports in main module
- [ ] Document public vs private functions

### Phase 4: Extension Updates
- [ ] Update `ext/CTModelsPlots.jl`
- [ ] Update `ext/CTModelsJSON.jl`
- [ ] Update `ext/CTModelsJLD.jl`

### Phase 5: Testing & Documentation
- [ ] Verify all tests pass
- [ ] Update API documentation
- [ ] Add module usage examples
- [ ] Create migration guide

## Documentation

See [`reports/2026-01-26_Modules/reference/01_project_objective.md`](../reference/01_project_objective.md) for detailed project objectives and rationale.

## Module Naming Rationale

### `Display` (not `Visualization`)
- **Precision:** Handles text output and formatting, not graphical visualization
- **Clarity:** Clearly indicates "showing information to users"
- **Separation:** Graphical plotting remains in extensions (`CTModelsPlots`)
- **Consistency:** Follows Julia conventions (`Base.show`, `Base.display`)

### `Serialization` (not `IO`)
- **Specificity:** Handles object serialization/deserialization, not general I/O
- **Precision:** Clearly indicates converting objects to/from storage formats
- **Avoidance:** Prevents conflicts with `Base.IO` namespace
- **Clarity:** Unambiguous purpose

### `InitialGuess` (not `init`)
- **Clarity:** Explicitly states purpose (initial guess for OCP)
- **Searchability:** Easier to find in documentation and code
- **Professionalism:** More descriptive naming improves readability
- **Consistency:** Matches domain terminology

## Review Checklist

- [ ] All existing tests pass
- [ ] No breaking changes to public API
- [ ] Extensions work correctly
- [ ] Documentation updated
- [ ] Code follows project style guidelines
- [ ] Performance benchmarks show no regression

## Related Issues

This PR addresses code organization and maintainability concerns raised in discussions about improving CTModels.jl's architecture.

---

**This refactoring establishes a solid foundation for future development while maintaining stability and usability of the existing API.**
