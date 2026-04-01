# Breaking Changes

<!-- markdownlint-disable MD024 -->

This document describes breaking changes in CTModels releases and how to migrate your code.

## [0.9.11] - 2026-03-31

### No Breaking Changes

This version includes only internal improvements and code formatting enhancements:

- Applied JuliaFormatter across entire codebase for consistent style
- Enhanced CompatHelper workflow with subdirectories support
- All existing APIs remain unchanged
- Zero functional changes - formatting and maintenance only
- Improved code maintainability and development experience

---

## [0.9.10-beta] - 2026-03-17

### No Breaking Changes

This version includes only internal improvements and documentation enhancements:

- Migration from `printstyled()` to ANSI sequences for better Documenter compatibility
- All existing APIs remain unchanged
- Terminal behavior is preserved
- New color support in generated documentation

---

## [0.9.9-beta] - 2026-03-17

**No breaking changes** - This release adds flexible control interpolation with both constant and linear options while maintaining full backward compatibility.

### New Features (Non-Breaking) - 0.9.9-beta

- **Flexible Control Interpolation**
  - New `control_interpolation` keyword argument in `build_solution` signatures
  - Support for both `:constant` (piecewise constant) and `:linear` (piecewise linear) interpolation
  - Default behavior unchanged: controls use `:constant` interpolation
  - Dynamic plotting adaptation based on interpolation type

- **Enhanced Control Architecture**
  - `ControlModelSolution` now includes `interpolation::Symbol` field
  - New `control_interpolation(sol::Solution)` accessor method
  - New `interpolation(model::ControlModelSolution)` accessor method
  - `control_interpolation` added to public API exports

- **Serialization Support**
  - Complete round-trip preservation of interpolation type in JSON/JLD2 formats
  - Backward compatibility: existing files without interpolation field default to `:constant`
  - Cross-format compatibility between JSON and JLD2 verified

### API Enhancements (Non-Breaking)

```julia
# Flexible interpolation (optional, defaults to :constant)
sol = CTModels.build_solution(ocp, T_state, T_control, T_costate, T_path, X, U, v, P; 
                           control_interpolation=:linear)  # or :constant

# Access interpolation type (new)
interp_type = CTModels.control_interpolation(sol)  # Returns :constant or :linear

# Automatic plotting adaptation (enhanced)
plot(sol, :control)  # Uses :steppost for constant, :path for linear
```

### Migration Notes

- **No action required** for existing code - all current behavior preserved
- **Optional enhancement**: Use `control_interpolation=:linear` for smoother control signals
- **Serialization**: Existing solution files continue to work without modification
- **Plotting**: Automatic adaptation ensures correct visualization

---

## [0.9.8-beta] - 2026-03-16

**No breaking changes** - This release adds piecewise constant interpolation for control signals while maintaining full backward compatibility.

### New Features (Non-Breaking) - 0.9.8-beta

- **Piecewise Constant Interpolation**
  - New `ctinterpolate_constant` function with right-continuous steppost behavior
  - Controls use `interpolation=:constant` by default in `build_solution`
  - Control plotting uses `seriestype=:steppost` by default
  - Enhanced `build_interpolated_function` with `interpolation` parameter

- **Performance Improvements**
  - Manual interpolation implementation ~20x-8600x faster to create
  - 10-21% faster for multiple evaluations
  - Zero allocations for interpolation object creation

### API Enhancements (Non-Breaking)

```julia
# New constant interpolation (optional)
interp = CTModels.ctinterpolate_constant(x, f)

# Enhanced interpolation helpers (backward compatible)
fu = OCP.build_interpolated_function(U, T, dim, type; interpolation=:constant)

# Control plotting improvements (automatic)
plot(sol, :control)  # Now uses seriestype=:steppost by default
```

### Migration Notes - 0.9.8-beta

**No action required** - existing code continues to work unchanged.

You can now benefit from improved control interpolation:

```julia
# Existing code (still works)
sol = build_solution(ocp, T, X, U, v, P; objective=obj, ...)

# New behavior (automatic)
u = control(sol)  # Now uses piecewise constant interpolation
plot(sol, :control)  # Now uses steppost plotting by default
```

