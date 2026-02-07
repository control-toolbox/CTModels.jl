# Tools Architecture Enhancement Planning

**Issue**: N/A  
**Date**: 2026-01-23  
**Status**: Planning Complete ✅

## TL;DR

Refactor the current `AbstractOCPTool` and generic options schema into a clean, 3-module architecture: **Options** (generic tools), **Strategies** (strategy management), and **Orchestration** (routing and dispatch). This will eliminate global mutable state, improve testability, and provide a clear contract for future extensions in the Control-Toolbox ecosystem.

---

## 1. Overview

### Goal

Replace the legacy `AbstractOCPTool` system with a modern architecture that separates option handling, strategy management, and action orchestration.

### Key Features

- **Options Module**: Generic option value tracking with provenance, schema-based validation, and aliases.
- **Strategies Module**: Explicit registry for strategy families, builders from IDs/methods, and a formal `AbstractStrategy` contract.
- **Orchestration Module**: Intelligent routing of options (action-specific vs strategy-specific) and method-based dispatch.

### References

- [Reference Materials](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-22_tools/reference/README.md)
- [3-Module Architecture (Doc 13)](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-22_tools/reference/13_module_dependencies_architecture.md)
- [Registry Design (Doc 11)](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-22_tools/reference/11_explicit_registry_architecture.md)
- [Strategy Contract (Doc 08)](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-22_tools/reference/08_complete_contract_specification.md)
- [Reference Implementation (solve_ideal.jl)](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-22_tools/reference/solve_ideal.jl)

---

## 2. User Stories

| ID | Description | Status |
|----|-------------|--------|
| US-1 | As a developer, I want a clear contract for implementing new strategies. | ⏳ |
| US-2 | As an user, I want helpful error messages, suggestions, and **validators** (e.g., positive tolerance) for my options. | ⏳ |
| US-3 | As a maintainer, I want to avoid global mutable state for strategy registration. | ⏳ |
| US-4 | As a developer, I want to easily route options via **intensive simulation tests** (2 strategies, 2 labels, etc.). | ⏳ |

---

## 2.5. Design Principles Assessment

### SOLID Compliance

- ✅ **Single Responsibility**: Each module has one clear purpose (Options: tools, Strategies: registry, Orchestration: routing).
- ✅ **Open/Closed**: New strategies can be added by implementing the contract and registering them without modifying core modules.
- ✅ **Liskov Substitution**: All strategies inherit from `AbstractStrategy` and follow its contract.
- ✅ **Interface Segregation**: Minimal, focused interfaces for each module.
- ✅ **Dependency Inversion**: Dependencies flow from high-level (Orchestration) to low-level (Options).

### Quality Objectives (Priority: 1=Low, 5=Critical)

| Objective | Priority | Score | Measures |
|-----------|----------|-------|----------|
| Reusability | 5 | 5 | Generic Options module can be used beyond OCP. |
| Maintainability| 5 | 4 | Clear boundaries reduce coupling. |
| Performance | 3 | 4 | Registry lookups and option extraction are optimized. |
| Safety | 4 | 5 | Robust validation and helpful error messages. |

---

## 3. Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Registry | Explicit Registry | Avoids global state, better for testing and thread-safety. |
| Contract | `AbstractStrategy` | Formalizes the interface for all "tools". |
| Options | `OptionValue` | Tracks BOTH value and provenance. |
| Routing | Centralized in Orchestration| Decouples strategies from the knowledge of other strategies. |

---

## 4. Tasks

### Phase 1: Infrastructure (Options)

| Task | Description |
|------|-------------|
| 1.1 | Implement `Options` module with `OptionValue` and `OptionSchema`. |
| 1.2 | Implement `extract_option` and `extract_options` with alias support. |
| 1.3 | Add unit tests for `Options`. |

### Phase 2: Strategies

| Task | Description |
|------|-------------|
| 2.1 | Implement `Strategies` module with `AbstractStrategy` contract. |
| 2.2 | Implement `StrategyRegistry` and `create_registry`. |
| 2.3 | Implement strategy builders from IDs and methods. |
| 2.4 | Add unit tests for `Strategies`. |

### Phase 3: Orchestration

| Task | Description |
|------|-------------|
| 3.1 | Implement `Orchestration` module with `route_all_options`. |
| 3.2 | Implement method-based strategy builders. |
| 3.3 | Add unit tests for `Orchestration`. |

### Phase 4: NLP & Core Refactoring

| Task | Description |
|------|-------------|
| 4.1 | Update `ADNLPModeler` and `ExaModeler` to use the new contract. |
| 4.2 | Refactor `CTModels.jl` to include and export new modules. |
| 4.3 | Update existing integration tests. |

---

## 5. Testing Guidelines

### Test file structure

```julia
# test/Strategies/test_strategies.jl

# ============================================================
# Fake types for unit testing
# ============================================================
struct FakeStrategy <: CTModels.Strategies.AbstractStrategy
    options::CTModels.Strategies.StrategyOptions
end

# Implement contract...
CTModels.Strategies.symbol(::Type{FakeStrategy}) = :fake

function test_strategies()
    @testset "Strategies registry" begin
        # ...
    end
end
```

---

## 6. Test Commands

```bash
# Run CTModels tests
julia --project=. -e 'using Pkg; Pkg.test("CTModels");'
```

---

## 7. Coverage Testing

Target: **≥ 90% coverage** for the new code.

---

## 8. GitHub Workflow

### Checklist for Issue

- [ ] Phase 1: Options Module
- [ ] Phase 2: Strategies Module
- [ ] Phase 3: Orchestration Module
- [ ] Phase 4: Integration and Refactoring

---

## 9. MVP (Minimum Viable Product)

**MVP** = Phase 1 + Phase 2 + Phase 3 (Core infrastructure ready for use)
