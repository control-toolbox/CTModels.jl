# Serialization Idempotence Analysis

**Version**: 1.0  
**Date**: 2026-01-29  
**Status**: 📊 Analysis Document  
**Related Issue**: [#217](https://github.com/control-toolbox/CTModels.jl/issues/217)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Current Implementation](#current-implementation)
3. [Idempotence Concept](#idempotence-concept)
4. [Potential Information Loss Points](#potential-information-loss-points)
5. [Test Coverage Analysis](#test-coverage-analysis)
6. [Recommendations](#recommendations)

---

## Introduction

### Purpose

This document analyzes the export/import serialization functionality in CTModels.jl to identify potential information loss during serialization cycles and design comprehensive idempotence tests.

### Scope

- JSON serialization (`ext/CTModelsJSON.jl`)
- JLD2 serialization (`ext/CTModelsJLD.jl`)
- Existing test coverage
- Identification of what information is preserved vs. lost

---

## Current Implementation

### Solution Structure

The `Solution` type (defined in `src/OCP/Types/solution.jl`) contains:

```julia
struct Solution{...} <: AbstractSolution
    time_grid::TimeGridModelType          # Discretised time points
    times::TimesModelType                 # Initial and final time
    state::StateModelType                 # State trajectory t → x(t)
    control::ControlModelType             # Control trajectory t → u(t)
    variable::VariableModelType           # Optimisation variable
    costate::CostateModelType             # Costate trajectory t → p(t)
    objective::ObjectiveValueType         # Optimal objective value
    dual::DualModelType                   # Dual variables
    solver_infos::SolverInfosType         # Solver statistics
    model::ModelType                      # Reference to original OCP
end
```

### JSON Implementation

**Export** (`CTModelsJSON.export_ocp_solution`):

- Serializes all fields to a JSON dictionary
- Uses `_apply_over_grid` to discretize function-based trajectories
- Converts `Dict{Symbol,Any}` to `Dict{String,Any}` for `infos`
- Handles non-serializable types by converting to strings

**Import** (`CTModelsJSON.import_ocp_solution`):

- Reads JSON and reconstructs `Solution` via `build_solution`
- Converts arrays back to matrices
- Deserializes `infos` back to `Dict{Symbol,Any}`
- Reconstructs function-based trajectories from discretized data

### JLD2 Implementation

**Export/Import** (`CTModelsJLD.{export,import}_ocp_solution`):

- Simple `save_object` / `load_object`
- Preserves Julia types natively
- May have issues with anonymous functions (warnings suppressed in tests)

---

## Idempotence Concept

### Definition

For serialization, **idempotence** means:

```
sol₀ → export → import → sol₁ → export → import → sol₂
```

Where `sol₁ ≈ sol₂` (and ideally `sol₀ ≈ sol₁`).

### What to Test

1. **Single cycle**: `sol₀ → export → import → sol₁`, verify `sol₀ ≈ sol₁`
2. **Multiple cycles**: `sol₁ → export → import → sol₂`, verify `sol₁ ≈ sol₂`
3. **Convergence**: After n cycles, no further information is lost

---

## Potential Information Loss Points

### 1. Function vs. Discretized Representation

**Issue**: JSON export discretizes functions to arrays, import reconstructs interpolated functions.

**Impact**:

- Original function: `x(t) = -exp(-t)` (analytical)
- After export/import: `x(t)` is interpolated from discrete points
- **Loss**: Analytical precision between grid points

**Severity**: 🟡 Medium (acceptable for numerical solutions)

### 2. Model Reference

**Issue**: The `model` field is **not exported** in JSON.

**Evidence**:

```julia
# CTModelsJSON.jl export - no "model" field in blob
blob = Dict(
    "time_grid" => ...,
    "state" => ...,
    # ... no "model" field
)
```

**Impact**:

- `import_ocp_solution` requires passing `ocp` as argument
- The imported solution's `model` field is set to the passed `ocp`
- **Loss**: If the original model differs from the passed model, metadata may be inconsistent

**Severity**: 🟢 Low (by design - user must provide model)

### 3. Non-Serializable Types in `infos`

**Issue**: `_serialize_value` converts non-serializable types to strings.

```julia
function _serialize_value(v)
    # ...
    else
        # For non-serializable types, convert to string representation
        return string(v)
    end
end
```

**Impact**:

- Complex types (e.g., custom structs, functions) become strings
- **Loss**: Type information and structure

**Severity**: 🟡 Medium (depends on what users store in `infos`)

### 4. Numerical Precision

**Issue**: JSON uses text representation of floats.

**Impact**:

- Potential rounding errors in float → string → float conversion
- **Loss**: Minimal (within machine precision)

**Severity**: 🟢 Low (acceptable)

### 5. JLD2 Anonymous Functions

**Issue**: JLD2 warns about serializing anonymous functions.

**Evidence**: Tests suppress warnings with `NullLogger()`

**Impact**:

- May fail to serialize/deserialize closures correctly
- **Loss**: Depends on function complexity

**Severity**: 🟡 Medium (JLD2-specific)

### 6. Metadata Fields

**Issue**: Some metadata is derived from the model, not stored in JSON.

**Fields potentially affected**:

- `state_name`, `control_name`, `variable_name`
- `state_components`, `control_components`, `variable_components`
- `initial_time_name`, `final_time_name`, `time_name`

**Impact**:

- These are reconstructed from the passed `ocp` during import
- **Loss**: If original model differs, names may differ

**Severity**: 🟢 Low (by design)

---

## Test Coverage Analysis

### Existing Tests

From `test/suite/serialization/test_export_import.jl`:

1. **Basic round-trip tests** (lines 28-73):
   - JSON with matrix representation
   - JSON with function representation
   - JLD2 with matrix representation
   - ✅ Verifies: objective, iterations, status

2. **Comprehensive JSON tests** (lines 79-222):
   - All fields preserved in JSON structure
   - Scalar fields, time grid, variable
   - State/control/costate discretization
   - All dual variables
   - ✅ Verifies: JSON structure completeness

3. **Full reconstruction test** (lines 224-378):
   - All fields reconstructed after import
   - Metadata (dimensions, names, components)
   - Trajectories at sample times
   - All dual variables
   - ✅ Verifies: Solution API completeness

4. **Edge cases** (lines 384-484):
   - Solutions with all duals = nothing
   - Custom `infos` Dict preservation
   - ✅ Verifies: Edge cases

### Gaps in Coverage

❌ **Missing**: Idempotence tests (multiple export/import cycles)  
❌ **Missing**: Comparison of `sol₁` vs `sol₂` after multiple cycles  
❌ **Missing**: Tests for information loss convergence  
❌ **Missing**: Tests with complex non-serializable types in `infos`  
❌ **Missing**: Systematic exploration of what information is lost

---

## Recommendations

### 1. Add Idempotence Tests

**Goal**: Verify that `export → import → export → import` produces identical results.

**Approach**:

- Test both JSON and JLD2 formats
- Compare `sol₁` (after 1 cycle) with `sol₂` (after 2 cycles)
- Use deep comparison functions

### 2. Create Comparison Utilities

**Helper functions needed**:

```julia
function compare_solutions(sol1, sol2; atol=1e-10) -> Bool
    # Compare all fields with appropriate tolerances
end

function compare_trajectories(f1, f2, times; atol=1e-8) -> Bool
    # Compare function outputs at given times
end
```

### 3. Test Information Loss Explicitly

**Scenarios**:

- Functions → discretization → interpolation
- Non-serializable types in `infos`
- Model metadata reconstruction

### 4. Document Expected Behavior

**Clarify**:

- What information is intentionally not preserved (e.g., `model` reference)
- What precision loss is acceptable (e.g., interpolation errors)
- What types are supported in `infos`

---

## Future Investigations

### 1. Function Serialization Strategy 🔍

**Current Situation**:

- JSON: Functions are discretized via `_apply_over_grid`, then reconstructed using `ctinterpolate` in `build_solution`
- JLD2: Uses `save_object`/`load_object` which may have issues with anonymous functions (warnings suppressed)
- `deepcopy` is used extensively in `src/OCP/Building/solution.jl` (lines 114-116, 135-206)

**Problem**:
The current approach has limitations:

1. **JLD2 anonymous functions**: Warnings about serializing closures are suppressed but the underlying issue remains
2. **deepcopy usage**: Unclear if `deepcopy` on functions is necessary or beneficial
3. **Information loss**: Function → discretization → interpolation loses analytical precision

**Proposed Investigation**:

#### Option A: Bidirectional ctinterpolate

Since we use `ctinterpolate` to create functions from discrete data, we could:

1. **Store interpolation metadata** in the `Solution` structure:
   - Interpolation method used (linear, cubic, etc.)
   - Original grid points
   - Interpolation parameters
2. **Create inverse operation**: `ctdeinterpolate` or similar to extract:
   - Time grid
   - Discrete values
   - Interpolation metadata
3. **Serialize metadata**: Include in JSON/JLD2 export to enable perfect reconstruction

**Benefits**:

- Lossless round-trip for interpolated functions
- No need for `deepcopy` on functions
- Clear separation between analytical and interpolated functions

**Challenges**:

- Need to distinguish between:
  - User-provided analytical functions (e.g., `x(t) = -exp(-t)`)
  - Interpolated functions created by `ctinterpolate`
- Backward compatibility with existing solutions

#### Option B: Function Type Tagging

Add metadata to track function provenance:

```julia
struct InterpolatedFunction{F<:Function}
    f::F
    grid::Vector{Float64}
    values::Matrix{Float64}
    method::Symbol  # :linear, :cubic, etc.
end
```

**Benefits**:

- Clear distinction between function types
- Easy to serialize/deserialize
- Preserves exact reconstruction capability

**Challenges**:

- Breaking change to `Solution` structure
- Need migration path for existing code

#### Option C: Hybrid Approach

- Keep current discretization for JSON (human-readable)
- Improve JLD2 to store function metadata natively
- Document `deepcopy` usage and potentially remove if unnecessary

### 2. deepcopy Investigation 🔍

**Current Usage** (from `src/OCP/Building/solution.jl`):

```julia
fx = (dim_x == 1) ? deepcopy(t -> x(t)[1]) : deepcopy(t -> x(t))
fu = (dim_u == 1) ? deepcopy(t -> u(t)[1]) : deepcopy(t -> u(t))
fp = (dim_x == 1) ? deepcopy(t -> p(t)[1]) : deepcopy(t -> p(t))
# ... and for all dual variables
```

**Questions to Investigate**:

1. **Why is deepcopy used?**
   - Is it to avoid closure issues?
   - Is it to prevent unintended sharing?
   - Historical reason that may no longer apply?

2. **Is it necessary?**
   - Test removing `deepcopy` and check for issues
   - Benchmark performance impact
   - Check if closures work correctly without it

3. **Alternative approaches?**
   - Use `let` blocks to create proper closures
   - Use function wrappers instead of anonymous functions
   - Store functions differently in `Solution`

**Recommended Actions**:

1. Create test cases to verify behavior with/without `deepcopy`
2. Profile memory usage and performance
3. Document findings and rationale
4. Consider deprecation if unnecessary

### 3. Action Items for Future Work

**High Priority**:

- [ ] Investigate `deepcopy` necessity and document rationale
- [ ] Design function metadata storage strategy
- [ ] Prototype `ctdeinterpolate` or equivalent inverse operation

**Medium Priority**:

- [ ] Add function type tagging to distinguish analytical vs interpolated
- [ ] Improve JLD2 serialization to handle functions properly
- [ ] Document supported function types in user-facing docs

**Low Priority**:

- [ ] Consider breaking changes for v1.0 to improve architecture
- [ ] Add migration tools for existing serialized solutions

---

## Next Steps

1. ✅ Create this analysis document
2. ✅ Create implementation plan in `reference/`
3. ✅ Implement comparison utilities
4. ✅ Implement idempotence tests
5. ✅ Document findings
6. 🔍 **NEW**: Investigate function serialization and deepcopy usage (future work)

---

**Author**: CTModels Development Team  
**Last Review**: 2026-01-29  
**Updated**: 2026-01-29 (added future investigations section)
