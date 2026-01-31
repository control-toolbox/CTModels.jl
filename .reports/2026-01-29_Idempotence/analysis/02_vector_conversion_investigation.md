# Vector Conversion Logic Investigation

## Context

In [`CTModelsJSON.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJSON.jl#L224-L368), the `import_ocp_solution` function contains multiple `isa Vector` checks followed by conversion logic. The user questions whether these checks are necessary.

## Current Implementation

### Pattern Identified

The code follows this pattern for multiple fields:

```julia
# Example for state X
X = stack(blob["state"]; dims=1)
if X isa Vector  # Check if result is a Vector
    X = Matrix{Float64}(reduce(hcat, X)')
else
    X = Matrix{Float64}(X)
end
```

### All Occurrences

| Line | Field | Pattern |
|------|-------|---------|
| 232-236 | `X` (state) | `stack` → `isa Vector` check → conversion |
| 240-244 | `U` (control) | `stack` → `isa Vector` check → conversion |
| 248-252 | `P` (costate) | `stack` → `isa Vector` check → conversion |
| 260-264 | `path_constraints_dual` | `stack` → `isa Vector` check → conversion |
| 272-277 | `state_constraints_lb_dual` | `stack` → `isa Vector` check → conversion |
| 284-289 | `state_constraints_ub_dual` | `stack` → `isa Vector` check → conversion |
| 298-303 | `control_constraints_lb_dual` | `stack` → `isa Vector` check → conversion |
| 310-315 | `control_constraints_ub_dual` | `stack` → `isa Vector` check → conversion |

## Questions to Investigate

### 1. When does `stack(...; dims=1)` return a Vector vs Matrix?

**Hypothesis**: `stack` returns a `Vector` when the input is a 1D array (scalar state/control), and a `Matrix` for multi-dimensional cases.

**Need to verify**:

- What is the exact behavior of `stack` with different input shapes?
- What does the JSON blob contain for 1D vs multi-D cases?

### 2. Is the conversion logic correct?

**Current logic**:

- If `Vector`: `Matrix{Float64}(reduce(hcat, X)')`
- If not `Vector`: `Matrix{Float64}(X)`

**Questions**:

- Does `reduce(hcat, X)'` produce the correct matrix shape?
- Could we simplify this with a single conversion path?

### 3. Can we eliminate the conditional?

**Possible alternatives**:

1. **Ensure consistent JSON structure**: Always export as 2D arrays
2. **Use reshape**: `reshape(X, :, dim)` instead of conditional logic
3. **Type-stable conversion**: Single conversion function that handles both cases

## Proposed Investigation Plan

### Phase 1: Understanding Current Behavior

1. **Add debug tests** to capture actual types returned by `stack`:

   ```julia
   @testset "Stack behavior analysis" begin
       # Test 1D state (scalar)
       sol_1d = solution_example(; state_dim=1, control_dim=1)
       export_ocp_solution(sol_1d; filename="test_1d", format=:json)
       # Inspect JSON structure
       
       # Test multi-D state
       sol_nd = solution_example(; state_dim=3, control_dim=2)
       export_ocp_solution(sol_nd; filename="test_nd", format=:json)
       # Inspect JSON structure
   end
   ```

2. **Analyze JSON structure**: Examine actual JSON files to understand data shapes

3. **Document `stack` behavior**: Create test cases showing when it returns Vector vs Matrix

### Phase 2: Testing Necessity

1. **Create unit tests** for each conversion case:
   - Test with 1D state/control (should trigger `isa Vector`)
   - Test with multi-D state/control (should not trigger `isa Vector`)
   - Verify correct matrix dimensions after conversion

2. **Test alternative implementations**:

   ```julia
   # Alternative 1: Always use reshape
   X_alt1 = reshape(stack(blob["state"]; dims=1), :, state_dim)
   
   # Alternative 2: Direct Matrix conversion
   X_alt2 = Matrix{Float64}(stack(blob["state"]; dims=1))
   
   # Compare results with current implementation
   ```

3. **Benchmark performance**: Compare conditional vs unconditional approaches

### Phase 3: Simplification (if possible)

If investigation shows the checks are unnecessary:

1. **Refactor to single conversion path**
2. **Add regression tests** to ensure no breakage
3. **Document the simplified logic**

If investigation shows the checks are necessary:

1. **Document WHY they are needed**
2. **Add tests that would fail without the checks**
3. **Consider adding helper function** to reduce code duplication

## Recommended Test Structure

### Unit Tests

```julia
@testset "Vector conversion in JSON import" begin
    @testset "1D state (scalar)" begin
        # Create solution with 1D state
        # Export to JSON
        # Import and verify correct matrix shape
    end
    
    @testset "Multi-D state" begin
        # Create solution with 3D state
        # Export to JSON
        # Import and verify correct matrix shape
    end
    
    @testset "Edge cases" begin
        # Empty trajectories
        # Single time point
        # Large dimensions
    end
end
```

### Integration Tests

Use existing `solution_example` with different dimensions:

- `solution_example(; state_dim=1, control_dim=1)` → triggers Vector path
- `solution_example(; state_dim=3, control_dim=2)` → triggers Matrix path

## Expected Outcomes

### Scenario A: Checks are necessary

- **Document**: Add comments explaining when `stack` returns Vector
- **Test**: Add specific tests for 1D vs multi-D cases
- **Refactor**: Extract to helper function to reduce duplication (see below)

### Scenario B: Checks are unnecessary

- **Simplify**: Remove conditional logic
- **Test**: Verify all existing tests still pass
- **Document**: Explain why single path works for all cases

## Code Refactoring Recommendation

If the `isa Vector` checks prove necessary, we should **refactor to eliminate duplication** following the [Development Standards](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/reference/00_development_standards_reference.md).

### Current Code (Duplicated 8 times)

```julia
X = stack(blob["state"]; dims=1)
if X isa Vector
    X = Matrix{Float64}(reduce(hcat, X)')
else
    X = Matrix{Float64}(X)
end
```

### Proposed Refactoring

Create a helper function to encapsulate the conversion logic:

```julia
"""
$(TYPEDSIGNATURES)

Convert JSON3 array data to Matrix{Float64} for trajectory import.

Handles both Vector (1D trajectories) and Matrix (multi-D trajectories) cases
from `stack(...; dims=1)` output.

# Arguments
- `data`: Output from `stack(blob[field]; dims=1)`, can be Vector or Matrix

# Returns
- `Matrix{Float64}`: Properly shaped matrix for `build_solution`

# Notes
When `stack` returns a Vector (1D case), we use `reduce(hcat, ...)` to convert
to a column matrix. For Matrix output, we directly convert to Float64.
"""
function _json_array_to_matrix(data)::Matrix{Float64}
    if data isa Vector
        return Matrix{Float64}(reduce(hcat, data)')
    else
        return Matrix{Float64}(data)
    end
end
```

### Refactored Usage

```julia
# Before: 8 duplicated blocks
X = stack(blob["state"]; dims=1)
if X isa Vector
    X = Matrix{Float64}(reduce(hcat, X)')
else
    X = Matrix{Float64}(X)
end

# After: Single helper function call
X = _json_array_to_matrix(stack(blob["state"]; dims=1))
U = _json_array_to_matrix(stack(blob["control"]; dims=1))
P = _json_array_to_matrix(stack(blob["costate"]; dims=1))
# ... etc for all 8 fields
```

### Benefits

1. **DRY Principle**: Single source of truth for conversion logic
2. **Maintainability**: Changes only need to be made in one place
3. **Testability**: Can unit test the helper function independently
4. **Documentation**: Clear docstring explains the behavior
5. **Type Stability**: Return type annotation helps compiler optimization

### Implementation Steps

1. Create `_json_array_to_matrix` helper function
2. Add unit tests for the helper:
   ```julia
   @testset "_json_array_to_matrix" begin
       # Test Vector input (1D case)
       vec_data = [[1.0], [2.0], [3.0]]
       result = _json_array_to_matrix(vec_data)
       @test result isa Matrix{Float64}
       @test size(result) == (3, 1)
       
       # Test Matrix input (multi-D case)
       mat_data = [1.0 2.0; 3.0 4.0; 5.0 6.0]
       result = _json_array_to_matrix(mat_data)
       @test result isa Matrix{Float64}
       @test size(result) == (3, 2)
       
       # Type stability
       @inferred _json_array_to_matrix(vec_data)
       @inferred _json_array_to_matrix(mat_data)
   end
   ```
3. Replace all 8 occurrences with helper function call
4. Run full test suite to verify no regressions

## Action Items for Future PR

- [ ] Implement Phase 1 investigation tests
- [ ] Analyze JSON structure for 1D vs multi-D cases
- [ ] Document `stack` behavior with different inputs
- [ ] Test alternative conversion approaches
- [ ] Decide on simplification or documentation
- [ ] Implement chosen solution with tests
- [ ] Update this analysis with findings

## Related Issues

This investigation is related to:

- Code clarity and maintainability
- Performance optimization (avoid unnecessary conditionals)
- Type stability in deserialization

## Priority

**Medium** - Not blocking current functionality, but would improve code quality and understanding.
