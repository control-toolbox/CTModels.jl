# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.1] - 2026-04-22

### 🚀 Enhancements

#### Clarified :exa Backend Error Message

- **Improved error message**: `get_build_examodel` now clearly explains that the Exa (:exa) modeler is unavailable for functional API (macro-free) models
- **Actionable suggestions**: Error message now suggests using ADNLP (:adnlp) or the @def macro from CTParser.jl
- **Better context**: Error reason explains the root cause (functional API does not generate Exa builder)
- **Regression test**: Added `test_build_examodel.jl` to verify error message content

### 🐛 Bug Fixes

- Fixed misleading error message that incorrectly suggested "dynamics" instead of "Exa modeler"

## [0.10.0] - 2026-04-20

### 📦 Release

- Initial stable release version (no breaking changes from 0.9.15-beta)

## [0.9.15-beta] - 2026-04-18

### 🚀 Enhancements

#### Box Constraint Aliases for Label Resolution

- **Unified source of truth**: Removed `original_dict` from `ConstraintsModel` and `original_constraints()` accessor
- **Aliases field**: Added `aliases::Vector{Vector{Symbol}}` as 5th element in box constraint tuples
- **Label resolution**: `constraint(model, label)` and `dual(sol, model, label)` now resolve labels via aliases
- **Effective bounds**: Returns intersected bounds when multiple constraints declared on same component
- **Per-component duals**: Dual matrices sized by state/control/variable dimension, not by number of declarations
- **Deduplication warning**: Single warning per component when duplicate bounds are declared

#### Dual Dimension Function Clarification

- **Renamed functions**: `dim_*_constraints_box(sol)` → `dim_dual_*_constraints_box(sol)` for clarity
- **Multiple dispatch**: `_dual_dimension` uses dispatch on `Nothing` (→ 0) and `Function` (→ length at t0)
- **Display improvement**: Dual variables only displayed if model has declared constraints
- **New exports**: `dim_dual_state_constraints_box`, `dim_dual_control_constraints_box`, `dim_dual_variable_constraints_box`

#### Optional Definition with EmptyDefinition Sentinel

- **Type hierarchy**: Introduced `AbstractDefinition` with concrete types `Definition(expr::Expr)` and `EmptyDefinition` (sentinel)
- **Optional definition**: `PreModel.definition` defaults to `EmptyDefinition()` instead of `nothing`
- **Model parametric**: `Model` is now parametric on `DefinitionType<<:AbstractDefinition`
- **Expression getter**: Added `expression()` function to extract `Expr` from `AbstractDefinition`
- **Build relaxation**: Removed precondition requiring definition in `build()`
- **Display refactor**: Split `Display/print.jl` into 5 focused files by responsibility
- **Code organization**: Moved definition setters to `Components/definition.jl`, Model getters to `Building/model.jl`

#### API Enhancements

```julia
# Definition is now optional
pre = PreModel()
pre.definition isa EmptyDefinition  # true by default

# Set definition via setter (auto-wraps Expr)
definition!(pre, quote
    t ∈ [0, 1], time
    x ∈ R, state
    u ∈ R, control
    ẋ(t) == u(t)
    ∫(0.5u(t)^2) → min
end)

# Extract expression
expr = expression(pre.definition)  # Returns the Expr

# Build without definition is now valid
model = build(pre)  # Works even without definition
```

#### User-Facing Model Predicates

- **New predicates**: Added user-friendly predicate methods for `Model` instances
- **Exclusive to Model**: Predicates are only available for immutable `Model`, not `PreModel`
- **Consistent naming**: Follows pattern `has_*` for presence checks, `is_*` for property checks
- **New exports**: `has_variable`, `has_control`, `has_abstract_definition`, `is_abstractly_defined`, `is_nonautonomous`, `is_nonvariable`

#### API Enhancements

