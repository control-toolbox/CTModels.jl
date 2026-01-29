Add idempotence tests for export/import serialization

## Summary

This PR adds comprehensive idempotence tests for the `export_ocp_solution` and `import_ocp_solution` functions to verify that multiple export-import cycles produce stable results with no progressive information loss.

## Changes

### Test Implementation (~460 lines)

**Helper Functions** (`test/suite/serialization/test_export_import.jl`):
- `compare_trajectories`: Compares function-based trajectories at time points
- `compare_infos`: Deep comparison of `Dict{Symbol,Any}` with type awareness
- `compare_solutions`: Comprehensive Solution object comparison with configurable tolerances

**New Test Cases** (7 total):
- **JSON** (4 tests): Double/triple cycles with duals, without duals, complex infos
- **JLD2** (3 tests): Double/triple cycles with duals, without duals

### Documentation

**Analysis**: `reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md`
- Identified 6 potential information loss points
- Analyzed existing test coverage
- Future investigation items (function serialization, deepcopy usage)

**Implementation Plan**: `reports/2026-01-29_Idempotence/reference/01_serialization_idempotence_plan.md`
- Detailed test strategy and verification plan

**Walkthrough**: `reports/2026-01-29_Idempotence/walkthrough.md`
- Summary of changes and test results
- Key findings and recommendations

## Test Results

```
Test Summary:                               | Pass  Total   Time
CTModels tests                              | 1721   1721  14.4s
  suite/serialization/test_export_import.jl | 1721   1721  14.4s
     Testing CTModels tests passed
```

✅ All tests pass - No regressions

## Key Findings

### Information Preserved ✅
- All scalar fields (objective, iterations, status, etc.)
- Time grid and variable (full precision)
- All trajectories (state, control, costate)
- All dual variables
- Infos dictionary structure and values

### Expected Transformations 🔄
1. **Functions → Discretization**: Analytical functions become interpolated after JSON export/import
   - Impact: Minimal (within `atol=1e-8`)
   - **Idempotent after first cycle** ✅

2. **Symbols → Strings**: Symbols in `infos` become strings after JSON serialization
   - Example: `:optimal` → `"optimal"`
   - **Idempotent after first cycle** ✅

### Conclusion
**No progressive information loss**: `sol₁ ≈ sol₂ ≈ sol₃` after multiple cycles.

## Future Work

The analysis identified areas for future investigation:
- Bidirectional `ctinterpolate`/`ctdeinterpolate` for lossless function serialization
- Review of `deepcopy` usage in `build_solution` (rationale unclear)
- Improved JLD2 handling of anonymous functions

See analysis document for details.

## Related Issue

Closes #217
