# Project Objective: Modelers & DOCP Architecture Modernization

**Version**: 1.0  
**Date**: 2026-01-25  
**Status**: 🎯 **Project Charter - Strategic Reference**  
**Author**: CTModels Development Team

> **Document Purpose**: This is the **strategic reference document** for the Modelers & DOCP modernization project. It defines objectives, scope, architecture vision, and success criteria. For detailed technical implementation guidance, see [`01_complete_work_analysis.md`](../analyse/01_complete_work_analysis.md).

---

## Executive Summary

This project aims to modernize and restructure the **Modelers** and **Discretized Optimal Control Problem (DOCP)** components within CTModels.jl to align with the new **Options/Strategies/Orchestration** architecture. The initiative will migrate from the legacy `AbstractOCPTool` system to the modern `AbstractStrategy` contract, improving modularity, testability, and maintainability.

**Key Decision**: This is a **breaking change** project - no backward compatibility with `AbstractOCPTool` system.

## Project Context & Background

### Current State
- Legacy `AbstractOCPTool` system with hardcoded option handling ([`src/nlp/types.jl:L5-L56`](../../../src/nlp/types.jl#L5-L56))
- Modelers (`ADNLPModeler`, `ExaModeler`) tightly coupled to NLP backends ([`src/nlp/types.jl:L202-L250`](../../../src/nlp/types.jl#L202-L250))
- Monolithic `src/nlp` directory containing mixed concerns
- Manual option management without unified validation
- Hardcoded registration system ([`src/nlp/nlp_backends.jl:L240-L301`](../../../src/nlp/nlp_backends.jl#L240-L301))

### Target State
- Modern `AbstractStrategy`-based Modelers with unified option handling
- Clean separation of concerns across dedicated modules
- Comprehensive registry-based strategy management
- Enhanced documentation and testing coverage

### Architecture Foundation
This project builds upon the completed **Options/Strategies/Orchestration** architecture:

- **Options Module**: Generic option handling with provenance tracking ([`src/Options/Options.jl`](../../../src/Options/Options.jl))
- **Strategies Module**: Strategy management with registry system ([`src/Strategies/Strategies.jl`](../../../src/Strategies/Strategies.jl))
- **Orchestration Module**: High-level orchestration utilities ([`src/Orchestration/Orchestration.jl`](../../../src/Orchestration/Orchestration.jl))

**Reference Implementation**: See [`solve_ideal.jl`](../../../reports/2026-01-22_tools/reference/solve_ideal.jl) for the complete architecture example.

**Previous Work**: The Tools architecture is **100% complete** with 649 tests ([`remaining_work_report.md`](../../../reports/2026-01-22_tools/todo/remaining_work_report.md)).

## Scope & Objectives

### Primary Objectives

1. **Architecture Migration**
   - Convert Modelers from `AbstractOCPTool` to `AbstractStrategy` contract
   - Implement unified option handling through Options module
   - Establish strategy families for Modelers
   - **BREAKING CHANGE**: Complete removal of `AbstractOCPTool` system - no backward compatibility needed

2. **Code Restructuring**
   - Create dedicated `src/Modelers` module for strategy-based Modelers
   - Create dedicated `src/docp` module for DOCP components
   - **DEPRECATE**: Entire `src/nlp` directory structure
   - Clean separation of concerns across dedicated modules

3. **Documentation & Testing**
   - Update all documentation to reflect new architecture
   - Ensure comprehensive test coverage for new components
   - Provide migration guides for users (from legacy to new system)

### Out of Scope
- Maintaining backward compatibility with `AbstractOCPTool` system
- Modifications to external dependencies (OptimalControl.jl)
- Changes to existing NLP solver implementations

## Technical Architecture

### New Module Structure

```
src/
├── Modelers/           # Strategy-based Modelers
│   ├── Modelers.jl     # Module definition
│   ├── strategies/     # Individual Modeler strategies
│   ├── registry.jl     # Modeler registry management
│   └── builders.jl     # Modeler construction utilities
├── docp/               # DOCP components
│   ├── docp.jl         # Module definition
│   ├── types.jl        # DOCP type definitions
│   └── builders.jl     # DOCP construction utilities
└── nlp/                # Legacy NLP components (deprecated)
```

### Strategy Integration

- **Modelers as Strategies**: Each Modeler becomes an `AbstractStrategy` implementation
- **Option Unification**: All Modelers use the Options module for consistent handling
- **Registry Management**: Centralized strategy registry for Modeler discovery
- **Orchestration Support**: Seamless integration with existing Orchestration module

## Key Components

### 1. Modeler Strategy Family

**Target Components**:
- `ADNLPModeler` → `ADNLPModelerStrategy` ([`src/nlp/types.jl:L219-L222`](../../../src/nlp/types.jl#L219-L222))
- `ExaModeler` → `ExaModelerStrategy` ([`src/nlp/types.jl:L246-L249`](../../../src/nlp/types.jl#L246-L249))

**Strategy Contract Implementation**:
- Unique strategy identifiers
- Standardized option metadata
- Registry-based discovery
- Validation and error handling

**Documentation References**:
- [Strategy Implementation Guide](../../../docs/src/interfaces/strategies.md)
- [Strategy Family Creation](../../../docs/src/interfaces/strategy_families.md)
- [Strategy Tutorial](../../../docs/src/tutorials/creating_a_strategy.md)
- [Strategy Family Tutorial](../../../docs/src/tutorials/creating_a_strategy_family.md)

### 2. DOCP Module

**Core Components**:
- `DiscretizedOptimalControlProblem` type ([`src/nlp/types.jl:L335-L390`](../../../src/nlp/types.jl#L335-L390))
- `OCPBackendBuilders` utilities ([`src/nlp/types.jl:L330-L334`](../../../src/nlp/types.jl#L330-L334))
- DOCP construction and management
- Integration with Modeler strategies

### 3. Migration Path

**Phase 1**: Infrastructure Setup
- Create new module structure
- Implement strategy-based Modelers
- Establish registry framework

**Phase 2**: Integration & Testing
- Integrate with existing Orchestration
- Comprehensive testing suite
- Documentation updates

### Phase 3: Migration & Cleanup
- **REMOVE**: Complete deprecation of `AbstractOCPTool` system
- **DELETE**: Entire `src/nlp` directory after migration
- User migration guides (from legacy to new system)
- Code cleanup and optimization

## Success Criteria

### Technical Metrics
- [ ] 100% test coverage for new components
- [ ] Zero performance regression in benchmarks
- [ ] Complete documentation coverage
- [ ] Successful integration with existing OptimalControl.jl

### Quality Metrics
- [ ] Compliance with development standards
- [ ] Clean separation of concerns
- [ ] Backward compatibility preservation
- [ ] Positive user feedback on migration experience

## Risk Assessment

### High Risks
- **Breaking Changes**: Potential impact on existing user code
- **Performance Impact**: Strategy overhead in critical paths
- **Migration Complexity**: User migration challenges

### Mitigation Strategies
- **Deprecation Path**: Gradual migration with clear warnings
- **Performance Testing**: Comprehensive benchmarking
- **Documentation**: Detailed migration guides and examples

## Timeline & Milestones

**Total Duration**: 2-3 weeks

### High-Level Phases

1. **Week 1**: Modelers Module + DOCP Module
2. **Week 2**: Integration + Testing
3. **Week 3**: Documentation + Cleanup

> **Note**: For detailed day-by-day breakdown and task estimates, see [Implementation Roadmap](../analyse/01_complete_work_analysis.md#implementation-roadmap) in the technical analysis document.

## Deliverables

### Code Deliverables
- New `src/Modelers` module with strategy-based Modelers
- New `src/docp` module with DOCP components
- Updated integration tests
- Performance benchmarks

### Documentation Deliverables
- Updated API documentation
- Migration guide for users
- Architecture decision records
- Development standards updates

### Quality Assurance
- Comprehensive test suite
- Code coverage reports
- Performance benchmarks
- Integration test results

## Stakeholders

### Primary Stakeholders
- CTModels development team
- OptimalControl.jl maintainers
- Power users and contributors

### Secondary Stakeholders
- Academic researchers using CTModels
- Industry partners
- Julia optimization community

## Next Steps

1. **Immediate Actions**
   - Review and approve this project charter
   - Set up development environment
   - Begin Phase 1 implementation

2. **Short-term Goals** (Week 1)
   - Create module structure
   - Implement basic strategy contracts
   - Set up testing framework

3. **Long-term Goals** (Week 2-6)
   - Complete full implementation
   - Comprehensive testing
   - Documentation and migration guides

---

## Appendix

### Related Documents
- [Development Standards Reference](./00_development_standards_reference.md)
- [Previous Tools Architecture Report](../2026-01-22_tools/todo/remaining_work_report.md)
- [Strategy Implementation Guide](../../../docs/src/interfaces/strategies.md)
- [Strategy Family Creation](../../../docs/src/interfaces/strategy_families.md)
- [Strategy Tutorial](../../../docs/src/tutorials/creating_a_strategy.md)
- [Strategy Family Tutorial](../../../docs/src/tutorials/creating_a_strategy_family.md)

### References
- Options Module: [`src/Options/Options.jl`](../../../src/Options/Options.jl)
- Strategies Module: [`src/Strategies/Strategies.jl`](../../../src/Strategies/Strategies.jl)
- Orchestration Module: [`src/Orchestration/Orchestration.jl`](../../../src/Orchestration/Orchestration.jl)
- Legacy Types: [`src/nlp/types.jl`](../../../src/nlp/types.jl)
- Legacy Backends: [`src/nlp/nlp_backends.jl`](../../../src/nlp/nlp_backends.jl)
- Reference Implementation: [`solve_ideal.jl`](../../../reports/2026-01-22_tools/reference/solve_ideal.jl)

---

*This document serves as the authoritative project charter for the Modelers & DOCP Architecture Modernization initiative. All development decisions should reference this document to ensure alignment with project objectives.*