```julia
# Check if problem has optimisation variables
has_variable(model)       # Alias for is_variable(model)
is_nonvariable(model)    # Opposite of is_variable(model)

# Check if problem has control input
has_control(model)        # Opposite of is_control_free(model)

# Check if problem has abstract definition
has_abstract_definition(model)      # Checks if definition is non-empty
is_abstractly_defined(model)        # Alias for has_abstract_definition

# Check time dependence
is_nonautonomous(model)             # Opposite of is_autonomous(model)
```

### 📊 API Changes

- **Breaking**: `is_variable(ocp::PreModel)`, `is_control_free(ocp::PreModel)`, `is_autonomous(ocp::PreModel)` removed
- **New exports**: `has_variable`, `has_control`, `has_abstract_definition`, `is_abstractly_defined`, `is_nonautonomous`, `is_nonvariable`
- **Display code**: Internal display functions use `__is_*_empty` predicates for PreModel, public predicates for Model

### 🔧 Internal Changes

- **Predicate refactoring**: Removed `__is_*_set` methods for `Model` (only `__is_*_empty` remains)
- **PreModel access**: Display code uses direct field access (`ocp.autonomous`) and internal predicates (`__is_variable_empty`, `__is_control_empty`)
- **Model access**: Public predicates (`is_variable`, `is_control_free`, `is_autonomous`) work for Model only
- **Test updates**: Migrated tests to use internal predicates for PreModel, public predicates for Model

## [0.9.14] - 2026-04-12

### 🚀 Enhancements

#### Automatic Grid Extension for Memory Optimization

- **Automatic grid unification**: Time grids that differ by only the last element (e.g., `T_control = T_state[1:end-1]`) are automatically extended to enable `UnifiedTimeGridModel`
- **Memory optimization**: Extending grids allows using `UnifiedTimeGridModel` instead of `MultipleTimeGridModel`, reducing memory overhead
- **No data modification**: Trajectory data matrices remain unchanged; interpolation automatically handles extended grids via `T[1:N]`
- **Transparent behavior**: Extension is automatic and requires no user intervention
- **Extension condition**: Only applies when a grid is a strict prefix (missing exactly the last element): `length(T_short) == length(T_long) - 1` AND `T_short == T_long[1:end-1]`

#### Improved Memory Efficiency

- **More unified grids**: Solutions with "almost identical" grids now benefit from unified grid model
- **Reduced storage**: Single grid stored instead of multiple separate grids
- **Same API**: No changes to user-facing API; behavior is fully backward compatible

### 📊 API Changes

```julia
# No API changes - behavior is automatic

# Before: Grids with missing last element used MultipleTimeGridModel
T_state = [0.0, 0.5, 1.0]
T_control = [0.0, 0.5]  # Missing last element
# Result: MultipleTimeGridModel (separate storage)

# After: Automatic extension enables UnifiedTimeGridModel
T_state = [0.0, 0.5, 1.0]
T_control = [0.0, 0.5]  # Missing last element
# Result: T_control automatically extended to [0.0, 0.5, 1.0]
# Result: UnifiedTimeGridModel (single grid storage)
```

### 🔧 Internal Changes

- **New function**: Added `_extend_grid_to_match()` helper function in `solution.jl`
- **Grid extension logic**: Integrated into `build_solution()` after validation, before grid detection
- **Reference grid selection**: Automatically selects longest grid as reference for extension
- **All grids extended**: `T_state`, `T_control`, `T_costate`, and `T_path` are all checked for extension
- **Updated docstring**: Added "Automatic Grid Extension" section to `build_solution()` documentation

### 🧪 Testing

- **New test file**: Added `test/suite/ocp/test_grid_extension.jl`
- **Unit tests**: Tests for extension logic (strict prefix detection, no extension for different grids)
- **Integration tests**: Tests for grid unification after extension
- **Coverage**: 8 tests passing, covering all extension scenarios

## [0.9.12-beta] - 2026-04-03

### 🚀 Enhancements

#### Default Component for Multiple Time Grid Solutions

