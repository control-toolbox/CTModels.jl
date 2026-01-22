# Optimization Problem Builders Refactoring

**Issue**: [#238 - Less creation of functions](https://github.com/control-toolbox/CTModels.jl/issues/238)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Refactor the NLP builder architecture to rely on **method dispatch** instead of storing closures/function pointers in structs. This involves introducing generic builder functions (`build_adnlp_model`, etc.) and updating `DiscretizedOptimalControlProblem` and test problems to be dispatchable.

---

## 1. Overview

### Goal
Replace the closure-based builder pattern with a dispatch-based system to improve type stability, inspection, and extensibility of the `CTModels` framework.

### Key Features
- **Generic Builder Stubs**: `build_adnlp_model(prob, ...)` etc.
- **Dispatchable Problems**: `DiscretizedOptimalControlProblem{Algo}` and `RosenbrockProblem`.
- **Clean Architecture**: Separation of data (structs) and logic (methods).

### References
- [Issue #238](https://github.com/control-toolbox/CTModels.jl/issues/238)
- Current `ADNLPModeler` implementation

---

## 2. User Stories

| ID | Description | Status |
|----|-------------|--------|
| US-1 | As a developer, I want to extend logical behavior by defining methods on types rather than injecting closures, so that the code is more idiomatic and inspectable (`methods()`). | ✅ |
| US-2 | As a maintainer, I want to remove opaque closures from structs to improve serialization (JLD2) and debugging (stack traces). | ✅ |
| US-3 | As a downstream developer (`CTSolvers`), I want a stable dispatch API to implement solvers without depending on internal storage fields. | ✅ |

---

## 3. Technical Decisions

| Decision | Choice |
|----------|--------|
| **Pattern** | **Method Dispatch** (replaces storing `Function` in structs). |
| **Problem Type** | **Parametric** `DiscretizedOptimalControlProblem{Algorithm}` (removes `backend_builders` field). |
| **Breaking Strategy** | **Phased**: Add new path (stubs/methods), migrate tests, then remove old path (breaking). |
| **Test Problems** | **Concrete Types**: Refactor generic `OptimizationProblem` to specific structs (`RosenbrockProblem`). |

---

## 4. Tasks

### Phase 1: Stubs & Modelers (Non-breaking)

| Task | Description |
|------|-------------|
| T1.1 | Define generic function stubs (`build_adnlp_model(prob, initial_guess; kwargs...)`, etc.) in `src/nlp/model_api.jl` with `NotImplemented` fallback. |
| T1.2 | Update `ADNLPModeler` and `ExaModeler` in `src/nlp/nlp_backends.jl` to call these functions instead of fetching closures. Direct switch (no transition layer). |

### Phase 2: Test Problems Refactor

| Task | Description |
|------|-------------|
| T2.1 | Define specific test problem structs (`RosenbrockProblem`, `ElecProblem`, etc.) replacing generic `OptimizationProblem`. |
| T2.2 | Implement `CTModels.build_adnlp_model` and `build_exa_model` methods for each test problem type. |
| T2.3 | Update test files (`test/problems/*.jl`) to use these new types and verify tests pass. |

### Phase 3: Core Refactor & Cleanup (Breaking)

| Task | Description |
|------|-------------|
| T3.1 | Refactor `DiscretizedOptimalControlProblem` to be parametric and remove `backend_builders` field. |
| T3.2 | Remove `get_adnlp_model_builder` and related getter functions. |
| T3.3 | Remove legacy `OptimizationProblem` struct from test helpers. |

---

## 5. Testing Guidelines

### Test file structure

```julia
# test/nlp/test_builders_dispatch.jl

# ============================================================
# Fake types for unit testing (MUST be at top-level!)
# ============================================================
struct FakeDispatchProblem <: CTModels.AbstractOptimizationProblem end

function CTModels.build_adnlp_model(::FakeDispatchProblem, args...; kwargs...)
    return "Dispatched!"
end

function test_builders_dispatch()
    # ========================================================
    # Unit tests
    # ========================================================
    @testset "Dispatch Mechanism" begin
        prob = FakeDispatchProblem()
        # Verify that calling the generic function dispatches correctly
        @test CTModels.build_adnlp_model(prob, nothing) == "Dispatched!"
    end
end
```

---

## 6. Test Commands

```bash
# Run NLP tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["nlp"])'

# Run all tests (crucial for Phase 3 breaking changes)
julia --project=. -e 'using Pkg; Pkg.test("CTModels")'
```

---

## 7. Coverage Testing

> [!IMPORTANT]
> Requires CTBase >= v0.17.2

```bash
julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true, test_args=["nlp"]); include("test/coverage.jl")'
```

Target: **≥ 90% coverage**.

---

## 8. GitHub Workflow

### Structure

```
Issue #238 (Builders Refactor)
  ├── PR "Phase 1: Stubs & API" → linked to #238
  ├── PR "Phase 2: Test Problems Migration" → linked to #238
  └── PR "Phase 3: Breaking Cleanup" → closes #238
```

### Checklist for Issue #238

- [ ] Phase 1: Stubs & API
- [ ] Phase 2: Test Problems Migration
- [ ] Phase 3: Breaking Cleanup

---

## 9. MVP

**MVP** = Phases 1+2+3 (Complete refactor required to ensure system consistency).

---

## Phase 3: User Validation

> Le rapport de planification est prêt : `reports/nlp_builders_refactor_planning.md`
>
> Voulez-vous faire une validation détaillée par user story et par tâche ?
> - **Oui** : Je vous détaille chaque point avec les sources pour validation pas à pas.
> - **Non** : Le plan est validé tel quel.
