# 🎯 Action Plan: PR #248 + Issue #254 - Extract SolverInfos Migration

**Date**: 2026-01-22  
**PR**: #248 by @ocots | **Branch**: `breaking/ctmodels-0.7` → `main`  
**State**: OPEN | **Linked Issue**: #254 (SolverInfos migration)

---

## 📋 Overview

**PR #248 Summary**: Breaking change migration from CTModels 0.6.10 → 0.7.0-beta. Currently only contains version bump and CTBase compatibility widening.

**Issue #254 Summary**: Migrate `SolverInfos` function from CTDirect to CTModels, renaming it to `extract_solver_infos` to avoid confusion with the existing `SolverInfos` struct. Implement generic method + MadNLP extension.

**Status**: PR is open and passing all CI checks, but Issue #254 work has not started yet.

---

## 🔍 Project Context

**Project**: CTModels.jl (Julia package)  
**Current branch**: `breaking/ctmodels-0.7` ✅  
**CI Status**: ✅ All 31 checks passing (tests, coverage, docs, breakage tests)  
**Local changes**: 1 uncommitted change in `src/ocp/solution.jl` (blank line added)

**PR Changes**:
- `Project.toml`: Version `0.7.0` → `0.7.0-beta`
- `Project.toml`: CTBase compat widened from `0.17` to `0.16, 0.17`

---

## 🎯 Gap Analysis

### ✅ Completed (PR #248)
- ✓ Version bumped to `0.7.0-beta`
- ✓ CTBase compatibility widened
- ✓ All CI checks passing
- ✓ Breakage tests passing for dependent packages

### ❌ Missing (Issue #254 - Not Yet Implemented)
- ✗ `extract_solver_infos` generic function
- ✗ MadNLP extension
- ✗ Tests for new function
- ✗ Documentation
- ✗ Export in `src/CTModels.jl`
- ✗ MadNLP added to Project.toml weakdeps
- ✗ Extension registered in Project.toml

### 📝 Issue #254 Status Report
- ✅ Comprehensive analysis completed
- ✅ Report generated: `reports/issue-254-report.md`
- ✅ Function renamed: `SolverInfos` → `extract_solver_infos`
- ✅ File locations decided:
  - Code: `src/nlp/extract_solver_infos.jl`
  - Extension: `ext/CTModelsMadNLP.jl`
  - Tests: `test/nlp/test_extract_solver_infos.jl`

---

## 🧪 Test Status

**Overall**: ✅ All existing tests passing (31/31 CI checks)

**CI Checks**:
- ✅ Tests (Julia 1.10, 1.12 on Linux, macOS, Windows)
- ✅ Documentation build
- ✅ Coverage
- ✅ Breakage tests (CTDirect, CTFlows, OptimalControl)
- ✅ Spell check

**New Tests Needed**:
- ❌ Tests for `extract_solver_infos` generic method
- ❌ Tests for MadNLP extension
- ❌ Mock `SolverCore.AbstractExecutionStats` objects
- ❌ Test objective sign handling (minimize vs maximize)

---

## 📝 Review Feedback

**Reviews**: No reviews yet (PR just contains version bump)

**Unresolved comments**: None

---

## 🔧 Code Quality Assessment

**Current PR Quality**:
- ✅ Minimal, focused changes (version bump only)
- ✅ All CI passing
- ✅ No breaking changes to existing code

**Planned Work Quality Requirements**:
- ✅ Type annotations required (Julia best practice)
- ✅ Docstrings with examples required
- ✅ Comprehensive tests required
- ✅ Extension pattern (already established in CTModels)

---

## 📋 Proposed Action Plan

### 🔴 Critical Priority (blocking merge of Issue #254 work)