- **Default time grid access**: `time_grid(sol)` now works for `MultipleTimeGridModel` without explicit component specification
- **Sensible default**: When no component is specified, defaults to `:state` grid (most commonly used)
- **Consistent API**: Same `time_grid(sol)` syntax works for both unified and multiple time grid solutions
- **Backward compatibility**: All existing code with explicit component specification continues to work unchanged

#### Improved Developer Experience

- **Reduced verbosity**: No need to specify `:state` component for most common use case
- **Intuitive behavior**: State trajectory is the natural default for optimal control problems
- **Cleaner code**: Simplified access to time grids in multi-grid solutions

### 📊 API Changes

```julia
# Before (required component specification)
time_grid(sol_multi, :state)  # Required for MultipleTimeGridModel
time_grid(sol_unified)        # Worked for UnifiedTimeGridModel

# After (consistent behavior)
time_grid(sol_multi)          # Now works! Defaults to :state
time_grid(sol_multi, :state)  # Still works (explicit)
time_grid(sol_unified)        # Still works (unchanged)
```

### 🔧 Internal Changes

- **Default function**: Added `__time_grid_default_component()::Symbol = :state` in `defaults.jl`
- **Method signature**: Updated `time_grid` method for `MultipleTimeGridModel` with default parameter
- **Removed exception**: Eliminated method that threw `IncorrectArgument` for missing component
- **Enhanced tests**: Updated test suites to verify new default behavior

### 🧪 Testing

- **Comprehensive coverage**: All existing tests pass with new behavior
- **Default behavior tests**: Added tests for automatic component selection
- **Compatibility verification**: Confirmed backward compatibility with explicit specifications
- **Integration testing**: End-to-end testing of multi-grid workflows

### 📝 Migration Notes

- **No breaking changes**: Existing code continues to work unchanged
- **Optional enhancement**: Can adopt new shorter syntax when convenient
- **Explicit still supported**: `time_grid(sol, :component)` syntax remains fully functional

---

## [0.9.11] - 2026-03-31

### 🔧 Internal Improvements

#### Code Quality and Maintenance

- **Code formatting**: Applied JuliaFormatter across entire codebase for consistent style
- **Enhanced readability**: Improved code formatting in interpolation, serialization, and display modules
- **Test formatting**: Updated test files for better maintainability
- **Zero functional changes**: All APIs remain unchanged, formatting only

#### Development Workflow

- **CompatHelper enhancement**: Added subdirectories input to CompatHelper workflow for better dependency management
- **Automated formatting**: Integrated JuliaFormatter in CI/CD pipeline
- **Development tools**: Improved development experience with consistent code style

### 📚 Documentation

- **No breaking changes**: This release focuses on internal code quality
- **Maintained compatibility**: All existing functionality preserved
- **Enhanced maintainability**: Cleaner codebase for future development

---

## [0.9.10-beta] - 2026-03-17

### 🎨 Documentation Enhancements

#### ANSI Color Support for Documenter

- **Printstyled to ANSI migration**: Replaced `printstyled()` calls with raw ANSI escape sequences for Documenter compatibility
- **Color preservation**: Colors now appear correctly in both terminal and generated HTML documentation
- **ANSI helper functions**: Added `_ansi_color()`, `_ansi_reset()`, and `_print_ansi_styled()` utilities
- **Documenter integration**: ANSI sequences automatically converted to CSS classes (`sgrXX`) in HTML output
- **Zero breaking changes**: Complete backward compatibility maintained for existing terminal usage

### 🔧 Internal Improvements

- **Display system refactoring**: 7 `printstyled()` calls migrated in `src/Display/print.jl`
- **Enhanced color support**: Bold and colored text now works in documentation examples
- **Performance optimized**: ANSI sequences have minimal overhead compared to `printstyled()`
- **Test coverage**: All display tests passing with new ANSI implementation

### 📚 Documentation Quality

