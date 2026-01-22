# Dual Variables Dimension Clarification

**Issue**: [#105 - Dual variables](https://github.com/control-toolbox/CTModels.jl/issues/105)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Clarify that `state_constraints_*_dual(t)` returns a vector of dimension `dim_x` (one per state component), not one per constraint declaration. Add a **warning** when multiple constraints are declared on the same component (bounds are overwritten).

---

## 1. Analysis

### Problem Statement
When a user declares:
```julia
x₂(t) ≤ 1.2
x₂(t) ≤ 2.0
x₂(t) ≤ 3.0
```
Three constraints are declared, but they all apply to `x₂`. 

### Current Behavior
- `append_box_constraints!` in `src/ocp/model.jl` appends to `state_cons_box_ind`, `state_cons_box_lb`, `state_cons_box_ub`.
- If called 3 times for `x₂`, the index `2` appears 3 times in `state_cons_box_ind`.
- `build_solution` creates duals based on `dim_x`, not on constraint count.

### Decision (Option A)
- **Dual dimension = `dim_x`** (state dimension).
- Only the last bound value "wins" for each component.
- **Warning**: Emit a warning when a component index is repeated, indicating the previous bound is overwritten.

---

## 2. Implementation Plan

### T1: Detect Duplicate Box Constraints
**File**: `src/ocp/model.jl`

Update `append_box_constraints!` or the loop in `build(constraints)` to detect when an index is already present and emit a warning:

```julia
for idx in rg
    if idx in inds
        @warn "Overwriting bound for component $idx. Previous value will be discarded."
    end
end
```

### T2: Document Behavior
**File**: `src/ocp/solution.jl` (docstring of `build_solution`)

Add documentation clarifying that `state_constraints_*_dual` has dimension `dim_x`.

---

## 3. Verification

### Test Commands
```bash
# Run constraints tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["constraints"])'
```

### Manual Check
Define an OCP with duplicate bounds on the same component and verify:
1. Warning is emitted.
2. `state_constraints_ub_dual(sol)(t)` returns a vector of dimension = state dimension.

---

## 4. Tasks

| Task | Description |
|------|-------------|
| T1 | Add duplicate index detection and warning in `src/ocp/model.jl`. |
| T2 | Update docstrings to clarify dual dimension semantics. |

---

## 5. Open Questions

> [!NOTE]
> If mathematically each constraint should have its own multiplier, Option B would be more rigorous. However, for simplicity and consistency with solver internals (which often use per-component bounds), Option A is adopted.
