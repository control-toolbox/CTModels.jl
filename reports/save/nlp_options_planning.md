# NLP Backends Options Planning

**Issue**: [#226 - NLP Options](https://github.com/control-toolbox/CTModels.jl/issues/226)  
**Date**: 2025-12-17  
**Status**: Planning Complete ✅

## TL;DR

Refine options for `ADNLPModeler` and `ExaModeler` to match their underlying backends strict sets. 
Enable `strict_keys=true` to catch invalid options. Improve error messages.

---

## 1. Analysis

### ADNLPModeler
Wraps `ADNLPModels.ADNLPModel`.
**Available Options**:
- `backend`: AD backend (already supported).
- `minimize`: Optimization direction (exclude, handled by OCP wrapping).
- `name`: Model name (default "Generic"). **Action**: Add.
- `show_time`: Custom CTModels option? (Keep).
- `y0`: Initial multipliers (advanced, maybe skip for now or add if requested).

**Proposed Options**: `backend`, `show_time`, `name`.

### ExaModeler
Wraps `ExaModels.ExaModel`.
**Available Options** (per Issue #196):
- `base_type`: Float type (supported).
- `backend`: Hardware backend (supported).
- `minimize`: Exclude (handled by OCP wrapping).

**Proposed Options**: `base_type`, `backend`.

---

## 2. Implementation Plan

### T1: Update `_option_specs`
**File**: `src/nlp/nlp_backends.jl`

**ADNLPModeler**:
```julia
(
    show_time=..., 
    backend=..., 
    name=OptionSpec(type=String, default="Generic", description="Model name.")
)
```

**ExaModeler**:
```julia
(
    base_type=..., 
    backend=... 
    # Remove minimize
)
```

### T2: Enable Strict Mode
Update constructors in `src/nlp/nlp_backends.jl` to use `strict_keys=true`.

### T3: Improve Error Message
**File**: `src/nlp/options_schema.jl`
Update `_unknown_option_error` to mention opening a discussion if the option is missing.

```julia
msg *= " ... Use show_options(...) ... If you believe this option should exist, please open a discussion at https://github.com/orgs/control-toolbox/discussions."
```

---

## 3. Verification

### Test Commands
```bash
# Check options list
julia --project=. -e 'using CTModels; show_options(ADNLPModeler); show_options(ExaModeler)'

# Test invalid option throws error with new message
julia --project=. -e 'using CTModels; try ADNLPModeler(foo=1) catch e; println(e); end'
```

---

## 4. Tasks

| Task | Description |
|------|-------------|
| T1 | Update `_option_specs` for `ADNLPModeler` (add `name`) and `ExaModeler` (remove `minimize`). |
| T2 | Enable `strict_keys=true` in `ADNLPModeler` and `ExaModeler` constructors. |
| T3 | Update `_unknown_option_error` in `src/nlp/options_schema.jl`. |
