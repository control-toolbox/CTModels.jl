# Issue #254 - [Dev] SolverInfos

**Date**: 2026-01-22 | **State**: Open | **Repo**: control-toolbox/CTModels.jl  
**PR**: #248 on branch `breaking/ctmodels-0.7`

---

## 📋 Summary

This issue tracks the migration of the `SolverInfos` function from CTDirect to CTModels as part of the breaking change migration to v0.7.0-beta. The function will be **renamed to `extract_solver_infos`** to avoid confusion with the existing `SolverInfos` struct. It extracts convergence information from NLP solver execution statistics and needs to be implemented with two methods: a generic method for `SolverCore.AbstractExecutionStats` and a specialized method for MadNLP in an extension.

**Created**: 2026-01-21 | **Updated**: 2026-01-22 | **Labels**: internal dev

---

## 💬 Discussion

### Initial Issue Description (2026-01-21)
The issue references the `SolverInfos` function currently located in CTDirect.jl that needs to be migrated to CTModels. The function has two implementations:
1. A generic method for `SolverCore.AbstractExecutionStats`
2. A MadNLP-specific method in an extension

**Key Decisions**:
- The first method can be placed in CTModels module since `SolverCore` and `NLPModels` are lightweight packages (already dependencies)
- The second method should be placed in a new extension triggered by `MadNLP`
- Start from the `breaking/ctmodels-0.7` branch
- Use PR #248 as the base
- Create a new beta release `v0.7.1-beta` after implementation

**References**:
- [CTDirect MadNLP Extension](https://github.com/control-toolbox/CTDirect.jl/blob/dd63c219985549adc77602af6a6de76bf73ca089/ext/CTDirectExtMadNLP.jl#L53-L63): Source of the `SolverInfos` implementations

### Comment 1 - Method Signatures (2026-01-22, 10:32)
User @ocots provided detailed method signatures:

**Method 1 - Generic (for CTModels core)**:
````julia
"""
$(TYPEDSIGNATURES)

Retrieve convergence information from an NLP solution.

# Arguments

- `nlp_solution`: A solver execution statistics object.

# Returns

- `(objective, iterations, constraints_violation, message, status, successful)`:  
  A tuple containing the final objective value, iteration count,
  primal feasibility, solver message, solver status, and success flag.

# Example

```julia-repl
julia> extract_solver_infos(nlp_solution, nlp)
(1.23, 15, 1.0e-6, "Ipopt/generic", :first_order, true)
```
"""
function extract_solver_infos(
    nlp_solution::SolverCore.AbstractExecutionStats, ::NLPModels.AbstractNLPModel
)
    objective = nlp_solution.objective
    iterations = nlp_solution.iter
    constraints_violation = nlp_solution.primal_feas
    status = nlp_solution.status
    successful = (status == :first_order) || (status == :acceptable)
    return objective, iterations, constraints_violation, "Ipopt/generic", status, successful
end
````

**Method 2 - MadNLP Extension**:
```julia
function CTModels.extract_solver_infos(
    nlp_solution::MadNLP.MadNLPExecutionStats, nlp::NLPModels.AbstractNLPModel
)
    minimize = NLPModels.get_minimize(nlp)
    objective = minimize ? nlp_solution.objective : -nlp_solution.objective # sign depends on minimization for MadNLP
    iterations = nlp_solution.iter
    constraints_violation = nlp_solution.primal_feas
    status = Symbol(nlp_solution.status)
    successful = (status == :SOLVE_SUCCEEDED) || (status == :SOLVED_TO_ACCEPTABLE_LEVEL)
    return objective, iterations, constraints_violation, "MadNLP", status, successful
end
```

**Tasks**:
- ✅ Implement the two methods
- ✅ Add tests
- ✅ Make a new beta release of CTModels

### Comment 2 - Branch Strategy (2026-01-22, 10:35)
User @ocots confirmed:
- Start from `breaking/ctmodels-0.7` branch (currently checked out ✅)
- Use PR #248 as the base
- Target new beta version: `v0.7.1-beta`

---

## ✅ Completed

None yet - this is a new issue with clear requirements but no implementation has started.

---

## 📝 Pending Actions

### 🔴 Critical

**Implement generic `extract_solver_infos` method in CTModels core**
- Why: Core functionality needed for all NLP solvers
- Where: `src/nlp/extract_solver_infos.jl` (new file)
- Complexity: Simple
- Details: Add the generic method that works with `SolverCore.AbstractExecutionStats` and `NLPModels.AbstractNLPModel`

**Create MadNLP extension for specialized `extract_solver_infos` method**
- Why: Handle MadNLP-specific behavior (objective sign, status codes)
- Where: `ext/CTModelsMadNLP.jl` (new file)
- Complexity: Simple
- Details: Create new extension file triggered by MadNLP package

**Add MadNLP to Project.toml weakdeps**
- Why: Required for the extension to be triggered
- Where: `Project.toml`
- Complexity: Simple
- Details: Add `MadNLP` to `[weakdeps]` section and register extension in `[extensions]`

### 🟡 High

**Add comprehensive tests for `extract_solver_infos` methods**
- Why: Ensure both methods work correctly and handle edge cases
- Where: `test/nlp/test_extract_solver_infos.jl` (new file)
- Complexity: Moderate
- Details: Test both the generic method and the MadNLP extension method with mock solver results

**Update documentation**
- Why: Document the new public API
- Where: `docs/src/` (appropriate section)
- Complexity: Simple
- Details: Add docstrings and examples for the `extract_solver_infos` function

### 🟢 Medium

**Create beta release v0.7.1-beta**
- Why: Make the new functionality available for testing
- Where: GitHub releases
- Complexity: Simple
- Details: Tag and release after all implementation and tests are complete

---

## 🔧 Technical Analysis

**Code Findings**:
- `SolverCore` and `NLPModels` are already dependencies in `Project.toml` (lines 20, 16) ✅
- `AbstractSolverInfos` type and `SolverInfos` struct already exist in `src/core/types/ocp_solution.jl` ✅
- The `SolverInfos` struct is used throughout the codebase (9 references in `src/ocp/solution.jl`)
- No existing `SolverInfos` function methods found in the codebase
- Extension infrastructure already exists (`ext/` directory with 3 extensions)
- Currently on the correct branch: `breaking/ctmodels-0.7` ✅

**⚠️ IMPORTANT CLARIFICATION: `SolverInfos` Struct vs Function**

There are **two different things** both named `SolverInfos`:

1. **`SolverInfos` struct** (already exists in `src/core/types/ocp_solution.jl:96-103`):
   - **Role**: Data container that stores solver information
   - **Fields**: `iterations`, `status`, `message`, `successful`, `constraints_violation`, `infos`
   - **Constructor signature**: `SolverInfos(iterations::Int, status::Symbol, message::String, successful::Bool, constraints_violation::Float64, infos::Dict)`
   - **Usage**: Used in `Solution` objects to store solver metadata
   - **Example** (line 225-227 of `solution.jl`):
     ```julia
     solver_infos = SolverInfos(
         iterations, status, message, successful, constraints_violation, infos
     )
     ```

2. **`extract_solver_infos` function** (to be implemented - this issue):
   - **Role**: Data extractor that converts NLP solver execution statistics into the 6 values needed to construct the struct
   - **New name**: Renamed from `SolverInfos` (in CTDirect) to `extract_solver_infos` (in CTModels) to avoid confusion with the struct
   - **Signature**: 
     ```julia
     extract_solver_infos(nlp_solution::SolverCore.AbstractExecutionStats, 
                          nlp::NLPModels.AbstractNLPModel)
     ```
   - **Returns**: A 6-element tuple `(objective, iterations, constraints_violation, message, status, successful)`
   - **Usage**: Called by solver backends (CTDirect, future CTSolvers) to extract standardized information from solver-specific result objects
   - **Note**: The tuple elements are in a **different order** than the struct constructor! The function returns `(objective, ...)` first, but the struct doesn't have an `objective` field (it's stored separately in the `Solution`).

