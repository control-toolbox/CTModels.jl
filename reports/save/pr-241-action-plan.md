# 🎯 Action Plan: PR #241 - Maintenance v0.17.2 Planning

**Date**: 2025-12-17  
**PR**: [#241](https://github.com/control-toolbox/CTModels.jl/pull/241) by @ocots | **Branch**: `239-general-compat-ctbase` → `main`  
**State**: OPEN | **Linked Issue**: [#239](https://github.com/control-toolbox/CTModels.jl/issues/239)

---

## 📋 Overview

**Issue Summary**: Align `CTModels.jl` infrastructure with `CTBase.jl` v0.17.2 conventions by refactoring the test runner to use `CTBase.run_tests`, updating documentation to use `DocumenterReference`, and enabling code coverage reporting.

**PR Summary**: Currently a placeholder PR with minimal changes (newline fix in `CTModels.jl`). The actual implementation work is not yet done.

**Status**: 🚧 Placeholder PR - Implementation needed

---

## 🔍 Project Context

**Project**: CTModels.jl (Julia)  
**Current branch**: `239-general-compat-ctbase`  
**CI Status**: ✅ All 21 checks passing

---

## 🎯 Gap Analysis

### ✅ Completed Requirements
_(None - PR is a placeholder)_

### ❌ Missing Requirements

| Requirement | Status | Evidence |
|-------------|--------|----------|
| T1.1: Create `test/coverage.jl` | ❌ Not implemented | File does not exist |
| T1.2: Refactor `test/runtests.jl` with `CTBase.run_tests` | ❌ Not implemented | Current file uses custom `OrderedDict` logic |
| T1.3: Verify all test groups run correctly | ⏳ Blocked | Depends on T1.2 |
| T2.1: Add `DocumenterReference.reset_config!()` in `docs/make.jl` | ❌ Not implemented | Not present in current file |
| T2.2: Set `remotes=nothing` in `makedocs` | ✅ Already done | Line 55 of `docs/make.jl` |
| T2.3: Verify documentation build locally | ⏳ Blocked | Depends on T2.1 |

### ➕ Current PR Content
- Newline fix at end of `src/CTModels.jl` (cosmetic change only)

---

## 🧪 Test Status

**Overall**: ✅ All passing (but no implementation done yet)

**CI Checks**: 21/21 passing
- CI tests: Julia 1.10 & 1.12 on Ubuntu, macOS, Windows
- Documentation build
- Breakage tests (CTDirect, CTFlows, OptimalControl)
- Spell check

**Local Tests**: Not yet run with new implementation

---

## 📝 Review Feedback

**Reviews**: No reviews yet  
**Unresolved comments**: None

---

## 🔧 Code Quality Assessment

**Current State**: PR is a placeholder, code quality assessment will be relevant after implementation.

**Existing Infrastructure**:
- `test/runtests.jl`: 206 lines, custom test runner with group selection
- `docs/make.jl`: 303 lines, uses `CTBase.automatic_reference_documentation`
- No `test/coverage.jl` exists

---

## 📋 Proposed Action Plan

### 🔴 Critical Priority (blocking merge)

1. **Create `test/coverage.jl`** (T1.1)
   - Why: Required for coverage reporting with CTBase v0.17.2
   - Where: `test/coverage.jl` [NEW]
   - Estimated effort: Small
   - Details: Standard CTBase coverage script using `CTBase.postprocess_coverage`

2. **Refactor `test/runtests.jl` to use `CTBase.run_tests`** (T1.2)
   - Why: Core requirement for ecosystem alignment
   - Where: `test/runtests.jl`
   - Estimated effort: Medium
   - Details: Replace custom `OrderedDict` logic with `CTBase.run_tests`, define `available_tests` tuple matching current test structure

3. **Add `DocumenterReference.reset_config!()` call** (T2.1)
   - Why: Required for proper local/remote link generation
   - Where: `docs/make.jl`
   - Estimated effort: Small
   - Details: Add explicit reset before `makedocs` call

### 🟡 High Priority (should do before merge)

4. **Verify all test groups run correctly** (T1.3)
   - Why: Ensure refactored test runner works
   - Where: CLI verification
   - Estimated effort: Small
   - Commands:
     ```bash
     julia --project=. -e 'using Pkg; Pkg.test("CTModels"; test_args=["core"])'
     julia --project=. -e 'using Pkg; Pkg.test("CTModels")'
     ```

5. **Verify documentation build locally** (T2.3)
   - Why: Confirm DocumenterReference integration works
   - Where: CLI verification
   - Estimated effort: Small
   - Command:
     ```bash
     julia --project=docs docs/make.jl
     ```

### 🟢 Medium Priority (nice to have)

6. **Create `docs/api_reference.jl`** (T2.4)
   - Why: Align with CTBase.jl structure, separate API generation from makedocs logic
   - Where: `docs/api_reference.jl` [NEW]
   - Estimated effort: Medium
   - Details: Extract API reference generation logic from `docs/make.jl` into dedicated file, following CTBase.jl pattern with `generate_api_reference()` function

7. **Run coverage analysis**
   - Why: Validate coverage reporting works
   - Where: CLI verification
   - Estimated effort: Small
   - Command:
     ```bash
     julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true); include("test/coverage.jl")'
     ```

### 🔵 Low Priority (future work)

_(None identified)_

---

## 💡 Recommendations

**Immediate next steps**:
1. Implement `test/coverage.jl`
2. Refactor `test/runtests.jl` using `CTBase.run_tests`
3. Add `DocumenterReference.reset_config!()` to `docs/make.jl`
4. Create `docs/api_reference.jl` (Medium priority)

**Before merging**:
- [ ] All Critical items resolved
- [ ] All High Priority items resolved
- [ ] Tests passing with new test runner
- [ ] CI checks passing
- [ ] Documentation builds locally
- [ ] Coverage reporting functional

**After merge**:
- Update CTBase version compatibility if needed
- Consider adding coverage badge to README
- Document the new `api_reference.jl` structure in CONTRIBUTING.md

---

## ⏱️ Estimated Effort

**To complete Critical + High**: ~2-3 hours  
**To complete all**: ~3-4 hours

---

## 📂 Changed Files Summary

| File | Changes | Notes |
|------|---------|-------|
| `src/CTModels.jl` | +1/-1 | Newline fix only (cosmetic) |

**Files to be modified**:

| File | Action | Description |
|------|--------|-------------|
| `test/coverage.jl` | [NEW] | Standard CTBase coverage script |
| `test/runtests.jl` | [MODIFY] | Refactor to use `CTBase.run_tests` |
| `docs/make.jl` | [MODIFY] | Add `DocumenterReference.reset_config!()`, import from `api_reference.jl` |
| `docs/api_reference.jl` | [NEW] | Extract API reference generation logic |
