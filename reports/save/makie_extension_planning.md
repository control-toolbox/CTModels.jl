# Makie Extension Planning for CTModels.jl

**Issue**: [#84 - Makie extension](https://github.com/control-toolbox/CTModels.jl/issues/84)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Add interactive plotting via Makie with `makie_plot(sol)` and `makie_plot!(fig, sol)`. 
Requires refactoring shared utilities to `CTModels.PlotUtils` first (Phase 0), then building the Makie extension (Phases 1-6). Target ≥90% test coverage.

**MVP**: Phases 0 + 1 + 2 + 5

---

## 1. Overview

### Goal
Add a Makie extension to CTModels.jl for **interactive plotting** of optimal control solutions.

### Key Features
- Interactive zoom/pan (GLMakie)
- Publication-quality static plots (CairoMakie)
- Web-based interactive plots (WGLMakie)

### Reference
- [How to plot a solution (OptimalControl.jl)](https://control-toolbox.org/OptimalControl.jl/stable/manual-plot.html)
- [Makie.jl Documentation](https://docs.makie.org/stable/)

---

## 2. User Stories (All Validated ✅)

| ID | Description | Status |
|----|-------------|--------|
| US-1 | Basic Interactive Plot with layouts `:split`/`:group` | ✅ |
| US-2 | Component Selection (`:state`, `:control`, etc.) | ✅ |
| US-3 | Time Normalization (`time=:normalize`) | ✅ |
| US-4 | Constraints Visualization (`:path`, `:dual`, bounds) | ✅ |
| US-5 | Comparing Solutions (`makie_plot!()` overlay) | ✅ |
| US-6 | Animation | 🔜 Deferred |

---

## 3. Technical Decisions

| Decision | Choice |
|----------|--------|
| Function naming | `makie_plot()` and `makie_plot!()` |
| Backend | Depend on `Makie` abstract (v0.21+) |
| Shared utilities | `CTModels.PlotUtils` submodule in `src/plot/` |
| Layout implementation | Makie GridLayout with colspan (no PlotTree) |
| Stub typing | Full typing for `makie_plot(sol)`, no stub for `makie_plot!(fig, sol)` |

---

## 4. Layout Structure (`:split` mode)

```
┌────────────────────────┬────────────────────────┐
│         x₁             │           p₁           │  ← states | costates
├────────────────────────┼────────────────────────┤
│         x₂             │           p₂           │
├────────────────────────┴────────────────────────┤
│                        u₁                       │  ← controls (colspan)
├─────────────────────────────────────────────────┤
│                        u₂                       │
├────────────────────────┬────────────────────────┤
│       path(c₁)         │        dual(μ₁)        │  ← constraints | duals
└────────────────────────┴────────────────────────┘
```

---

## 5. Tasks

### Phase 0: Refactoring ✅

| Task | Description |
|------|-------------|
| T0.1 | Create `src/plot/plot_utils.jl` with `PlotUtils` submodule |
| T0.2 | Move `clean()`, `do_plot()`, `do_decorate()` to PlotUtils |
| T0.3a | Extract `get_plot_data()` to PlotUtils |
| T0.3b | Extract `compute_nb_lines()` to PlotUtils |
| T0.4 | Include PlotUtils in `src/CTModels.jl` (internal) |
| T0.5 | Update `ext/CTModelsPlots.jl` to use PlotUtils |
| T0.5b | Update `ext/plot_default.jl` to use `compute_nb_lines()` |
| T0.6a | Create `test/plot/test_plot_utils.jl` |
| T0.6b | Validate: plot_utils → plot → all tests |

### Phase 1: Infrastructure ✅

| Task | Description |
|------|-------------|
| T1.1 | Add `Makie = "0.21"` to Project.toml (weakdeps, extensions, compat) |
| T1.2 | Add stubs `makie_plot(sol)` and `makie_plot!(sol)` in CTModels.jl |
| T1.3 | Create `ext/CTModelsMakie.jl` entry point |
| T1.4 | Create `ext/makie_default.jl` with defaults |

### Phase 2: Core Plotting ✅

| Task | Description |
|------|-------------|
| T2.1 | `__makie_initial_figure()`: Figure + Axes layout (GridLayout + colspan) |
| T2.2 | `__makie_plot!()`: trace state/control/costate with `lines!()` |
| T2.3 | `__makie_plot()`: orchestrate initial + plot! |
| T2.4 | `makie_plot()`: public API |
| T2.5 | Labels from solution metadata |
| T2.6 | Control modes (`:components`, `:norm`, `:all`) |

### Phase 3: Overlay and Styles ✅

| Task | Description |
|------|-------------|
| T3.1 | `makie_plot!(fig, sol)`: overlay (same description required) |
| T3.2 | `makie_plot!(sol)`: use `Makie.current_figure()` |
| T3.3 | `*_style` arguments |
| T3.4 | `time_style` for t0/tf vertical lines |

### Phase 4: Constraints ✅

| Task | Description |
|------|-------------|
| T4.1 | Path constraints (`:path`) |
| T4.2 | Dual variables (`:dual`) |
| T4.3 | Bounds decoration (`hlines!()`) |
| T4.4 | `*_bounds_style` arguments |

### Phase 5: Testing ✅

| Task | Description |
|------|-------------|
| T5.1 | `test/makie/test_makie.jl` with unit + integration tests |
| T5.2 | `test/extras/makie_manual.jl` for visual verification |
| T5.3 | Add `:makie` to test infrastructure |

### Phase 6: Documentation ✅

| Task | Description |
|------|-------------|
| T6.1 | Docstrings for `makie_plot()` and `makie_plot!()` |
| T6.2 | Update package documentation |

---

## 6. Testing Guidelines

> [!IMPORTANT]
> **Julia constraint**: `struct` definitions must be at **top-level**, not inside functions.

### Test file structure

```julia
# test/makie/test_makie.jl

# ============================================================
# Fake types for unit testing (MUST be at top-level!)
# ============================================================
struct FakeMakieModel <: CTModels.AbstractModel end
struct FakeMakieSolution <: CTModels.AbstractSolution
    model::FakeMakieModel
end
CTModels.model(sol::FakeMakieSolution) = sol.model
CTModels.state_dimension(::FakeMakieSolution) = 2

function test_makie()
    # ========================================================
    # Unit tests – helper logic (no plotting side effects)
    # ========================================================
    @testset "makie helpers" begin ... end
    
    # ========================================================
    # Integration tests – actual plotting
    # ========================================================
    @testset "makie_plot basic" begin ... end
end
```

---

## 7. Test Commands

```bash
# PlotUtils only
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["plot_utils"]);'

# Plots extension
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["plot"]);'

# Makie extension
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["makie"]);'

# All tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels");'
```

---

## 8. Coverage Testing

> [!IMPORTANT]
> Requires **CTBase v0.17.2** for coverage postprocessing.

### Coverage command

```bash
julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true, test_args=["makie"]); include("test/coverage.jl")'
```

### Target

**≥ 90% coverage** for the Makie extension code.

### Iteration process

1. Run coverage command
2. Check uncovered lines in `ext/CTModelsMakie.jl`, `ext/makie_plot.jl`, etc.
3. Add tests for uncovered code paths
4. Repeat until ≥ 90%

### References

- [CTBase coverage.jl](https://github.com/control-toolbox/CTBase.jl/blob/main/test/coverage.jl)
- [CoveragePostprocessing.jl](https://github.com/control-toolbox/CTBase.jl/blob/main/ext/CoveragePostprocessing.jl)

---

## 9. GitHub Workflow

**Approach**: Issue #84 + PRs per phase (Option C)

### Structure

```
Issue #84 (Makie extension) ← Epic
  ├── PR "Phase 0: Refactoring PlotUtils" → linked to #84
  ├── PR "Phase 1: Makie infrastructure" → linked to #84
  ├── PR "Phase 2: Core plotting" → linked to #84
  ├── PR "Phase 3: Overlay & Styles" → linked to #84
  ├── PR "Phase 4: Constraints" → linked to #84
  ├── PR "Phase 5: Testing" → linked to #84
  └── PR "Phase 6: Documentation" → closes #84
```

### Checklist for Issue #84

- [ ] Phase 0: Refactoring (PlotUtils)
- [ ] Phase 1: Infrastructure
- [ ] Phase 2: Core Plotting
- [ ] Phase 3: Overlay & Styles
- [ ] Phase 4: Constraints
- [ ] Phase 5: Testing (≥90% coverage)
- [ ] Phase 6: Documentation

---

## 10. MVP

**MVP** = Phase 0 + Phase 1 + Phase 2 + Phase 5

Basic interactive plotting with state/control/costate, layouts, and tests.