- **Better visual hierarchy**: Mathematical problem definitions now properly colored in docs
- **Improved readability**: "Abstract definition", "minimize", and "subject to" sections highlighted
- **Consistent experience**: Terminal and documentation displays now visually identical

---

## [0.9.9-beta] - 2026-03-17

### 🚀 Major Features

#### Flexible Control Interpolation System

- **Dual interpolation support**: Both piecewise constant (`:constant`) and piecewise linear (`:linear`) interpolation for control signals
- **Configurable interpolation**: New `control_interpolation` keyword argument in `build_solution` signatures
- **Dynamic plotting**: Automatic seriestype selection based on interpolation type (`:steppost` for constant, `:path` for linear)
- **Serialization support**: Full round-trip preservation of interpolation type in JSON/JLD2 formats
- **Backward compatibility**: Existing files without `control_interpolation` field default to `:constant`

#### Enhanced Control Architecture

- **ControlModelSolution**: Added `interpolation::Symbol` field to store interpolation type
- **Accessors**: New `control_interpolation(sol::Solution)` and `interpolation(model::ControlModelSolution)` methods
- **Default system**: Centralized `__control_interpolation()::Symbol = :constant` method for consistent defaults
- **Export system**: `control_interpolation` added to CTModels exports for public API access

### 📊 API Enhancements

```julia
# Flexible interpolation in build_solution
sol = CTModels.build_solution(ocp, T_state, T_control, T_costate, T_path, X, U, v, P; 
                           control_interpolation=:linear)  # or :constant

# Access interpolation type
interp_type = CTModels.control_interpolation(sol)  # Returns :constant or :linear

# Automatic plotting adaptation
plot(sol, :control)  # Uses :steppost for constant, :path for linear
```

### 🔧 Serialization & Compatibility

- **JSON/JLD2 preservation**: Interpolation type survives complete export/import cycles
- **Backward compatibility**: Files without interpolation field default to `:constant`
- **Cross-format compatibility**: JSON ↔ JLD2 interpolation preservation verified
- **Comprehensive testing**: 1751 tests passing with full serialization coverage

### 🧪 Testing & Quality

- **Comprehensive test suite**: 96 new interpolation-specific tests added
- **Integration testing**: End-to-end testing from creation to serialization to plotting
- **Compatibility testing**: Backward compatibility with existing solutions verified
- **Performance validation**: No performance impact on existing workflows

### 📝 Internal Improvements

- **Consistent defaults**: `__control_interpolation()` method used across all components
- **Clean architecture**: Separation of interpolation logic from core functionality
- **Enhanced extensions**: JSON and JLD2 extensions updated with interpolation support
- **Documentation**: Complete docstrings and examples for new features

---

## [0.9.8-beta] - 2026-03-16

### 🚀 Major Features

#### Piecewise Constant Interpolation for Control Signals

- **New `ctinterpolate_constant` function**: Implements right-continuous steppost behavior for control signals
- **Control interpolation**: Controls now use `interpolation=:constant` by default in `build_solution`
- **Plotting integration**: Default `seriestype=:steppost` for control plotting, consistent with interpolation
- **Performance optimized**: Manual implementation ~20x-8600x faster to create, 10-21% faster for multiple evaluations

#### Enhanced Interpolation System

- **Parameterized interpolation**: `build_interpolated_function` now accepts `interpolation::Symbol` (`:linear`, `:constant`)
- **Manual `ctinterpolate`**: Replaced Interpolations.jl dependency with high-performance manual implementation
- **Flat extrapolation**: Both interpolation functions use flat extrapolation (returns boundary values)

### 📊 Performance Improvements

- **Creation speed**: Manual interpolation objects are ~20x-8600x faster to create
- **Evaluation speed**: 10-21% faster for multiple evaluations
- **Memory efficiency**: Zero allocations for interpolation object creation
- **Benchmark verified**: Comprehensive performance testing in `.extras/benchmark_interpolation.jl`

### 🧪 Testing

