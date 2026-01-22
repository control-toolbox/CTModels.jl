# Maintenance v0.17.2 Planning

**Issue**: [#239 - Maintenance v0.17.2](https://github.com/control-toolbox/CTModels.jl/issues/239)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Standardize testing and documentation infrastructure by adopting `CTBase.jl` v0.17.2 conventions. This involves refactoring `test/runtests.jl` to use `CTBase.run_tests`, updating `docs/make.jl` to use `DocumenterReference`, and enabling code coverage reporting.

---

## 1. Overview

### Goal
Align `CTModels.jl` maintenance infrastructure with the `Control-Toolbox` ecosystem standards to reduce maintenance burden and improve developer experience.

### Key Features
- **Standardized Test Runner**: Use `CTBase.run_tests` for argument parsing and group selection.
- **Robust Documentation**: Fix local/remote link generation using `DocumenterReference`.
- **Coverage Reporting**: Enable standard coverage analysis via `test/coverage.jl`.

### References
- [CTBase.jl TestRunner](https://github.com/control-toolbox/CTBase.jl/blob/main/src/test_runner.jl)
- [DocumenterReference Extension](https://github.com/control-toolbox/CTBase.jl/blob/main/ext/DocumenterReference.jl)

---

## 2. User Stories

| ID | Description | Status |
|----|-------------|--------|
| US-1 | As a developer, I want to run specific test groups using standard arguments (e.g. `test_args=["ocp"]`) so I can iterate faster. | ✅ |
| US-2 | As a developer, I want documentation links to work correctly in local builds so I can verify documentation offline. | ✅ |
| US-3 | As a maintainer, I want automatic code coverage reports so I can track testing quality. | ✅ |

---

## 3. Technical Decisions

| Decision | Choice |
|----------|--------|
| **Test Engine** | `CTBase.run_tests` (replaces manual `OrderedDict` logic) |
| **Doc Plugin** | `DocumenterReference` extension from `CTBase` |
| **Coverage Tool** | `CTBase.postprocess_coverage` via `test/coverage.jl` |
| **Test Grouping** | Keep existing directory structure mapping (`ocp`, `nlp`, etc.) |

---

## 4. Tasks

### Phase 1: Test Runner Refactor

| Task | Description |
|------|-------------|
| T1.1 | Create `test/coverage.jl` with standard `CTBase` coverage script. |
| T1.2 | Refactor `test/runtests.jl` using `CTBase.run_tests` with `available_tests=("core/test_*", "init/test_*", "io/test_*", "meta/test_*", "nlp/test_*", "ocp/test_*", "plot/test_*")`. |
| T1.3 | Verify all test groups (`ocp`, `nlp`, `core`, etc.) run correctly. |

### Phase 2: Documentation Update

| Task | Description |
|------|-------------|
| T2.1 | Update `docs/make.jl` to explicitly call `DocumenterReference.reset_config!()`. |
| T2.2 | Set `remotes=nothing` in `makedocs` to support local linking. |
| T2.3 | Verify documentation build locally. |

---

## 5. Testing Guidelines

### Test Infrastructure Testing

Since we are modifying the test runner itself, verification involves running the test suite with various arguments:

```bash
# Verify specific group selection
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["core"])'

# Verify all tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels")'
```

---

## 6. Test Commands

```bash
# Run specific test group
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["<test_group>"]);'

# Run all tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels");'
```

---

## 7. Coverage Testing

> [!IMPORTANT]
> Requires CTBase >= v0.17.2

### Coverage command

```bash
julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true); include("test/coverage.jl")'
```

### Target

**≥ 90% coverage** (maintain existing level).

---

## 8. GitHub Workflow

### Structure

```
Issue #239 (Maintenance v0.17.2)
  ├── PR "Phase 1: Test Runner & Coverage" → linked to #239
  └── PR "Phase 2: Documentation" → closes #239
```

### Checklist for Issue #239

- [ ] Phase 1: Test Runner & Coverage
- [ ] Phase 2: Documentation

---

## 9. MVP

**MVP** = Phase 1 + Phase 2 (All tasks are required for v0.17.2 alignment).

---

## Phase 3: User Validation

> Le rapport de planification est prêt : `reports/maintenance_v0.17.2_planning.md`