---

## [0.9.7] - 2026-03-11

**No breaking changes** - This release adds support for optimal control problems without a control input (`control_dimension == 0`) while maintaining full backward compatibility.

### New Features (Non-Breaking) - 0.9.7

- **Zero Control Dimension Support**
  - `control!` is now optional in `PreModel`
  - `build(pre)` accepts models where no control has been defined
  - Plotting ignores `:control` when `control_dimension(sol) == 0`
  - Serialization (JSON/JLD2) supports round-tripping solutions with empty control

### Migration Notes - 0.9.7

**No action required** - existing code continues to work unchanged.

You can now write models without `control!`:

```julia
pre = PreModel()
time!(pre, t0=0.0, tf=1.0)
state!(pre, 2)
dynamics!(pre, (x, u) -> [x[2], -x[1]])
objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
model = build(pre)

@assert control_dimension(model) == 0
```

## [0.9.6] - 2026-03-10

**No breaking changes** - This release adds a dedicated costate time grid while maintaining full backward compatibility.

### New Features (Non-Breaking)

- **4-Grid Time System**: `build_solution` now supports 4 independent time grids
  - New signature: `build_solution(ocp, T_state, T_control, T_costate, T_path, X, U, v, P; ...)`
  - Legacy signature preserved: `build_solution(ocp, T, X, U, v, P; ...)` still works
  - Automatic grid optimization when all grids are identical

- **Costate Grid Independence**: Costate now has its own dedicated time grid
  - `time_grid(sol, :costate)` returns costate-specific grid
  - `clean_component_symbols((:costate,))` → `(:costate,)` (was `(:state,)` before)
  - Enables different discretizations for state and costate (e.g., symplectic integrators)

- **Enhanced Serialization**: Multi-grid format includes `time_grid_costate`
  - Backward compatible: old files without `time_grid_costate` use `T_state` as fallback
  - Forward compatible: new files with 4 grids work with updated readers

### Migration Notes

**No action required** - All existing code continues to work unchanged:

```julia
# Legacy single-grid code (still works)
sol = build_solution(ocp, T, X, U, v, P; objective=obj, ...)

# New multi-grid code (optional)
sol = build_solution(ocp, T_state, T_control, T_costate, T_path, X, U, v, P; objective=obj, ...)
```

The package automatically detects and handles both formats. All tests pass (3324/3324).

## [0.9.5] - 2026-03-09

**No breaking changes** - This release focuses on internal API cleanup with no impact on public functionality.

### Internal Changes

- **Variable API Cleanup**: Removed redundant `variable(sol::AbstractSolution)` method
  - Eliminated potential semantic inconsistency between different AbstractSolution subtypes
  - Solution concrete type already provides specific method that returns `value(sol.variable)`
  - Test types like `DummySolution1DVar` now require explicit implementations
  - Enhanced method dispatch clarity and maintainability

### Migration Notes

No action required for users. All existing code continues to work unchanged. This is an internal improvement that:
- Removes a redundant generic method
- Improves type safety and method dispatch clarity
- Maintains all existing public APIs
- All tests pass (2941/2941)

## [0.9.4] - 2026-03-09

**No breaking changes** - This release focuses on code formatting and documentation improvements with no API changes.

### Internal Changes

- **Code Formatting**: Applied JuliaFormatter across entire codebase
  - Consistent code style throughout all source files
  - Improved readability and maintainability
  - No functional changes - formatting only

- **Documentation**: Fixed formatting issues in documentation files
  - Resolved duplicate text in BREAKING.md
  - Cleaned up markdown formatting
  - Enhanced documentation consistency

### Migration Notes

No action required for users. All existing code continues to work unchanged.

## [0.9.3] - 2026-03-08

**No breaking changes** - This release focuses on internal testing infrastructure improvements with no API changes.

### Internal Changes

- **Testing Infrastructure**: Complete migration to CTModels testing standards
  - All test files now use `import` instead of `using` for better module isolation
  - Test execution and discovery improved, but no impact on public API
  - Enhanced test reliability and maintainability (internal improvement only)

