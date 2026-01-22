# Naming and Consistency Planning for CTModels.jl

**Issue**: [#169 - Naming and consistency](https://github.com/control-toolbox/CTModels.jl/issues/169)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Add alias functions so both `is_*` and `has_*` naming conventions are available for boolean predicates. No breaking changes - existing API remains, new aliases added.

---

## 1. Current State

### Existing predicate functions

| Function | Location | Pattern |
|----------|----------|---------|
| `is_autonomous` | `model.jl`, `time_dependence.jl` | `is_*` ✅ |
| `has_fixed_initial_time` | `times.jl`, `model.jl` | `has_*` |
| `has_free_initial_time` | `times.jl`, `model.jl` | `has_*` |
| `has_fixed_final_time` | `times.jl`, `model.jl` | `has_*` |
| `has_free_final_time` | `times.jl`, `model.jl` | `has_*` |
| `has_mayer_cost` | `objective.jl`, `model.jl` | `has_*` |
| `has_lagrange_cost` | `objective.jl`, `model.jl` | `has_*` |

---

## 2. Proposed Aliases

### Time-related predicates

| Existing function | New alias (`is_*` style) |
|-------------------|--------------------------|
| `has_fixed_initial_time` | `is_initial_time_fixed` |
| `has_free_initial_time` | `is_initial_time_free` |
| `has_fixed_final_time` | `is_final_time_fixed` |
| `has_free_final_time` | `is_final_time_free` |

### Autonomy-related

| Existing function | New alias (`has_*` style) |
|-------------------|---------------------------|
| `is_autonomous` | `has_autonomous_dynamics` |

### Cost-related

| Existing function | New alias (`is_*` style) |
|-------------------|--------------------------|
| `has_mayer_cost` | `is_mayer_cost_defined` |
| `has_lagrange_cost` | `is_lagrange_cost_defined` |

---

## 3. Implementation

### T1: Add time aliases

**File**: `src/ocp/times.jl` (add after existing functions)

```julia
# Aliases for naming consistency (is_* style)
const is_initial_time_fixed = has_fixed_initial_time
const is_initial_time_free = has_free_initial_time
const is_final_time_fixed = has_fixed_final_time
const is_final_time_free = has_free_final_time
```

### T2: Add cost aliases

**File**: `src/ocp/objective.jl` (add after existing functions)

```julia
# Aliases for naming consistency (is_* style)
const is_mayer_cost_defined = has_mayer_cost
const is_lagrange_cost_defined = has_lagrange_cost
```

### T3: Add autonomy alias

**File**: `src/ocp/time_dependence.jl`

```julia
# Aliases for naming consistency (has_* style)
const has_autonomous_dynamics = is_autonomous
```

### T4: Add docstrings

Add `@doc` to alias constants or use `"""..."""` before each.

### T5: Add tests

**File**: `test/ocp/test_times.jl`, `test/ocp/test_objective.jl`, `test/ocp/test_variable.jl` (or similar)

Test that aliases return same values as original functions.

---

## 4. Tasks Summary

| Task | Description | Effort |
|------|-------------|--------|
| T1 | Add time aliases in `times.jl` | Low |
| T2 | Add cost aliases in `objective.jl` | Low |
| T3 | Add autonomy alias in `time_dependence.jl` | Low |
| T4 | Add docstrings | Low |
| T5 | Add tests | Low |

**Total effort**: Small

---

## 5. Test Commands

```bash
# Run time-related tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["times"]);'

# All tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels");'
```

---

## 6. GitHub Workflow

Single PR to close issue #169.

### Checklist for Issue #169

- [ ] T1: Add time aliases in `times.jl`
- [ ] T2: Add time aliases in `model.jl`
- [ ] T3: Add autonomy alias
- [ ] T4: Export aliases
- [ ] T5: Add docstrings
- [ ] T6: Add tests
