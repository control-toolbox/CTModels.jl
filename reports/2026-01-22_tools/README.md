# Strategies Architecture Documentation

**Date**: 2026-01-22 to 2026-01-23  
**Status**: Design Complete

---

## Quick Start

**For implementation**, read documents in this order:

1. **[reference/13_module_dependencies_architecture.md](reference/13_module_dependencies_architecture.md)** - Overall architecture
2. **[reference/11_explicit_registry_architecture.md](reference/11_explicit_registry_architecture.md)** - Registry design
3. **[reference/08_complete_contract_specification.md](reference/08_complete_contract_specification.md)** - Strategy contract
4. **[reference/solve_ideal.jl](reference/solve_ideal.jl)** - Complete example

---

## Directory Structure

```
reports/2026-01-22_tools/
├── README.md              # This file
├── ORGANIZATION.md        # Detailed organization plan
├── reference/             # Implementation-critical documents (4 docs)
│   ├── README.md
│   ├── 08_complete_contract_specification.md
│   ├── 11_explicit_registry_architecture.md
│   ├── 13_module_dependencies_architecture.md
│   └── solve_ideal.jl
└── analysis/              # Working documents (15 docs)
    ├── README.md
    ├── 00-07_*.md        # Initial analysis and registration evolution
    ├── 09-10_*.md        # Routing and options design
    ├── 12-15_*.md        # Action pattern and genericity
    └── solve*.jl         # Implementation evolution
```

---

## Final Architecture

### 3-Module System

```
Options (generic option handling)
   ↑
Strategies (strategy management)
   ↑
Orchestration (action orchestration)
```

### Key Decisions

1. **Explicit Registry**: Registry passed as argument (not global mutable)
2. **Strategy Contract**: `symbol()`, `options()`, `metadata()`
3. **Orchestration**: Provides tools (routing, extraction), not magic dispatch
4. **3 Modes**: Standard, Description, Explicit

---

## Implementation Status

- [x] Architecture designed
- [x] Contracts specified
- [x] Registry design finalized
- [x] Reference implementation created
- [ ] Modules implementation (Options, Strategies, Orchestration)
- [ ] Migration of existing code
- [ ] Tests

---

## Reference Documents (4)

**Must-read for implementation**:

| Document | Purpose |
|----------|---------|
| 13_module_dependencies_architecture.md | 3-module architecture, dependencies, responsibilities |
| 11_explicit_registry_architecture.md | Registry creation, function signatures |
| 08_complete_contract_specification.md | Strategy contract (what to implement) |
| solve_ideal.jl | Complete working example |

---

## Analysis Documents (15)

**Context and decision-making process**:

- **Initial Analysis** (01-05): Restructuring, contract design, naming
- **Registration Evolution** (06-07, 00): Registration system design
- **Routing Design** (09-10): Method-based functions, option routing
- **Action Pattern** (12, 14-15): Action pattern, genericity, renaming
- **Implementation Evolution**: solve.jl → solve_simplified.jl → solve_ideal.jl

See [analysis/README.md](analysis/README.md) for details.

---

## Key Concepts

### Strategy

An implementation of `AbstractStrategy` with:
- Unique symbol (`:adnlp`, `:ipopt`, etc.)
- Options with defaults and sources
- Metadata (package name, description)

### Registry

Explicit mapping of families to strategy types:
```julia
registry = create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler),
    ...
)
```

### Orchestration

Coordinates strategies and options:
- Extracts action options
- Routes strategy options
- Builds strategies from method + options

---

## Next Steps

1. Implement Options module (generic option handling)
2. Implement Strategies module (registry, contract, builders)
3. Implement Orchestration module (routing, coordination)
4. Migrate OptimalControl.jl to use new architecture
5. Update documentation and examples

---

## Questions?

See [ORGANIZATION.md](ORGANIZATION.md) for detailed document categorization.
