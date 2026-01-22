# Control Logic - Validation & Visualization

**Issue**: [#207 - Control logic](https://github.com/control-toolbox/CTModels.jl/issues/207)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Add defensive validation in `build_solution` to ensure state/control/costate dimensions match the time grid (either `N` or `N-1`), and enforce `steppre` visualization for controls.

---

## 1. Analysis

### Current Behavior
- `build_solution` automatically slices `T` to match the data size (`T[1:size(data,1)]`).
- **Risk**: It implicitly accepts arbitrary sizes (e.g., data covering only half the time grid), which is likely a bug in user code.

### Requirement
1.  **Validation**: Enforce that `size(X,1)`, `size(U,1)`, `size(P,1)` are either `length(T)` or `length(T)-1`.
2.  **Visualization**: Always use `steppre` for controls in `ext/plot.jl`.

---

## 2. Technical Design

### Solution Building (`src/ocp/solution.jl`)

Insert checks before interpolation:

```julia
dim_t = length(T)
N = size(X, 1)
M = size(U, 1)
L = size(P, 1)

@ensure N == dim_t || N == dim_t - 1 "State dimension mismatch"
@ensure M == dim_t || M == dim_t - 1 "Control dimension mismatch"
@ensure L == dim_t || L == dim_t - 1 "Costate dimension mismatch"
```

### Plotting (`ext/plot.jl`)

Update `__plot` recipe:
```julia
# For controls
seriestype := :steppre
```

---

## 3. Tasks

| Task | Description |
|------|-------------|
| T1.1 | Add dimension validation in `build_solution`. |
| T1.2 | Update `ext/plot.jl` to use `:steppre` for controls. |

---

## 4. Test Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["solution"]);'
```