### Migration Notes

No action required for users. All existing code continues to work unchanged.

## [0.9.2] - 2026-03-05

**No breaking changes** - This release adds new multi-time-grid functionality while maintaining full backward compatibility. All existing APIs continue to work unchanged.

### New Features (Non-Breaking)

While not breaking changes, the following new features are available:

```julia
# New time grid model access
sol = build_solution(...)
time_grid_model(sol)  # Returns UnifiedTimeGridModel or MultipleTimeGridModel

# Enhanced time_grid with component specification
time_grid(sol, :state)     # Component-specific time grid
time_grid(sol, :control)   # Control time grid
time_grid(sol, :costate)   # Costate time grid

# Multi-grid build solution (new signature)
build_solution(ocp, T_state, T_control, T_costate, T_dual, X, U, v, P; kwargs...)

# Component symbol cleaning
clean_component_symbols((:states, :controls, :constraint))  # Returns (:state, :control, :path)
```

### Serialization Format Changes

The serialization format has been enhanced to support multi-time-grids, but existing files remain compatible:

- **Legacy Format**: Automatically detected and loaded
- **Multi-Grid Format**: New format with component-specific time grids
- **Automatic Conversion**: Seamless handling of both formats

### Plotting Enhancements

Plotting now supports additional component symbols with automatic mapping:

- `:control_norm` → `:control`
- `:path_constraint` → `:state`
- `:dual_path_constraint` → `:dual`

Existing plotting code continues to work unchanged.

---

## [0.9.1] - 2026-03-02

**No breaking changes** - This release only removes experimental test files from `test/extras/` directory. All public APIs remain unchanged.

---

## [0.9.0-beta] - 2026-02-12

### Module and Type Renaming

#### Overview
The InitialGuess module has been renamed to `Init` for better API ergonomics and more concise naming. This is a **breaking change** that requires users to update their imports and type references.

#### What Changed

##### Module Name
```julia
# Before (0.8.2-beta and earlier)
using CTModels.InitialGuess

# After (0.9.0-beta)
using CTModels.Init
```

##### Type Names
```julia
# Before
pre = CTModels.OptimalControlPreInit(...)
abstract_type = CTModels.AbstractOptimalControlPreInit

# After  
pre = CTModels.PreInitialGuess(...)
abstract_type = CTModels.AbstractPreInitialGuess
```

#### Migration Required

**User code changes required** - update your imports and type references:

```julia
# Before
using CTModels.InitialGuess
pre_init = CTModels.OptimalControlPreInit(state=0.1, control=0.2)

# After
using CTModels.Init
pre_init = CTModels.PreInitialGuess(state=0.1, control=0.2)
```

#### Benefits

- **More Concise API**: `CTModels.Init` vs `CTModels.InitialGuess`
- **Cleaner Type Names**: `PreInitialGuess` vs `OptimalControlPreInit`
- **Better Developer Experience**: Shorter, more intuitive names
- **Maintained Functionality**: Zero behavioral changes, only naming improvements

#### Compatibility

- All public functions remain unchanged
- Only module and type names have been updated
- All tests pass (3146/3146)
- Ready for production use

---

## [0.8.2-beta] - 2026-02-12

### InitialGuess Validation Architecture Change

#### Overview
Refactored the InitialGuess validation system to follow Single Responsibility Principle. This is an **internal architectural change** that does not affect the public API behavior but improves code organization.

#### What Changed

##### Construction vs Validation Separation
```julia
# Before (0.8.1-beta and earlier)
# initial_guess() validated internally, build_initial_guess() had mixed responsibilities

# After (0.8.2-beta)
# initial_guess() is pure construction
# build_initial_guess() centralises validation for ALL input types
```

##### Validation Coverage Fix
```julia
# Before: This case was NOT validated (potential runtime error)
bad_init = CTModels.InitialGuess(wrong_dimensions...)
validated = CTModels.build_initial_guess(ocp, bad_init)  # No validation!

# After: All branches are validated
validated = CTModels.build_initial_guess(ocp, bad_init)  # Throws IncorrectArgument
```