**Why this design?**
- The **function** acts as an adapter/extractor that normalizes solver-specific results
- The **struct** is the standardized data container used throughout CTModels
- This separation allows different solvers (Ipopt, MadNLP, etc.) to provide their results in different formats, which the `SolverInfos` function then standardizes

**Julia Standards**:
- ✅ Documentation: Project uses `DocStringExtensions` (already in deps)
- ✅ Testing: Test infrastructure exists (`test/` directory with comprehensive tests)
- ✅ Type Stability: Need to ensure return type is consistent (tuple of 6 elements)
- ✅ Structure: Extension pattern is appropriate for optional MadNLP dependency
- ✅ Package version: Currently at `v0.7.0-beta`, will become `v0.7.1-beta`

**Performance**: 
- The function is a simple data extraction operation, no performance concerns
- Return type should be type-stable (tuple of specific types)

**Design Considerations**:
1. **Return Type**: The function returns a 6-element tuple `(objective, iterations, constraints_violation, message, status, successful)`. This tuple is then unpacked to construct a `SolverInfos` struct (see `src/ocp/solution.jl:225-227`).

2. **Critical Finding**: The `SolverInfos` **struct** already exists in `src/core/types/ocp_solution.jl:96-103`. What we need to add is a **function** named `extract_solver_infos` that extracts information from NLP solver execution statistics and returns the 6-element tuple.

3. **Current Usage Pattern**: In `src/ocp/solution.jl:225-227`, the code calls:
   ```julia
   solver_infos = SolverInfos(
       iterations, status, message, successful, constraints_violation, infos
   )
   ```
   This is the **struct constructor**. The new `extract_solver_infos` **function** will be called elsewhere (likely in CTDirect or future solver interfaces) to extract these values from solver results.

4. **Extension Pattern**: MadNLP extension follows the established pattern in CTModels (similar to existing `CTModelsJLD`, `CTModelsJSON`, `CTModelsPlots` extensions).

5. **Namespace**: The function should be in the `CTModels` namespace (not `CTDirect`) since it's being migrated to CTModels.

---

## 🚧 Blockers

None identified. All requirements are clear and dependencies are in place.

---

## 💡 Recommendations

**Immediate**:
1. **File creation**: Create new file `src/nlp/extract_solver_infos.jl` containing:
   - Generic method for `SolverCore.AbstractExecutionStats`
   - Proper docstring with examples
   - Export the function in `src/CTModels.jl`

2. **Extension setup**: Create `ext/CTModelsMadNLP.jl` with the MadNLP-specific method

3. **Test strategy**: Create `test/nlp/test_extract_solver_infos.jl` with tests that:
   - Mock `SolverCore.AbstractExecutionStats` objects
   - Test both success and failure cases
   - Verify the MadNLP extension loads correctly
   - Test the objective sign handling for MadNLP (minimize vs maximize)

**Long-term**:
- Consider creating a more structured return type instead of a 6-element tuple for better type safety and readability
- Document the relationship between the `extract_solver_infos` function and the `SolverInfos` struct

**Julia Alignment**:
- ✅ Follows Julia extension pattern for optional dependencies
- ✅ Uses lightweight core dependencies (`SolverCore`, `NLPModels`)
- ✅ Maintains backward compatibility through careful API design

---

**Status**: Ready to implement - All requirements clear, no blockers  
**Effort**: Small (estimated 2-3 hours for implementation + tests + documentation)
