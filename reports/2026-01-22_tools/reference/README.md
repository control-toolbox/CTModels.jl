# Reference Documentation

Implementation-critical documents for the Strategies architecture.

## Core Documents

1. **13_module_dependencies_architecture.md** - 3-module architecture overview
2. **11_explicit_registry_architecture.md** - Registry design and function signatures
3. **08_complete_contract_specification.md** - Strategy contract specification
4. **solve_ideal.jl** - Reference implementation example

## Reading Order

1. Start with **13** for the overall architecture (Options → Strategies → Orchestration)
2. Read **11** for registry design and how to pass it explicitly
3. Read **08** for the strategy contract (what every strategy must implement)
4. See **solve_ideal.jl** for a complete example

## Purpose

These documents are required to implement the new architecture. They define:
- Module structure and dependencies
- Registry creation and usage
- Strategy contract and interface
- Complete working example
