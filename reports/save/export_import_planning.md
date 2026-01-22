# Export/Import Verification Planning

**Issue**: [#217 - Improve import and export](https://github.com/control-toolbox/CTModels.jl/issues/217)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Existing JSON tests are comprehensive. JLD2 tests are minimal.
**Goal**: Verify "idempotency" (numerical stability) and data integrity.
**Plan**: Enhance JLD2 tests to match JSON coverage. Add a "Stability Test" (Export → Import → Export → Compare Files).

---

## 1. Analysis of Current State

### JSON (`ext/CTModelsJSON.jl`)
- **Method**: Manual serialization of discretized data + metadata. Reconstructs solution via `build_solution` + interpolation.
- **Tests**: Comprehensive (`test/io/test_export_import.jl`). Checks scalars, vectors, all duals, `infos`. Verifies numerical closeness (`≈`) of trajectories.

### JLD2 (`ext/CTModelsJLD.jl`)
- **Method**: Direct Julia object serialization (`save_object`/`load_object`).
- **Tests**: Minimal (only checks objective and iterations).
- **Risk**: Serialization of function objects (interpolations) can be fragile.

---

## 2. Verification Plan

### T1: Enhance JLD2 Tests
Update `test/io/test_export_import.jl` to include a full test suite for JLD2, mirroring the JSON tests:
- Check all scalar fields.
- Check trajectories (state, control, costate) numerically at grid points.
- Check duals.
- Check `infos`.

### T2: Stability / Idempotency Test
Add a test case for both formats:
1. `export(sol) → file1`
2. `sol2 = import(file1)`
3. `export(sol2) → file2`
4. **Verify**: `file1 == file2` (content equality) or `sol ≈ sol2` (numerical equality).

*Note*: For JSON, `file1 == file2` might effectively hold if floating point printing is deterministic. For JLD2, binary equality is expected if the object structure is preserved.

---

## 3. Implementation Tasks

| Task | Description |
|------|-------------|
| T1 | Add "JLD comprehensive round-trip" test set in `test/io/test_export_import.jl`. |
| T2 | Add "Stability test" (double export) for JSON and JLD2. |

---

## 4. Test Commands

```bash
# Run IO tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["io"]);'
```

---

## 5. GitHub Workflow

PR to verify and close #217.
