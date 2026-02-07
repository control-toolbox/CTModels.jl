# Extended Modular Architecture - Utils and OCP

This document extends the modular architecture proposal to cover the `utils` and `ocp` directories.

## Module: `Utils`

### Current Structure

```
src/utils/
├── utils.jl              # Include file
├── interpolation.jl      # ctinterpolate function
├── matrix_utils.jl       # matrix2vec function
├── function_utils.jl     # to_out_of_place function
└── macros.jl            # @ensure macro
```

### Analysis

**Public Functions** (useful outside, should be exported):
- `ctinterpolate(x, f)` - Used for initial guess interpolation, useful for users
- `matrix2vec(A, dim)` - Converts matrices to vectors, useful for data manipulation

**Private Functions** (internal implementation):
- `to_out_of_place(f!, n; T)` - Internal conversion utility
- `@ensure(cond, exc)` - Internal validation macro

### Proposed Module Structure

```julia
module Utils
    using Interpolations
    using ..Types  # For ctNumber type
    
    # Public utilities (exported)
    include("interpolation.jl")
    include("matrix_utils.jl")
    export ctinterpolate, matrix2vec
    
    # Private utilities (not exported)
    include("function_utils.jl")  # to_out_of_place
    include("macros.jl")           # @ensure
end
```

### Usage Patterns

**From CTModels:**
```julia
module CTModels
    include("Utils/Utils.jl")
    using .Utils
    
    # Public functions accessible as:
    # CTModels.ctinterpolate()
    # CTModels.matrix2vec()
    
    # Private functions accessible internally:
    # Utils.to_out_of_place()
    # Utils.@ensure()
end
```

**For Users:**
```julia
using CTModels

# Public API
interp = CTModels.ctinterpolate(x, f)
vecs = CTModels.matrix2vec(A, 1)

# Private functions not accessible
# CTModels.to_out_of_place()  # ✗ Not exported
```

### Rationale for Module Name

**`Utils` (recommended)**
- **Standard**: Common name in Julia ecosystem
- **Clear**: Indicates utility functions
- **Concise**: Short and memorable

**Alternative: `Utilities`**
- More formal but longer
- Less common in Julia packages

**Decision: Use `Utils`** - follows Julia conventions and is widely recognized.

---

## Module: `OCP` (Optimal Control Problem)

### Current Structure

```
src/ocp/
├── ocp.jl                    # Include file
├── types/
│   ├── components.jl         # Component types
│   ├── model.jl             # Model type
│   └── solution.jl          # Solution type
├── model.jl                  # Model construction (60 functions)
├── solution.jl               # Solution construction (36 functions)
├── print.jl                  # Display functions → Move to Display module
├── state.jl                  # State functions (8 functions)
├── control.jl                # Control functions (8 functions)
├── variable.jl               # Variable functions (11 functions)
├── times.jl                  # Time functions (21 functions)
├── dynamics.jl               # Dynamics functions (4 functions)
├── objective.jl              # Objective functions (14 functions)
├── constraints.jl            # Constraint functions (14 functions)
├── dual_model.jl             # Dual model (9 functions)
├── time_dependence.jl        # Time dependence (1 function)
├── definition.jl             # Definition (3 functions)
└── defaults.jl               # Default values (2 functions)
```

### Problem Analysis

**Issues with Current Structure:**
1. **Flat organization**: 15+ files at the same level
2. **Mixed concerns**: Types, builders, components all together
3. **No clear hierarchy**: Hard to understand relationships
4. **Large files**: `model.jl` (60 functions), `solution.jl` (36 functions)

### Proposed Module Structure

#### Option A: Single `OCP` Module with Organized Subdirectories

```
src/OCP/
├── OCP.jl                    # Main module file
├── Types/
│   ├── components.jl         # Component types (PreModel, etc.)
│   ├── model.jl             # Model type definition
│   └── solution.jl          # Solution type definition
├── Components/
│   ├── state.jl             # State functions
│   ├── control.jl           # Control functions
│   ├── variable.jl          # Variable functions
│   ├── times.jl             # Time functions
│   ├── dynamics.jl          # Dynamics functions
│   ├── objective.jl         # Objective functions
│   └── constraints.jl       # Constraint functions
├── Building/
│   ├── model.jl             # Model construction
│   ├── solution.jl          # Solution construction
│   ├── dual_model.jl        # Dual model construction
│   └── definition.jl        # Definition handling
└── Core/
    ├── defaults.jl          # Default values
    └── time_dependence.jl   # Time dependence utilities
```