1. **Create `src/nlp/extract_solver_infos.jl`**
   - Why: Core functionality for Issue #254
   - Where: New file `src/nlp/extract_solver_infos.jl`
   - Estimated effort: Small (30 min)
   - Details:
     ````julia
     """
     $(TYPEDSIGNATURES)
     
     Retrieve convergence information from an NLP solution.
     
     # Arguments
     - `nlp_solution`: A solver execution statistics object.
     - `nlp`: The NLP model.
     
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
         nlp_solution::SolverCore.AbstractExecutionStats, 
         ::NLPModels.AbstractNLPModel
     )
         objective = nlp_solution.objective
         iterations = nlp_solution.iter
         constraints_violation = nlp_solution.primal_feas
         status = nlp_solution.status
         successful = (status == :first_order) || (status == :acceptable)
         return objective, iterations, constraints_violation, "Ipopt/generic", status, successful
     end
     ````

2. **Create `ext/CTModelsMadNLP.jl`**
   - Why: Handle MadNLP-specific behavior
   - Where: New file `ext/CTModelsMadNLP.jl`
   - Estimated effort: Small (20 min)
   - Details:
     ```julia
     module CTModelsMadNLP
     
     using CTModels
     using MadNLP
     using NLPModels
     
     function CTModels.extract_solver_infos(
         nlp_solution::MadNLP.MadNLPExecutionStats, 
         nlp::NLPModels.AbstractNLPModel
     )
         minimize = NLPModels.get_minimize(nlp)
         objective = minimize ? nlp_solution.objective : -nlp_solution.objective
         iterations = nlp_solution.iter
         constraints_violation = nlp_solution.primal_feas
         status = Symbol(nlp_solution.status)
         successful = (status == :SOLVE_SUCCEEDED) || (status == :SOLVED_TO_ACCEPTABLE_LEVEL)
         return objective, iterations, constraints_violation, "MadNLP", status, successful
     end
     
     end
     ```

3. **Update `Project.toml`**
   - Why: Register MadNLP extension
   - Where: `Project.toml`
   - Estimated effort: Small (5 min)
   - Details:
     - Add to `[weakdeps]`: `MadNLP = "2621e9c9-9eb4-46b1-8089-e8c72242dfb6"`
     - Add to `[extensions]`: `CTModelsMadNLP = "MadNLP"`

4. **Export function in `src/CTModels.jl`**
   - Why: Make function publicly available
   - Where: `src/CTModels.jl`
   - Estimated effort: Small (2 min)
   - Details: Add `extract_solver_infos` to exports

5. **Include new file in module**
   - Why: Load the new function
   - Where: `src/CTModels.jl`
   - Estimated effort: Small (2 min)
   - Details: Add `include("nlp/extract_solver_infos.jl")`

### 🟡 High Priority (should do before merge)

6. **Create comprehensive tests**
   - Why: Ensure correctness and prevent regressions
   - Where: New file `test/nlp/test_extract_solver_infos.jl`
   - Estimated effort: Medium (1 hour)
   - Details:
     - Mock `SolverCore.AbstractExecutionStats` objects
     - Test success cases (`:first_order`, `:acceptable`)
     - Test failure cases (other statuses)
     - Test MadNLP extension (if MadNLP available)
     - Test objective sign handling (minimize vs maximize)
     - Verify tuple structure and types

7. **Add test file to test suite**
   - Why: Ensure tests are run in CI
   - Where: `test/runtests.jl` or appropriate test runner
   - Estimated effort: Small (5 min)
   - Details: Include the new test file in the test suite

8. **Update documentation**
   - Why: Document new public API
   - Where: `docs/src/` (appropriate section)
   - Estimated effort: Small (20 min)
   - Details:
     - Add entry in API reference
     - Add usage example
     - Explain relationship with `SolverInfos` struct

### 🟢 Medium Priority (nice to have)

9. **Add inline comments**
   - Why: Explain design decisions
   - Where: `src/nlp/extract_solver_infos.jl`
   - Estimated effort: Small (10 min)
   - Details: Explain why tuple order differs from struct constructor

10. **Update CHANGELOG**
    - Why: Document breaking changes
    - Where: `CHANGELOG.md` (if exists)
    - Estimated effort: Small (5 min)
    - Details: Note new function in v0.7.1-beta

### 🔵 Low Priority (future work)

11. **Consider structured return type**
    - Why: Better type safety than 6-element tuple
    - Where: Future refactoring
    - Estimated effort: Medium
    - Details: Could create a `SolverResult` type, but defer to avoid scope creep

---

## 💡 Recommendations

**Immediate next steps**:
1. Handle uncommitted change in `src/ocp/solution.jl` (stash or commit)
2. Create the 5 Critical priority items in order
3. Run local tests to verify
4. Create the High priority items
5. Commit all changes with message: "feat: add extract_solver_infos function (Issue #254)"
6. Push to `breaking/ctmodels-0.7` branch
7. Update PR #248 description to mention Issue #254

**Before merging PR #248**:
- [ ] All Critical items completed
- [ ] All High Priority items completed
- [ ] Tests passing locally
- [ ] CI checks passing
- [ ] Documentation updated
- [ ] PR description updated

**After merge**:
- Create new beta release `v0.7.1-beta`
- Update CTDirect to use `CTModels.extract_solver_infos`

---

## ⏱️ Estimated Effort

**Critical items (1-5)**: ~1 hour  
**High priority items (6-8)**: ~1.5 hours  
**Medium priority items (9-10)**: ~15 minutes  

**Total to complete Critical + High**: ~2.5 hours  
**Total to complete all**: ~2.75 hours

---

## 📂 Files to Create/Modify

| File | Action | Lines | Notes |
|------|--------|-------|-------|
| `src/nlp/extract_solver_infos.jl` | CREATE | ~30 | Generic method |
| `ext/CTModelsMadNLP.jl` | CREATE | ~25 | MadNLP extension |
| `test/nlp/test_extract_solver_infos.jl` | CREATE | ~100 | Comprehensive tests |
| `Project.toml` | MODIFY | +2 | Add MadNLP weakdep + extension |
| `src/CTModels.jl` | MODIFY | +2 | Export + include |
| `test/runtests.jl` | MODIFY | +1 | Include new tests |
| `docs/src/nlp.md` | MODIFY | +20 | Documentation |

---

## 🎯 Success Criteria

✅ **Definition of Done**:
1. `extract_solver_infos` function implemented and exported
2. MadNLP extension working
3. All tests passing (existing + new)
4. CI checks green
5. Documentation updated
6. Code follows Julia best practices
7. Issue #254 can be closed

---

## 🚨 Risks & Mitigations

**Risk**: MadNLP extension might not load correctly
- **Mitigation**: Test with conditional loading, follow existing extension patterns

**Risk**: Tests might fail in CI due to MadNLP dependency
- **Mitigation**: Make MadNLP tests conditional on package availability

**Risk**: Breaking changes to CTDirect
- **Mitigation**: Breakage tests already passing, function is new (not changing existing)

---

**Next Step**: 🛑 **AWAITING YOUR VALIDATION**

Please review this plan and tell me:
1. ✅ Do you agree with the priorities?
2. ✅ Should I proceed with implementation?
3. ✅ Any changes to the plan?
4. ✅ Should I tackle all priorities or just Critical + High?
