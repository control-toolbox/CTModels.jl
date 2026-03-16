# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- **92 tests pass**: Complete test coverage for new interpolation functionality
- **Behavior verification**: Tests confirm right-continuous steppost behavior
- **Integration testing**: Full workflow testing from interpolation to plotting

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