- **3456 tests pass**: Complete test coverage including new interpolation functionality
- **75 interpolation tests**: Unit tests + comprehensive integration tests
- **Behavior verification**: Tests confirm right-continuous steppost behavior
- **Integration testing**: End-to-end testing from `build_solution` to `control()` interpolation
- **Performance benchmarking**: Comprehensive testing in `.extras/benchmark_interpolation.jl`

### 📝 API Changes

```julia
# New constant interpolation
interp = CTModels.ctinterpolate_constant(x, f)  # Right-continuous steppost

# Enhanced interpolation helpers
fu = OCP.build_interpolated_function(U, T, dim, type; interpolation=:constant)

# Control plotting with steppost (automatic)
plot(sol, :control)  # Uses seriestype=:steppost by default
```

### 🔧 Internal Changes

- **Dependency reduction**: Manual interpolation implementation reduces Interpolations.jl dependency
- **Code clarity**: Explicit interpolation behavior with comprehensive documentation
- **Cohesion**: Interpolation and plotting behaviors are now fully consistent

---

## [0.9.7] - 2026-03-11

### Added - 0.9.7

- **OCP Without Control Input**: Optimal control problems can now be built and solved without defining a control variable (`control_dimension(ocp) == 0`)
  - `PreModel` defaults to an `EmptyControlModel()` when `control!` is not called
  - `build` accepts models without control while preserving backward compatibility

### Changed - 0.9.7

- **Relaxed Preconditions**: `dynamics!` and `objective!` no longer require control to be set (control is optional)
- **Constraints**: `constraint!` only requires control when `type == :control`
- **Plotting**: Requesting `:control` in plot descriptions is ignored when `control_dimension(sol) == 0`
- **Initialization**: `initial_control(ocp, Float64[])` is accepted when `control_dimension(ocp) == 0`

### Fixed - 0.9.7

- **Serialization Round-Trip Coverage**: Added JSON/JLD2 round-trip tests for solutions with `control_dimension == 0`
- **Documentation Accuracy**: Updated docstrings for control-optional behavior (build/dynamics/objective/constraints/plotting/display)

## [0.9.6] - 2026-03-10

### Added

- **Dedicated Costate Time Grid**: Reintroduced independent `T_costate` time grid for costate trajectories
  - `build_solution` now accepts 4 independent time grids: `T_state`, `T_control`, `T_costate`, `T_path`
  - Costate can now use a different discretization from state (e.g., for symplectic integrators)
  - `MultipleTimeGridModel` extended to include `:costate` grid
  - `clean_component_symbols` updated to map `:costate` → `:costate` (own grid)
  - `time_grid(sol, :costate)` now returns the costate-specific grid
  - All tests passing (3324/3324)

- **Enhanced Serialization**: Multi-grid format now includes `time_grid_costate`
  - JSON/JLD export includes dedicated costate grid
  - Backward compatibility: files without `time_grid_costate` use `T_state` as fallback
  - Automatic format detection and conversion

- **Comprehensive Documentation**: Added detailed docstrings explaining time grid semantics
  - `build_solution`: 173 lines of detailed documentation on 4-grid system
  - `_serialize_solution`: 128 lines explaining serialization formats
  - `_discretize_all_components`: 41 lines on grid-component associations
  - Complete examples and usage patterns

### Changed

- **Time Grid Validation**: `time_grid` getter now accepts `:costate` for both `UnifiedTimeGridModel` and `MultipleTimeGridModel`
- **Legacy Signature**: `build_solution(ocp, T, X, U, v, P; ...)` now forwards to 4-grid version with `T_state = T_control = T_costate = T_path = T`
- **Plotting**: Costate now maps to its dedicated grid in `_map_to_time_grid_component`

### Fixed

- **Grid Optimization**: Solutions with identical grids automatically use `UnifiedTimeGridModel` for memory efficiency
- **Test Coverage**: All multi-grid tests updated to use 4-grid signature and verify costate grid independence

## [0.9.5] - 2026-03-09

### Fixed

