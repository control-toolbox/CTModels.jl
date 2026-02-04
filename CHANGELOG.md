# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Added

- **Defensive Validation System**: Comprehensive validation infrastructure for OCP components
  - New `name_validation.jl` module with helper functions (`__collect_used_names`, `__has_name_conflict`, `__validate_name_uniqueness`)
  - Global uniqueness validation for component names across state, control, variable, and time
  - Inter-component name conflict detection (e.g., state component name vs control name)
  - Special handling for scalar components (dim=1) where name == component is allowed
  - Support for empty variables (q=0) without name conflicts

- **Component Validations**: Enhanced input validation for all OCP components
  - `state!`: Name uniqueness validation with inter-component conflict checks
  - `control!`: Name uniqueness validation with inter-component conflict checks
  - `variable!`: Name uniqueness validation with inter-component conflict checks (supports q=0)
  - `time!`: Name uniqueness validation and `t0 < tf` bounds validation
  - `objective!`: Case-insensitive criterion validation (accepts `:min`, `:max`, `:MIN`, `:MAX`)
  - `constraint!`: Element-wise `lb ≤ ub` bounds validation for all constraint types

- **Documentation**: Complete `# Throws` sections for all validated functions
  - Clear documentation of `CTBase.IncorrectArgument` exceptions
  - Clear documentation of `CTBase.UnauthorizedCall` exceptions
  - Detailed error messages for validation failures

- **Test Coverage**: Extensive test suites for validation logic
  - 323 unit tests for component validations (100% pass rate)
  - 53 integration tests covering complex scenarios (100% pass rate)
  - Tests for high-dimensional systems (dim > 3)
  - Tests for Unicode and special characters in names
  - Tests for edge cases (infinity bounds, equality constraints, etc.)
  - Tests for multiple constraint types combined
  - Type stability tests with `@inferred` where applicable

### Changed

- **Objective Criterion**: Now accepts case-insensitive input (`:min`, `:max`, `:MIN`, `:MAX`)
  - All criterion values are normalized to lowercase (`:min` or `:max`) for internal consistency
  - Maintains backward compatibility with existing code

### Fixed

- Eliminated duplicate function definition warnings in `test_objective.jl`
- Improved error messages for name conflicts to be more descriptive and actionable

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