#### Option B: Multiple Submodules (More Complex)

```
src/OCP/
├── OCP.jl                    # Main module
├── Types/
│   └── Types.jl             # Submodule for types
├── Components/
│   └── Components.jl        # Submodule for components
└── Building/
    └── Building.jl          # Submodule for builders
```

### Recommendation: Option A (Single Module with Subdirectories)

**Rationale:**
1. **Simpler**: One module, organized directories
2. **Clearer**: Directory structure shows organization
3. **Maintainable**: Easier to navigate and modify
4. **Sufficient**: Subdirectories provide enough organization
5. **No over-engineering**: Multiple submodules add complexity without clear benefit

### Module Structure

```julia
module OCP
    using ..Types      # For type aliases
    using ..Utils      # For utilities
    using CTBase
    using DocStringExtensions
    
    # Load types first
    include("Types/components.jl")
    include("Types/model.jl")
    include("Types/solution.jl")
    
    # Load core utilities
    include("Core/defaults.jl")
    include("Core/time_dependence.jl")
    
    # Load component functions
    include("Components/state.jl")
    include("Components/control.jl")
    include("Components/variable.jl")
    include("Components/times.jl")
    include("Components/dynamics.jl")
    include("Components/objective.jl")
    include("Components/constraints.jl")
    
    # Load builders
    include("Building/definition.jl")
    include("Building/dual_model.jl")
    include("Building/model.jl")
    include("Building/solution.jl")
    
    # Export public API
    export Model, Solution, PreModel
    export state!, control!, variable!
    export time!, dynamics!, objective!, constraint!
    # ... other public functions
end
```

### Public vs Private Functions

**Public Functions** (exported by OCP module):
- Type constructors: `Model()`, `Solution()`, `PreModel()`
- Builder functions: `state!()`, `control!()`, `variable!()`
- Component functions: `time!()`, `dynamics!()`, `objective!()`, `constraint!()`
- Accessor functions: `state(ocp)`, `control(ocp)`, etc.

**Private Functions** (not exported):
- Internal helpers: `__validate_*()`, `__process_*()`, `__check_*()`
- Default value functions: `__default_*()`
- Internal constructors

### Usage from CTModels

```julia
module CTModels
    # ... other modules ...
    
    include("OCP/OCP.jl")
    using .OCP
    
    # Re-export main API
    export Model, Solution, PreModel
    export state!, control!, variable!
    export time!, dynamics!, objective!, constraint!
end
```

### Benefits of This Organization

1. **Clear Hierarchy**:
   - `Types/` - Type definitions
   - `Components/` - Component manipulation
   - `Building/` - Model/solution construction
   - `Core/` - Utilities and defaults

2. **Better Navigation**:
   - Easy to find where functionality lives
   - Related code grouped together
   - Clear separation of concerns

3. **Maintainability**:
   - Smaller, focused files
   - Clear dependencies
   - Easier to test

4. **Extensibility**:
   - Clear where to add new features
   - Organized extension points
   - Better documentation structure

---

## Complete Module Architecture

### Final Structure