- **Variable API Cleanup**: Removed redundant `variable(sol::AbstractSolution)` method
  - Eliminated potential semantic inconsistency between different AbstractSolution subtypes
  - Solution concrete type already provides specific method that returns `value(sol.variable)`
  - Test types like `DummySolution1DVar` now require explicit implementations
  - Improved API clarity - each AbstractSolution subtype must implement explicit `variable()` method
  - All tests pass (2941/2941) - no functional impact on users

### Changed

- **Internal Architecture**: Cleaner method dispatch for variable extraction
  - Removed generic fallback that could return inconsistent data types
  - Each solution type now has explicit, well-defined variable extraction behavior
  - Enhanced maintainability and reduced potential for type confusion

## [0.9.4] - 2026-03-09

### Changed

- **Code Formatting**: Applied JuliaFormatter across entire codebase
  - Consistent code style throughout all source files
  - Improved readability and maintainability
  - No functional changes - formatting only

- **Documentation**: Fixed formatting issues in documentation files
  - Resolved duplicate text in BREAKING.md
  - Cleaned up markdown formatting
  - Enhanced documentation consistency

### Fixed

- **Documentation Issues**: Resolved formatting inconsistencies
  - Fixed duplicate text in v0.9.2 section of BREAKING.md
  - Improved markdown structure and readability
  - Ensured consistent documentation style

## [0.9.3] - 2026-03-08

### Changed - v0.9.3

- **Testing Standards Overhaul**: Complete migration of all test files to CTModels testing standards
  - Replaced all `using` with `import` statements for proper module isolation
  - Added explicit Test macro imports (`@test`, `@testset`, `@test_throws`, etc.)
  - Qualified all function calls with module prefixes (`Test.`, `CTModels.`, etc.)
  - Structured tests hierarchically with "Abstract Types" and specific test sections
  - Added `VERBOSE` and `SHOWTIMING` constants from `Main.TestData` for configurable output
  - Included critical outer scope function redefinitions for TestRunner compatibility
  - Preserved all existing test logic and functionality (895 tests passing)

- **Test Suite Modernization**: Enhanced test organization and reliability
  - Updated `test/runtests.jl` with improved test discovery and execution
  - Migrated 22 OCP test files to new standards (`test/suite/ocp/test_*.jl`)
  - Improved test isolation and reduced namespace pollution
  - Enhanced test output formatting and timing information
  - Better integration with CTBase testing infrastructure

### Fixed - v0.9.3

- **Test Compatibility**: Resolved TestRunner integration issues
  - Fixed outer scope function redefinitions for proper test discovery
  - Eliminated namespace conflicts between test modules
  - Improved test execution reliability and reproducibility
  - Enhanced error reporting and debugging capabilities

### Test Coverage

- **Comprehensive Test Migration**: All 895 tests successfully migrated
  - OCP Components: 22 files completely refactored
  - Test execution time: 31.3s (full suite)
  - 100% backward compatibility maintained
  - Enhanced test reliability and maintainability

## [0.9.2] - 2026-03-05

### Added

- **Multi-Time-Grid System**: Complete implementation of multiple time grid support
  - New `UnifiedTimeGridModel` for single time grid solutions
  - New `MultipleTimeGridModel` for different time grids per component
  - New `time_grid_model()` getter function for accessing time grid models
  - Enhanced `time_grid()` function with component-specific access
  - Support for empty dual grids with `nothing` values

- **Enhanced Serialization**: Dual format support for backward compatibility
  - Legacy format preservation for existing solutions
  - New multi-grid format with component-specific time grids
  - `_serialize_solution()` function now exported for advanced usage
  - Automatic format detection and conversion

- **Component Symbol Cleaning**: Order-preserving component name normalization
  - `clean_component_symbols()` function preserves input order
  - Plural to singular conversion (`:states` → `:state`, `:controls` → `:control`)
  - Ambiguous term mapping (`:constraint` → `:path`, `:cons` → `:path`)
  - Duplicate removal while maintaining original sequence

