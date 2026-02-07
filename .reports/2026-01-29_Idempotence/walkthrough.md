# Idempotence Tests Implementation Walkthrough

**Version**: 1.0  
**Date**: 2026-01-29  
**Status**: ✅ Completed  
**Related Issue**: [#217](https://github.com/control-toolbox/CTModels.jl/issues/217)  
**Branch**: `test/serialization-idempotence`  
**PR Title**: "Add idempotence tests for export/import serialization"

---

## Summary

Successfully implemented comprehensive idempotence tests for CTModels.jl export/import serialization. All tests pass (1721/1721), verifying that multiple export-import cycles produce stable results with no progressive information loss.

---

## Changes Made

### 1. Helper Functions

Added three helper functions to [`test/suite/serialization/test_export_import.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/test/suite/serialization/test_export_import.jl):

#### `compare_trajectories`

- Compares two function-based trajectories at given time points
- Configurable tolerance (`atol`)
- Returns `true` if trajectories match within tolerance

#### `compare_infos`

- Deep comparison of `Dict{Symbol,Any}` dictionaries
- Handles nested structures recursively
- Type-aware comparison (numbers, vectors, dicts)
- Configurable numerical tolerance

#### `compare_solutions`

- Comprehensive deep comparison of `Solution` objects
- Compares all fields: scalars, trajectories, dual variables, infos
- Two tolerance levels:
  - `atol_numerical=1e-10` for scalars
  - `atol_trajectories=1e-8` for function evaluations

**Lines added**: ~230

---

### 2. Idempotence Tests

Added 7 new test cases covering both JSON and JLD2 formats:

#### JSON Tests (4 cases)

1. **Double cycle with duals** (`solution_example_dual`)
   - Verifies: `sol₁ ≈ sol₂` after two export-import cycles
   - Tests all dual variables

2. **Triple cycle with duals** (`solution_example_dual`)
   - Verifies: `sol₂ ≈ sol₃` (convergence)
   - Ensures no further degradation

3. **Double cycle without duals** (`solution_example`)
   - Tests solutions with all duals = `nothing`
   - Verifies edge case handling

4. **Complex infos** (custom solution)
   - Tests nested dictionaries, arrays, symbols
   - Verifies: Symbol → String conversion (expected behavior)
   - Confirms idempotence after conversion

#### JLD2 Tests (3 cases)

1. **Double cycle with duals**
2. **Triple cycle with duals**
3. **Double cycle without duals**

**Lines added**: ~230

---

## Test Results

```
Test Summary:                               | Pass  Total   Time
CTModels tests                              | 1721   1721  14.4s
  suite/serialization/test_export_import.jl | 1721   1721  14.4s
     Testing CTModels tests passed
```

✅ **All tests pass** - No regressions, all new tests successful

---

## Key Findings

### Information Preserved ✅

1. **Scalar fields**: objective, iterations, constraints_violation, message, status, successful
2. **Time grid**: Full precision maintained
3. **Variable**: Full precision maintained
4. **Trajectories**: State, control, costate (within interpolation tolerance)
5. **Dual variables**: All dual variables (path, boundary, state/control bounds, variable bounds)
6. **Infos dictionary**: Structure and values preserved

### Expected Transformations 🔄

1. **Functions → Discretization**: Analytical functions become interpolated functions after JSON export/import
   - **Impact**: Minimal (within `atol=1e-8`)
   - **Idempotent**: Yes (after first cycle)

2. **Symbols → Strings**: Symbols in `infos` dict become strings after JSON serialization
   - **Example**: `:optimal` → `"optimal"`
   - **Impact**: Type change but value preserved
   - **Idempotent**: Yes (after first cycle)

### No Information Loss After First Cycle ✅

The tests confirm that:

- `sol₁ ≈ sol₂` (double cycle)
- `sol₂ ≈ sol₃` (triple cycle)

**Conclusion**: Any information transformation occurs in the first cycle only. Subsequent cycles are perfectly idempotent.

---

## Documentation Created

1. **Analysis**: [`reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md)
   - Identified 6 potential information loss points
   - Analyzed existing test coverage
   - Provided recommendations

2. **Implementation Plan**: [`reports/2026-01-29_Idempotence/reference/01_serialization_idempotence_plan.md`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/reference/01_serialization_idempotence_plan.md)
   - Detailed test strategy
   - Helper function specifications
   - Verification plan

3. **This Walkthrough**: [`reports/2026-01-29_Idempotence/walkthrough.md`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/walkthrough.md)

---

## Next Steps

- [x] Implementation complete
- [x] All tests passing
- [x] Documentation complete
- [ ] Create Git branch `test/serialization-idempotence`
- [ ] Commit changes
- [ ] Push to GitHub
- [ ] Create Pull Request

---

## Recommendations

### For Users

The export/import functionality is **robust and idempotent**:

- Safe to use for solution persistence
- No progressive information loss
- Acceptable precision for numerical solutions

### For Future Improvements (Optional)

1. **Document Symbol → String conversion** in user-facing docs
2. **Consider adding type hints** for `infos` dict to guide users
3. **Add example** showing idempotence in documentation

---

## Future Work & Investigations

Based on analysis and user feedback, the following areas require investigation:

### 1. Function Serialization Strategy 🔍

**Current Architecture** (Clarified 2026-01-29):

The serialization already implements a **lossless round-trip** for interpolated functions:

1. **`build_solution`** creates interpolated functions from discrete data:

   ```julia
   # Lines 89-111 in src/OCP/Building/solution.jl
   x = ctinterpolate(T[1:N], matrix2vec(X[:, 1:dim_x], 1))
   u = ctinterpolate(T[1:M], matrix2vec(U[:, 1:dim_u], 1))
   p = ctinterpolate(T[1:L], matrix2vec(P[:, 1:dim_x], 1))
   ```

2. **Export** discretizes functions on the time grid:

   ```julia
   # Lines 160-161 in ext/CTModelsJSON.jl
   "state" => _apply_over_grid(CTModels.state(sol), T)
   "control" => _apply_over_grid(CTModels.control(sol), T)
   ```

3. **Import** reconstructs by calling `build_solution` with discrete data:

   ```julia
   # Lines 348-371 in ext/CTModelsJSON.jl
   CTModels.build_solution(ocp, T, X, U, v, P; ...)
   ```

**Key Insight**:

- `ctdeinterpolate` is **already implemented** as `_apply_over_grid`
- It evaluates functions on specific grid portions (T[1:N], T[1:M], T[1:L])
- Since `time_grid` is stored, we have all information to reconstruct perfectly
- `ctinterpolate` uses linear interpolation with constant extrapolation

**Remaining Issues**:

1. **JLD2 anonymous function warnings**: Functions cannot be natively serialized
2. **User-provided analytical functions**: Lost after first export (converted to interpolated)
3. **No function type tagging**: Cannot distinguish analytical vs interpolated functions

#### Proposed JLD2 Improvement

**Current Problem**: JLD2 tries to serialize functions directly, causing warnings.

**Solution**: Apply the same strategy as JSON:

1. **Extract utility functions** from `build_solution` (lines 89-111):
   - Create `_discretize_state(x::Function, T, dim_x)::Matrix{Float64}`
   - Create `_discretize_control(u::Function, T, dim_u)::Matrix{Float64}`
   - Create `_discretize_costate(p::Function, T, dim_x)::Matrix{Float64}`

2. **Refactor `build_solution`** to use these utilities

3. **Use in JLD2 serialization**:
   - Store discrete data (grids + matrices) instead of functions
   - Avoid code duplication with JSON
   - Eliminate function serialization warnings

**Benefits**:

- **Code reuse**: Same discretization logic for JSON and JLD2
- **No warnings**: JLD2 stores only data, not functions
- **Lossless**: Perfect reconstruction via `build_solution`
- **Maintainability**: Single source of truth for discretization

#### deepcopy Usage Review

From `src/OCP/Building/solution.jl`:

```julia
fx = (dim_x == 1) ? deepcopy(t -> x(t)[1]) : deepcopy(t -> x(t))
fu = (dim_u == 1) ? deepcopy(t -> u(t)[1]) : deepcopy(t -> u(t))
fp = (dim_x == 1) ? deepcopy(t -> p(t)[1]) : deepcopy(t -> p(t))
```

**Questions**:

- Why is `deepcopy` used on functions? (closure issues? sharing prevention?)
- Is it still necessary or is it a historical artifact?
- What's the performance/memory impact?
- Can we use `let` blocks or function wrappers instead?

**Recommended Actions**:

1. Test behavior with/without `deepcopy`
2. Profile memory and performance
3. Document rationale or remove if unnecessary

### 2. Action Items for Future PRs

**Phase 3: Deepcopy Optimization** (High Priority):

- [ ] Investigate `deepcopy` necessity in `build_solution` (lines 114-116)
- [ ] Test behavior with/without `deepcopy`
- [ ] Profile memory and performance impact
- [ ] Document rationale or remove if unnecessary

**Phase 4: Function Serialization** (High Priority):

- [x] ~~Investigate `isa Vector` checks in JSON deserialization~~ → **COMPLETED** (Phase 2)
- [ ] Extract discretization utilities from `build_solution`:
  - `_discretize_state(x::Function, T, dim_x)::Matrix{Float64}`
  - `_discretize_control(u::Function, T, dim_u)::Matrix{Float64}`
  - `_discretize_costate(p::Function, T, dim_x)::Matrix{Float64}`
- [ ] Refactor `build_solution` to use extracted utilities
- [ ] Update JLD2 to store discrete data instead of functions
- [ ] Eliminate JLD2 function serialization warnings

**Future Enhancements** (Medium Priority):

- [ ] Add function type tagging to distinguish analytical vs interpolated
- [ ] Document supported function types in user docs
- [ ] Add examples showing idempotence in documentation

**Long-term** (Low Priority):

- [ ] Consider architecture improvements for v1.0
- [ ] Add migration tools for existing serialized solutions

**See**: [`reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md) for detailed analysis.

---

## Next Steps

**Author**: CTModels Development Team  
**Verified**: 2026-01-29  
**Test Status**: ✅ All 1721 tests passing