#### Migration Required

**No user code changes required** - this is an internal refactoring that:
- Maintains all existing public APIs
- Fixes a validation gap for direct `AbstractInitialGuess` inputs
- Improves error detection and code reliability
- All tests pass (147/147)

#### Benefits

- **Better Error Detection**: Invalid initial guesses are caught consistently
- **Cleaner Architecture**: Clear separation of construction and validation concerns
- **Improved Reliability**: Eliminates potential runtime errors from unchecked inputs

---

## [0.8.0-beta] - 2026-02-04

### Module Migration to CTSolvers

#### Overview
Major refactoring where several modules have been moved from CTModels to the new CTSolvers package.

#### Moved Modules
The following modules are no longer part of CTModels and must be imported from CTSolvers:

- **Options** → `using CTSolvers.Options`
- **Strategies** → `using CTSolvers.Strategies` 
- **Orchestration** → `using CTSolvers.Orchestration`
- **Optimization** → `using CTSolvers.Optimization`
- **Modelers** → `using CTSolvers.Modelers`
- **DOCP** → `using CTSolvers.DOCP`

#### Migration Guide

##### Before (CTModels < 0.8.0)
```julia
using CTModels
using CTModels.Options
using CTModels.Strategies
using CTModels.Optimization
```

##### After (CTModels ≥ 0.8.0)
```julia
using CTModels
using CTSolvers.Options
using CTSolvers.Strategies  
using CTSolvers.Optimization
```

#### Specific Changes

##### Option Types
```julia
# Before
using CTModels.Options
opt = CTModels.OptionValue(100, :user)

# After  
using CTSolvers.Options
opt = CTSolvers.OptionValue(100, :user)
```

##### Strategy Types
```julia
# Before
using CTModels.Strategies
strategy = CTModels.DirectStrategy()

# After
using CTSolvers.Strategies
strategy = CTSolvers.DirectStrategy()
```

##### Modelers
```julia
# Before
using CTModels.Modelers
modeler = CTModels.ADNLPModeler()

# After
using CTSolvers.Modelers
modeler = CTSolvers.ADNLPModeler()
```

##### DOCP Types
```julia
# Before
using CTModels.DOCP
docp = CTModels.DiscretizedOptimalControlProblem(...)

# After
using CTSolvers.DOCP
docp = CTSolvers.DiscretizedOptimalControlProblem(...)
)
```

#### Package Dependencies

If your package depends on CTModels and uses any of the moved modules, update your dependencies:

```toml
# Project.toml
[deps]
CTModels = "34c4fa32-2049-4079-8329-de33c2a22e2d"
CTSolvers = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Add CTSolvers

[compat]
CTModels = "0.8"
CTSolvers = "0.1"  # Or appropriate version
```

#### What Remains in CTModels

The following modules remain in CTModels and are unchanged:

- **OCP**: Core optimal control problem types and building
- **Utils**: Utility functions and helpers  
- **Display**: Text display and printing
- **Serialization**: Export/import functionality
- **InitialGuess**: Initial guess management
- **Extensions**: Plots, JSON, JLD2 extensions

#### Compatibility

- CTModels 0.8.0-beta maintains compatibility with CTBase 0.18
- All remaining CTModels APIs are unchanged
- Extensions (Plots, JSON, JLD2) work as before

#### Action Required

1. **Update imports**: Replace CTModels module imports with CTSolvers equivalents
2. **Update dependencies**: Add CTSolvers to your package dependencies
3. **Update code**: Change module prefixes from `CTModels.` to `CTSolvers.` where needed
4. **Test**: Verify your code works with the new module structure

#### Help and Support

- Check the [CTSolvers documentation](https://github.com/control-toolbox/CTSolvers.jl) for detailed API
- Open an issue if you encounter migration problems
- See examples in the CTSolvers repository for usage patterns

---

## Older Breaking Changes

See [CHANGELOG.md](CHANGELOG.md) for historical breaking changes.