- **Plotting Enhancements**: Multi-time-grid compatible plotting system
  - Component mapping for special plotting symbols (`:control_norm` → `:control`)
  - Path constraint plotting support (`:path_constraint` → `:state`)
  - Dual constraint plotting (`:dual_path_constraint` → `:dual`)
  - Robust error handling for invalid component specifications

### Changed - v0.9.2

- **Build Solution API**: Enhanced multi-grid support in `build_solution()`
  - Accepts separate time grids for state, control, costate, and dual components
  - Automatic conversion from `LinRange` to `Vector{Float64}` for compatibility
  - Improved error messages for mismatched grid and data sizes
  - Better type stability for `UnifiedTimeGridModel` operations

- **Exception Handling**: Improved error messages and formatting
  - `IncorrectArgument` exceptions with semicolon-separated named arguments
  - Better localization of errors with file, line, and function information
  - Actionable error messages with suggestions for fixes

### Fixed - v0.9.2

- **Type Stability**: Resolved type inference issues in multi-time-grid operations
  - `UnifiedTimeGridModel` operations are now fully type-stable
  - `MultipleTimeGridModel` handles Union return types gracefully
  - Proper type annotations for time grid getter functions

- **Data Grid Consistency**: Fixed bounds errors in multi-grid test cases
  - Corrected data matrix sizes to match corresponding time grids
  - Proper handling of different grid sizes in test scenarios
  - Improved interpolation for mismatched grid dimensions

### Test Coverage - v0.9.2

- **Comprehensive Test Suite**: 79 tests passing (100% success rate)
  - Time Grid Models: 10 tests
  - Component Symbol Cleaning: 15 tests
  - Build Solution with Multiple Grids: 14 tests
  - Time Grid Getters: 17 tests
  - Serialization with Multiple Grids: 9 tests
  - Backward Compatibility: 5 tests
  - Error Handling: 3 tests
  - Type Stability: 6 tests

## [0.9.1] - 2026-03-02

### Removed

- **Test Extras Cleanup**: Removed `test/extras/` directory and all experimental test files
  - Removed `test/extras/Project.toml`
  - Removed debugging scripts (`debug_stack.jl`)
  - Removed experimental dynamics tests (`dynamics.jl`)
  - Removed export/import tests (`export_import.jl`)
  - Removed plotting experiments (`plot_duals.jl`, `plot_manual.jl`, `plot_series.jl`, `plot_variable.jl`)
  - Removed utility tests (`print_model.jl`, `test_deepcopy_necessity.jl`, `test_jld2_roundtrip.jl`, `test_manual.jl`)
  - Updated `.gitignore` to reflect cleanup

### Changed

- **Repository Hygiene**: Cleaner test structure focusing on production test suite
  - All functionality is covered by the main test suite
  - Removed ~900 lines of experimental/debugging code
  - Improved maintainability and clarity

## [0.9.0-beta] - 2026-02-12

### Breaking

- **Module Renaming**: InitialGuess module renamed to Init for better API ergonomics
  - `InitialGuess` module → `Init` module
  - `OptimalControlPreInit` type → `PreInitialGuess` type
  - `AbstractOptimalControlPreInit` type → `AbstractPreInitialGuess` type
  - **Action Required**: Update imports and type references

### Changed

- **API Ergonomics**: Shorter, more intuitive module and type names
  - `CTModels.InitialGuess` → `CTModels.Init`
  - Improved developer experience with concise naming
  - Updated all documentation references

### Added

- **Module Organization**: Consolidated Init module structure
  - Reorganized under `src/Init/` directory
  - Updated exports and imports throughout codebase
  - All tests updated to use new naming (3146 tests passing)

### Migration Guide

```julia
# Before
using CTModels.InitialGuess
pre = CTModels.OptimalControlPreInit(...)

# After
using CTModels.Init  
pre = CTModels.PreInitialGuess(...)
```

