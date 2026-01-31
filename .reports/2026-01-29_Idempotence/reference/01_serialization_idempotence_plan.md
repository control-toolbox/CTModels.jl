# Implementation Plan: Idempotence Tests for Serialization

**Version**: 1.0  
**Date**: 2026-01-29  
**Status**: 📋 Implementation Plan  
**Related Issue**: [#217](https://github.com/control-toolbox/CTModels.jl/issues/217)  
**Branch**: `test/serialization-idempotence`  
**PR Title**: "Add idempotence tests for export/import serialization"

---

## Goal Description

Add comprehensive idempotence tests to verify that export/import cycles preserve solution information correctly. The goal is to:

1. Test that `export → import → export → import` produces stable results
2. Identify and document what information is lost during serialization
3. Ensure the loss converges (no further degradation after first cycle)
4. Improve confidence in the serialization implementation

**Background**: Issue #217 notes that export/import functions were written quickly and need verification. Current tests verify basic round-trips but don't test idempotence (stability across multiple cycles).

---

## User Review Required

> [!IMPORTANT]
> **Test Strategy**: This plan focuses on **adding tests** without modifying the serialization implementation. If tests reveal unexpected information loss, we may need a follow-up issue to improve the implementation.

> [!NOTE]
> **Scope**: This work only adds tests to `test/suite/serialization/test_export_import.jl`. No changes to production code (`src/` or `ext/`) are planned unless tests reveal bugs.

---

## Proposed Changes

### Test Files

#### [MODIFY] [test_export_import.jl](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/test/suite/serialization/test_export_import.jl)

**Changes**:

1. **Add helper functions** (lines ~15-20, after `remove_if_exists`):
   - `compare_solutions(sol1, sol2; atol_numerical, atol_trajectories)`: Deep comparison of two solutions
   - `compare_trajectories(f1, f2, times; atol)`: Compare function outputs at given times
   - `compare_infos(infos1, infos2)`: Compare `infos` dictionaries with type awareness

2. **Add idempotence test section** (lines ~490+, new section):
   - **JSON idempotence tests**:
     - Single cycle: `sol → export → import → sol₁`, verify `sol ≈ sol₁`
     - Double cycle: `sol₁ → export → import → sol₂`, verify `sol₁ ≈ sol₂`
     - Triple cycle: verify convergence
   - **JLD2 idempotence tests**:
     - Same structure as JSON
   - **Edge cases**:
     - Solutions with complex `infos` (nested dicts, arrays, symbols)
     - Solutions with function vs. matrix representations
     - Solutions with all duals populated

3. **Add information loss documentation tests** (lines ~600+):
   - Test that function discretization introduces acceptable interpolation error
   - Test that non-serializable types in `infos` become strings
   - Document expected vs. actual behavior

**Rationale**: These tests will systematically explore what information is preserved/lost during serialization cycles, addressing the gaps identified in the analysis document.

---

## Verification Plan

### Automated Tests

**Command to run**:
```bash
cd /Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["serialization"])'
```

**What will be tested**:
1. ✅ All existing tests still pass (regression check)
2. ✅ New idempotence tests pass for JSON format
3. ✅ New idempotence tests pass for JLD2 format
4. ✅ Comparison utilities work correctly
5. ✅ Information loss is within acceptable bounds

**Expected outcomes**:
- All tests pass
- Idempotence is verified (sol₁ ≈ sol₂ after multiple cycles)
- Any information loss is documented and acceptable

**If tests fail**:
- Document the failure in the analysis report
- Create follow-up issue for implementation improvements
- Adjust test tolerances if needed (with justification)

### Manual Verification

**Not required** - all verification is automated via unit tests.

---

## Implementation Details

### Helper Function: `compare_solutions`

```julia
function compare_solutions(
    sol1::CTModels.Solution,
    sol2::CTModels.Solution;
    atol_numerical::Float64 = 1e-10,
    atol_trajectories::Float64 = 1e-8,
)::Bool
    # Compare scalar fields
    CTModels.objective(sol1) ≈ CTModels.objective(sol2) atol=atol_numerical || return false
    CTModels.iterations(sol1) == CTModels.iterations(sol2) || return false
    # ... (all fields)
    
    # Compare trajectories at time grid points
    T = CTModels.time_grid(sol1)
    compare_trajectories(CTModels.state(sol1), CTModels.state(sol2), T; atol=atol_trajectories) || return false
    # ... (all trajectories)
    
    return true
end
```

### Helper Function: `compare_trajectories`

```julia
function compare_trajectories(
    f1::Function,
    f2::Function,
    times::Vector{Float64};
    atol::Float64 = 1e-8,
)::Bool
    for t in times
        v1 = f1(t)
        v2 = f2(t)
        if !isapprox(v1, v2; atol=atol)
            return false
        end
    end
    return true
end
```

### Idempotence Test Structure

```julia
Test.@testset "JSON idempotence: double cycle" verbose=VERBOSE showtiming=SHOWTIMING begin
    ocp, sol0 = solution_example_dual()
    
    # First cycle
    CTModels.export_ocp_solution(sol0; filename="idempotence_test", format=:JSON)
    sol1 = CTModels.import_ocp_solution(ocp; filename="idempotence_test", format=:JSON)
    
    # Second cycle
    CTModels.export_ocp_solution(sol1; filename="idempotence_test", format=:JSON)
    sol2 = CTModels.import_ocp_solution(ocp; filename="idempotence_test", format=:JSON)
    
    # Verify idempotence: sol1 ≈ sol2
    Test.@test compare_solutions(sol1, sol2)
    
    remove_if_exists("idempotence_test.json")
end
```

---

## Testing Strategy

### Test Coverage

| Test Category | JSON | JLD2 | Notes |
|---------------|------|------|-------|
| Single cycle | ✅ | ✅ | Existing tests |
| Double cycle | 🆕 | 🆕 | New idempotence tests |
| Triple cycle | 🆕 | 🆕 | Verify convergence |
| Complex `infos` | 🆕 | 🆕 | Non-serializable types |
| Function vs. matrix | ✅ | ❌ | Existing for JSON only |
| All duals populated | ✅ | ❌ | Existing for JSON only |

### Test Data

Use existing test problems:
- `solution_example()`: Basic solution, no duals
- `solution_example_dual()`: Full solution with all duals
- Custom solutions with complex `infos`

---

## Files Modified

- ✏️ `test/suite/serialization/test_export_import.jl`: Add ~200 lines of new tests
- 📄 `reports/2026-01-28_Checkings/analysis/07_serialization_idempotence_analysis.md`: Analysis document (already created)
- 📄 `reports/2026-01-28_Checkings/reference/04_serialization_idempotence_plan.md`: This implementation plan

---

## Success Criteria

✅ All new tests pass  
✅ Idempotence verified for both JSON and JLD2  
✅ Information loss documented and within acceptable bounds  
✅ No regressions in existing tests  
✅ Code follows development standards (see [reference/00_development_standards_reference.md](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-28_Checkings/reference/00_development_standards_reference.md))

---

## Next Steps

1. ✅ Create this implementation plan
2. ⏭️ Request user review of this plan
3. ⏭️ Implement helper functions
4. ⏭️ Implement idempotence tests
5. ⏭️ Run tests and document findings
6. ⏭️ Create walkthrough document
7. ⏭️ Create branch and PR

---

**Author**: CTModels Development Team  
**Last Review**: 2026-01-29
