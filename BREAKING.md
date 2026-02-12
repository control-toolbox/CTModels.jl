# Breaking Changes

This document describes breaking changes in CTModels releases and how to migrate your code.

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