## [0.8.2-beta] - 2026-02-12

### Changed

- **InitialGuess Architecture**: Refactored validation system following Single Responsibility Principle
  - `initial_guess()` is now pure construction (no validation)
  - `build_initial_guess()` centralises validation for ALL input types
  - Fixed validation hole: direct `AbstractInitialGuess` now properly validated
  - Internal builders (`_initial_guess_from_*`) return without validation
  - Updated docstrings to reflect construction/validation separation

### Added

- **Regression Tests**: Comprehensive test coverage for refactored validation
  - Tests for invalid direct InitialGuess detection
  - Tests for construction/validation separation
  - Tests for centralised validation in all branches
  - All 147 tests passing

### Fixed

- **Validation Gap**: Direct `AbstractInitialGuess` passed to `build_initial_guess`
  was not being validated, creating a potential runtime error source
- **Architecture**: Improved code organization with clear separation of concerns

## [0.8.1-beta] - 2026-02-10

### Changed

- **Project Configuration**: Updated GitHub workflows to use CTActions shared workflows
  - Coverage workflow now uses `control-toolbox/CTActions/.github/workflows/coverage.yml@main`
  - Documentation workflow now uses `control-toolbox/CTActions/.github/workflows/documentation.yml@main`
  - Improved consistency with other Control Toolbox projects

- **Repository Management**: Enhanced .gitignore configuration
  - Added `.agent/`, `.windsurf/`, and `.reports/` directories to gitignore
  - Cleaned up Git history by removing previously tracked temporary directories
  - Better separation between source code and development artifacts

### Fixed

- Removed development artifacts from Git tracking while preserving local files
- Improved repository hygiene and reduced noise in version control

## [0.8.0-beta] - 2026-02-04

### Breaking

- **Module Migration**: Major refactoring with modules migrated to CTSolvers
  - Moved modules: Options, Strategies, Orchestration, Optimization, Modelers, DOCP
  - Updated dependencies and compatibility requirements
  - Code cleanup and removal of migrated components
  - **Action Required**: Projects using migrated modules must update to CTSolvers

### Added

- **Complete Documentation Overhaul**: Modern documentation with CTBase.automatic_reference_documentation
  - Full API reference with automatic generation
  - Integrated extensions documentation (Plots, JSON, JLD2)
  - Comprehensive docstrings following project standards
  - Cross-references and improved navigation

- **Enhanced Extensions**: Better integration and usability
  - Export of `plot` and `plot!` from CTModelsPlots extension
  - Extensions now documented in main API reference
  - Improved developer experience

- **Rich Documentation**: New docstring for `build_model()` and other critical functions
  - Complete parameter documentation
  - Usage examples and best practices
  - Error handling documentation

### Changed

- **Code Quality**: Significant cleanup and optimization
  - Removed migrated module code
  - Updated imports and dependencies
  - Improved type stability and performance

- **Testing**: Comprehensive test suite
  - 3135 tests passing (100% success rate)
  - Full coverage of remaining functionality
  - Integration tests for extensions

### Fixed

- Documentation generation issues resolved
- Cross-reference warnings handled gracefully
- Extension integration improvements

## [Unreleased]

## [0.7.1-beta] - 2026-01-22

### Added

- New `extract_solver_infos` function to extract convergence information from NLP solver execution statistics
- MadNLP extension (`CTModelsMadNLP`) for MadNLP-specific solver information extraction

### Changed

- Widened CTBase compatibility to support versions 0.16 and 0.17

## [0.7.0-beta] - 2026-01-22

### Changed

- Breaking change migration: CTModels 0.6.10 → 0.7.0-beta
- Widened CTBase compatibility from 0.17 to 0.16, 0.17

## [0.7.0] - 2026-01-18

### Changed

- Version bump to 0.7.0

---

## Version History

For older versions, see the [GitHub releases](https://github.com/control-toolbox/CTModels.jl/releases).

---

## Categories

- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** in case of vulnerabilities
