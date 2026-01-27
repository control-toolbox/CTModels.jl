# Documentation Update Summary - Explicit Registry Architecture

**Date**: 2026-01-22  
**Status**: Documentation Update Plan

---

## Architecture Decision Impact

**Decision**: Use **explicit registry** (passed as argument) instead of global mutable registry.

This impacts multiple documents that need updating:

---

## Documents to Update

### ✅ Already Updated

1. **11_explicit_registry_architecture.md** - NEW
   - Complete specification of explicit registry approach
   - All function signatures with registry parameter
   - Usage examples

2. **solve_simplified.jl** - UPDATED
   - Uses `create_registry()` instead of `register_family!()`
   - Passes `OCP_REGISTRY` to all functions

### ⚠️ Needs Update

3. **07_registration_final_design.md**
   - Currently describes global `GLOBAL_REGISTRY` approach
   - **Update needed**: Replace with explicit registry approach
   - Add note that this is superseded by 11_explicit_registry_architecture.md

4. **09_method_based_functions_simplification.md**
   - Function signatures don't include registry parameter
   - **Update needed**: Add registry parameter to all function signatures

5. **10_option_routing_complete_analysis.md**
   - `route_options()` signature doesn't include registry
   - **Update needed**: Add registry parameter to signature

### ℹ️ Minor Updates Needed

6. **05_design_decisions_summary.md**
   - Has section on registration but uses old approach
   - **Update needed**: Update registration section with explicit registry note

### ✓ No Update Needed

7. **01_ocptools_restructuring_analysis.md** - Analysis only, no implementation details
8. **02_ocptools_contract_design.md** - Contract doesn't change
9. **03_api_and_interface_naming.md** - Naming doesn't change
10. **04_function_naming_reference.md** - Function names don't change
11. **06_registration_system_analysis.md** - Analysis only, marked as superseded
12. **08_complete_contract_specification.md** - Contract doesn't change

---

## Update Plan

### Priority 1: Mark superseded documents

- [x] 06_registration_system_analysis.md - Already marked as superseded
- [ ] 07_registration_final_design.md - Mark as superseded, point to 11

### Priority 2: Update function signatures

- [ ] 09_method_based_functions_simplification.md - Add registry parameter
- [ ] 10_option_routing_complete_analysis.md - Add registry parameter

### Priority 3: Update summaries

- [ ] 05_design_decisions_summary.md - Update registration section

---

## Key Changes to Document

### Function Signatures (add `registry` parameter)

**Before**:
```julia
route_options(method, families, kwargs; source_mode=:description)
build_strategy_from_method(method, family; kwargs...)
extract_id_from_method(method, family)
```

**After**:
```julia
route_options(method, families, kwargs, registry; source_mode=:description)
build_strategy_from_method(method, family, registry; kwargs...)
extract_id_from_method(method, family, registry)
```

### Registry Creation (replace registration)

**Before**:
```julia
register_family!(AbstractOptimizationModeler, (ADNLPModeler, ExaModeler))
```

**After**:
```julia
const OCP_REGISTRY = create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler),
    ...
)
```

---

## Execution Order

1. Update 07_registration_final_design.md (mark superseded)
2. Update 09_method_based_functions_simplification.md (add registry param)
3. Update 10_option_routing_complete_analysis.md (add registry param)
4. Update 05_design_decisions_summary.md (update summary)
