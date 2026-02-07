# Documentation Organization

**Date**: 2026-01-23  
**Purpose**: Organize documentation into reference (implementation) vs analysis (working) documents

---

## Directory Structure

```
reports/2026-01-22_tools/
├── reference/          # Implementation-critical documents
│   └── (Final architecture, contracts, specifications)
└── analysis/           # Working documents, explorations, decisions
    └── (Analysis, comparisons, decision logs)
```

---

## Reference Documents (Implementation-Critical)

**Purpose**: Documents needed to implement the architecture

1. **08_complete_contract_specification.md**
   - Strategy contract (symbol, options, metadata)
   - Required for implementing strategies

2. **11_explicit_registry_architecture.md**
   - Registry design (create_registry, explicit passing)
   - Function signatures with registry parameter
   - Required for Strategies module

3. **13_module_dependencies_architecture.md**
   - 3-module architecture (Options → Strategies → Orchestration)
   - Module responsibilities and dependencies
   - Required for overall structure

4. **solve_ideal.jl**
   - Reference implementation showing final architecture
   - Demonstrates 3 modes, routing, orchestration
   - Template for implementation

---

## Analysis Documents (Working/Exploratory)

**Purpose**: Decision-making process, comparisons, explorations

1. **00_documentation_update_plan.md**
   - Update plan for explicit registry change
   - Historical/process document

2. **01_ocptools_restructuring_analysis.md**
   - Initial analysis of current implementation
   - Background context

3. **02_ocptools_contract_design.md**
   - Contract design exploration
   - Led to document 08

4. **03_api_and_interface_naming.md**
   - Naming conventions analysis
   - Design decisions

5. **04_function_naming_reference.md**
   - Function naming reference
   - Design decisions

6. **05_design_decisions_summary.md**
   - Summary of design decisions
   - Historical record

7. **06_registration_system_analysis.md**
   - Registration system analysis (superseded)
   - Historical

8. **07_registration_final_design.md**
   - Registration design (superseded by 11)
   - Historical

9. **09_method_based_functions_simplification.md**
   - Method-based functions design
   - Part of Strategies module design

10. **10_option_routing_complete_analysis.md**
    - Option routing analysis
    - Led to route_all_options design

11. **12_action_pattern_analysis.md**
    - Action pattern exploration
    - Led to 3-module architecture

12. **14_action_genericity_analysis.md**
    - Genericity analysis (what can/cannot be generic)
    - Important design clarification

13. **15_renaming_summary.md**
    - Renaming log (Actions → Orchestration)
    - Historical/process

14. **solve.jl**
    - Current implementation (for comparison)
    - Reference for what to replace

15. **solve_simplified.jl**
    - Intermediate simplification
    - Exploration step toward solve_ideal.jl

---

## Proposed Organization

### Move to `reference/`

- ✅ 08_complete_contract_specification.md
- ✅ 11_explicit_registry_architecture.md
- ✅ 13_module_dependencies_architecture.md
- ✅ solve_ideal.jl

### Move to `analysis/`

- ✅ 00_documentation_update_plan.md
- ✅ 01_ocptools_restructuring_analysis.md
- ✅ 02_ocptools_contract_design.md
- ✅ 03_api_and_interface_naming.md
- ✅ 04_function_naming_reference.md
- ✅ 05_design_decisions_summary.md
- ✅ 06_registration_system_analysis.md
- ✅ 07_registration_final_design.md
- ✅ 09_method_based_functions_simplification.md
- ✅ 10_option_routing_complete_analysis.md
- ✅ 12_action_pattern_analysis.md
- ✅ 14_action_genericity_analysis.md
- ✅ 15_renaming_summary.md
- ✅ solve.jl
- ✅ solve_simplified.jl

---

## README for Each Directory

### reference/README.md

```markdown
# Reference Documentation

Implementation-critical documents for the Strategies architecture.

## Core Documents

1. **08_complete_contract_specification.md** - Strategy contract
2. **11_explicit_registry_architecture.md** - Registry design
3. **13_module_dependencies_architecture.md** - 3-module architecture
4. **solve_ideal.jl** - Reference implementation

Start with 13 for overview, then 11 for registry, then 08 for contract.
```

### analysis/README.md

```markdown
# Analysis Documentation

Working documents showing the decision-making process and explorations.

These documents provide context and rationale but are not required for implementation.
See `../reference/` for implementation-critical documents.
```