```
src/
├── CTModels.jl               # Main module
├── Types/
│   └── types.jl             # Type aliases (no module)
├── Utils/
│   ├── Utils.jl             # Utils module
│   ├── interpolation.jl
│   ├── matrix_utils.jl
│   ├── function_utils.jl
│   └── macros.jl
├── OCP/
│   ├── OCP.jl               # OCP module
│   ├── Types/
│   │   ├── components.jl
│   │   ├── model.jl
│   │   └── solution.jl
│   ├── Components/
│   │   ├── state.jl
│   │   ├── control.jl
│   │   ├── variable.jl
│   │   ├── times.jl
│   │   ├── dynamics.jl
│   │   ├── objective.jl
│   │   └── constraints.jl
│   ├── Building/
│   │   ├── model.jl
│   │   ├── solution.jl
│   │   ├── dual_model.jl
│   │   └── definition.jl
│   └── Core/
│       ├── defaults.jl
│       └── time_dependence.jl
├── Display/
│   ├── Display.jl           # Display module
│   └── print.jl
├── Serialization/
│   ├── Serialization.jl     # Serialization module
│   └── export_import.jl
├── InitialGuess/
│   ├── InitialGuess.jl      # InitialGuess module
│   ├── types.jl
│   └── initial_guess.jl
├── Options/
│   └── Options.jl           # Existing module
├── Strategies/
│   └── Strategies.jl        # Existing module
├── Orchestration/
│   └── Orchestration.jl     # Existing module
├── Optimization/
│   └── Optimization.jl      # Existing module
├── Modelers/
│   └── Modelers.jl          # Existing module
└── DOCP/
    └── DOCP.jl              # Existing module
```

### Module Dependencies

```
CTModels
├── Types (no module, just includes)
├── Utils (module)
├── OCP (module)
│   ├── depends on: Types, Utils
├── Display (module)
│   ├── depends on: OCP
├── Serialization (module)
│   ├── depends on: OCP
├── InitialGuess (module)
│   ├── depends on: OCP, Utils
├── Options (module)
├── Strategies (module)
├── Orchestration (module)
├── Optimization (module)
├── Modelers (module)
│   ├── depends on: Optimization
└── DOCP (module)
    ├── depends on: Modelers
```

### Main Module Structure

```julia
module CTModels
    # External dependencies
    using CTBase, DocStringExtensions, Interpolations, MLStyle
    using Parameters, MacroTools, RecipesBase, OrderedCollections
    using SolverCore, ADNLPModels, ExaModels, KernelAbstractions, NLPModels
    
    # Type aliases (no module)
    include("Types/types.jl")
    
    # Core modules
    include("Utils/Utils.jl")
    using .Utils
    
    include("OCP/OCP.jl")
    using .OCP
    
    # Feature modules
    include("Display/Display.jl")
    using .Display
    
    include("Serialization/Serialization.jl")
    using .Serialization
    
    include("InitialGuess/InitialGuess.jl")
    using .InitialGuess
    
    # Existing modules
    include("Options/Options.jl")
    using .Options
    
    include("Strategies/Strategies.jl")
    using .Strategies
    
    include("Orchestration/Orchestration.jl")
    using .Orchestration
    
    include("Optimization/Optimization.jl")
    using .Optimization
    
    include("Modelers/Modelers.jl")
    using .Modelers
    
    include("DOCP/DOCP.jl")
    using .DOCP
    
    # Export core API
    export Model, Solution, PreModel
    export state!, control!, variable!
    export time!, dynamics!, objective!, constraint!
    export initial_guess, pre_initial_guess
    export export_ocp_solution, import_ocp_solution
    export ctinterpolate, matrix2vec
end
```

---

## Summary

### New Modules

1. **`Utils`** - Utility functions
   - Public: `ctinterpolate`, `matrix2vec`
   - Private: `to_out_of_place`, `@ensure`

2. **`OCP`** - Optimal control problem (reorganized)
   - Subdirectories: `Types/`, `Components/`, `Building/`, `Core/`
   - Public: Model/solution constructors and builders
   - Private: Internal helpers and validators

3. **`Display`** - Output formatting (from previous analysis)
4. **`Serialization`** - Import/export (from previous analysis)
5. **`InitialGuess`** - Initial guess (from previous analysis)

### Key Principles

1. **Modules as abstraction barriers**: Control what's exposed
2. **Clear organization**: Subdirectories for related functionality
3. **Public vs private**: Explicit exports define API
4. **No over-engineering**: Use subdirectories instead of nested modules when sufficient
5. **Maintainability**: Easy to navigate and understand

### Migration Strategy

1. Create `Utils` module
2. Reorganize `OCP` into subdirectories
3. Move `print.jl` to `Display` module
4. Move export/import to `Serialization` module
5. Rename `init` to `InitialGuess`
6. Update all imports in `CTModels.jl`
7. Update tests and documentation
