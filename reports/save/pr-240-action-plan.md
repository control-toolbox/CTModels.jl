# 🎯 Action Plan: PR #240 - Dual Variables Dimension Clarification

**Date**: 2025-12-17  
**PR**: #240 by @ocots | **Branch**: `105-dev-dual-variables` → `main`  
**State**: DRAFT | **Linked Issue**: #105

---

## 📋 Overview

**Issue Summary**: Clarify dual variable semantics when multiple constraints are declared on the same state/control component. Question: should `state_constraints_ub_dual(t)` return dimension 3 (constraints count) or 2 (state dimension)?

**PR Summary**: Draft PR created as placeholder to link to issue #105. Currently contains only a trivial newline change. Real implementation not yet started.

**Status**: Draft / Needs full implementation

---

## 🔍 Project Context

**Project**: CTModels.jl v0.7.0 (Julia)  
**Current branch**: `105-dev-dual-variables`  
**CI Status**: ✅ All 21 checks passing

---

## 🎯 Gap Analysis

### ✅ Completed Requirements
*(None - implementation not started)*

### ❌ Missing Requirements (from Issue #105 planning report)

| Task | Description | Status |
|------|-------------|--------|
| T1 | Detect duplicate box constraints and emit warning | ❌ Not started |
| T2 | Document dual dimension semantics in docstrings | ❌ Not started |

### ➕ Additional Work Done
- PR created and linked to issue
- All CI checks passing

---

## 🧪 Test Status

**Overall**: ✅ All passing (no new changes to test)

**CI Checks**: 21/21 passing
- CI tests (Julia 1.10, 1.12): ✅
- Breakage tests (CTDirect, CTFlows, OptimalControl): ✅
- Documentation, SpellCheck, Formatter: ✅

**Local Tests**: Not run (no code changes)

---

## 📝 Review Feedback

**Reviews**: None  
**Comments**: 1 (github-actions bot - breakage test results)

---

## 🔧 Code Quality Assessment

**Current PR**: No substantive code changes to assess.

**Required Implementation** (from issue planning):
- `src/ocp/model.jl`: Add duplicate index detection in `append_box_constraints!`
- `src/ocp/solution.jl`: Update `build_solution` docstring

---

## 📋 Proposed Action Plan

### 🔴 Critical Priority (blocking merge)

1. **Implement T1: Duplicate constraint detection**
   - Why: Core feature requested in issue
   - Where: `src/ocp/model.jl` - `append_box_constraints!` or `build(constraints)`
   - Estimated effort: Small
   - Details: Detect when a component index is repeated in box constraints, emit `@warn`

2. **Implement T2: Document dual dimension semantics**
   - Why: Clarify API behavior
   - Where: `src/ocp/solution.jl` - docstring of `build_solution`
   - Estimated effort: Small
   - Details: Document that `state_constraints_*_dual` has dimension = state dimension

### 🟡 High Priority (should do before merge)

1. **Add unit tests for duplicate constraint warning**
   - Why: Verify warning is emitted
   - Where: `test/ocp/test_constraints.jl`
   - Estimated effort: Small

2. **Update PR with meaningful commit message**
   - Why: Current "foo" commit is placeholder
   - Where: Git history
   - Estimated effort: Trivial

### 🟢 Medium Priority (nice to have)

1. **Add documentation in user guide**
   - Why: Issue mentions updating tutorial docs
   - Where: `docs/` or external OptimalControl.jl tutorial
   - Estimated effort: Small

### 🔵 Low Priority (future work)

1. **Consider CTDirect/CTParser integration**
   - Why: Issue discussion mentions `parse_docp_dual` updates
   - Can be deferred to: Separate PR after this is merged

---

## 💡 Recommendations

**Immediate next steps**:
1. Implement duplicate constraint detection with warning (T1)
2. Update docstrings (T2)
3. Add test for warning emission
4. Squash/amend commit with proper message

**Before merging**:
- [ ] All Critical items resolved
- [ ] Tests passing
- [ ] CI checks passing *(currently ✅)*
- [ ] Reviews approved
- [ ] Documentation updated
- [ ] Remove Draft status

**After merge**:
- Update related packages (CTParser, CTDirect) if needed

---

## ⏱️ Estimated Effort

**To complete Critical + High**: ~1-2 hours  
**To complete all**: ~2-3 hours

---

## 📂 Changed Files Summary (Current PR)

| File | Changes | Notes |
|------|---------|-------|
| `src/CTModels.jl` | +1/-1 | Trivial newline change (placeholder) |

---

## 🔗 Key References

- **Issue #105 Planning Report**: [Comment by @ocots (Dec 16, 2025)](https://github.com/control-toolbox/CTModels.jl/issues/105#issuecomment-3662868255)
- **Decision**: Option A - Dual dimension = state dimension, with warning for duplicates
- **Files to modify**: `src/ocp/model.jl`, `src/ocp/solution.jl`

---

**Next Step**: Please review this plan and advise:
- Agree with priorities?
- Ready to start implementation?
- Any changes needed?
