# Complete Work Analysis: Modelers & DOCP Migration

**Version**: 1.0  
**Date**: 2026-01-25  
**Status**: 📋 **Technical Implementation Guide**  
**Author**: CTModels Development Team

> **Document Purpose**: This is the **technical implementation guide** for developers. It provides detailed code-level instructions, pseudo-code, task breakdowns, and hour-by-hour estimates. For strategic overview and project objectives, see [`01_project_objective.md`](../reference/01_project_objective.md).

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Target Architecture](#target-architecture)
4. [Detailed Work Breakdown](#detailed-work-breakdown)
5. [Code Migration Map](#code-migration-map)
6. [Testing Strategy](#testing-strategy)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Risk Analysis](#risk-analysis)

---

## Executive Summary

This document provides comprehensive **technical implementation guidance** for migrating Modelers and DOCP from the legacy `AbstractOCPTool` system to the modern `AbstractStrategy` architecture.

### Document Scope

**This document contains**:
- Line-by-line code migration instructions
- Complete pseudo-code for new implementations
- Hour-by-hour task estimates
- Detailed testing specifications
- Technical risk analysis

**This document does NOT contain**:
- Strategic project justification (see project objective doc)
- High-level architecture vision (see project objective doc)
- Stakeholder communication (see project objective doc)

### Key Facts
- **Foundation**: Options/Strategies/Orchestration architecture is **100% complete** (649 tests)
- **Scope**: Migration of 2 Modelers + DOCP infrastructure
- **Breaking Changes**: Complete removal of `AbstractOCPTool` - no backward compatibility
- **Timeline**: Estimated 2-3 weeks for complete implementation

### Work Summary
- **New Code**: ~1500 lines (Modelers module + DOCP module)
- **Migrated Code**: ~600 lines from `src/nlp/`
- **Deleted Code**: ~800 lines (legacy `AbstractOCPTool` system)
- **Tests**: ~200 new tests required
- **Documentation**: 4 major doc updates + 2 new guides

---

## Current State Analysis

### 1. Completed Infrastructure

#### Options Module ✅
**Location**: [`src/Options/Options.jl`](../../../src/Options/Options.jl)

**Status**: 100% Complete (147 tests)

**Key Components**:
- `OptionValue`: Provenance tracking for option values
- `OptionDefinition`: Unified option schema with validation and aliases
- `extract_option()`, `extract_options()`: Alias-aware extraction

**No changes needed** - This module is production-ready.

#### Strategies Module ✅
**Location**: [`src/Strategies/Strategies.jl`](../../../src/Strategies/Strategies.jl)

**Status**: 100% Complete (~323 tests)

**Key Components**:
- `AbstractStrategy`: Base contract for all strategies
- `StrategyMetadata`: Type-stable metadata with `OptionDefinition`
- `StrategyOptions`: Type-stable option storage with provenance
- `StrategyRegistry`: Explicit registry for strategy families
- Complete introspection API
- Builder and configuration utilities

**No changes needed** - Ready for Modeler integration.

#### Orchestration Module ✅
**Location**: [`src/Orchestration/Orchestration.jl`](../../../src/Orchestration/Orchestration.jl)

**Status**: 100% Complete (79 tests)

**Key Components**:
- `route_all_options()`: Smart option routing with disambiguation
- `extract_strategy_ids()`: Strategy ID extraction from method tuples
- `build_strategy_from_method()`: Convenience builders
- `option_names_from_method()`: Option name collection

**No changes needed** - Ready for Modeler integration.

**Reference**: See [`solve_ideal.jl`](../../../reports/2026-01-22_tools/reference/solve_ideal.jl) for complete usage example.

---

### 2. Legacy Code to Migrate

#### AbstractOCPTool System ❌ TO DELETE
**Location**: [`src/nlp/types.jl:L5-L56`](../../../src/nlp/types.jl#L5-L56)

**Current Implementation**:
```julia
abstract type AbstractOCPTool end

struct OptionSpec
    type::Any
    default::Any
    description::Any
end
```

**Status**: **OBSOLETE** - Replaced by `AbstractStrategy` + `OptionDefinition`

**Action**: Complete removal in Phase 3

---

#### ADNLPModeler ⚠️ TO MIGRATE
**Location**: [`src/nlp/types.jl:L219-L222`](../../../src/nlp/types.jl#L219-L222)

**Current Implementation**:
```julia
struct ADNLPModeler{Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end
```

**Current Options** ([`src/nlp/nlp_backends.jl:L33-L46`](../../../src/nlp/nlp_backends.jl#L33-L46)):
- `show_time::Bool` (default: `false`)
- `backend::Symbol` (default: `:optimized`)

**Target**: `ADNLPModelerStrategy <: AbstractStrategy`

**Migration Complexity**: **Medium**
- Need to implement full `AbstractStrategy` contract
- Convert `_option_specs()` to `metadata()`
- Implement `id()` method
- Update constructor to use `build_strategy_options()`

---

#### ExaModeler ⚠️ TO MIGRATE
**Location**: [`src/nlp/types.jl:L246-L249`](../../../src/nlp/types.jl#L246-L249)

**Current Implementation**:
```julia
struct ExaModeler{BaseType<:AbstractFloat,Vals,Srcs} <: AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end
```

**Current Options** ([`src/nlp/nlp_backends.jl:L120-L138`](../../../src/nlp/nlp_backends.jl#L120-L138)):
- `base_type::Type{<:AbstractFloat}` (default: `Float64`)
- `minimize::Bool` (default: `missing`)
- `backend::Union{Nothing,KernelAbstractions.Backend}` (default: `nothing`)

**Target**: `ExaModelerStrategy <: AbstractStrategy`

**Migration Complexity**: **Medium-High**
- More complex type parameters (`BaseType`)
- Special handling of `base_type` option (type parameter vs option)
- Same strategy contract implementation as ADNLPModeler

---

#### Registration System ❌ TO DELETE
**Location**: [`src/nlp/nlp_backends.jl:L240-L301`](../../../src/nlp/nlp_backends.jl#L240-L301)

**Current Implementation**:
```julia
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)
registered_modeler_types() = REGISTERED_MODELERS
modeler_symbols() = ...
_modeler_type_from_symbol(sym::Symbol) = ...
build_modeler_from_symbol(sym::Symbol; kwargs...) = ...
```

**Status**: **OBSOLETE** - Replaced by `StrategyRegistry`

**Action**: Complete removal - Registry creation moves to `OptimalControl.jl`

**Reference**: See [`solve_ideal.jl:L34-L43`](../../../reports/2026-01-22_tools/reference/solve_ideal.jl#L34-L43) for new registry pattern.

---

#### DOCP Types ⚠️ TO MIGRATE
**Location**: [`src/nlp/types.jl:L330-L390`](../../../src/nlp/types.jl#L330-L390)

**Current Components**:
1. `OCPBackendBuilders{TM,TS}` - Container for model/solution builders
2. `DiscretizedOptimalControlProblem{TO,TB}` - Main DOCP type

**Target**: Move to new `src/docp/` module

**Migration Complexity**: **Low**
- Mostly structural move
- May need minor updates for strategy integration
- Keep existing constructors and interfaces

---

### 3. Supporting Infrastructure

#### Abstract Types Hierarchy
**Location**: [`src/nlp/types.jl:L68-L160`](../../../src/nlp/types.jl#L68-L160)

**Current Types**:
- `AbstractBuilder`
- `AbstractModelBuilder` → `ADNLPModelBuilder`, `ExaModelBuilder`
- `AbstractSolutionBuilder` → `AbstractOCPSolutionBuilder`
- `AbstractOptimizationProblem`
- `AbstractOptimizationModeler` ← **TO DELETE**

**Action**: 
- Keep builder types (needed by DOCP)
- Delete `AbstractOptimizationModeler` (replaced by `AbstractStrategy`)
- Move remaining types to appropriate modules

---

## Target Architecture

### New Module Structure

```
src/
├── Options/              ✅ Complete (no changes)
│   ├── Options.jl
│   ├── option_value.jl
│   ├── option_definition.jl
│   └── extraction.jl
│
├── Strategies/           ✅ Complete (no changes)
│   ├── Strategies.jl
│   ├── contract/
│   │   ├── abstract_strategy.jl
│   │   ├── metadata.jl
│   │   └── strategy_options.jl
│   └── api/
│       ├── registry.jl
│       ├── introspection.jl
│       ├── builders.jl
│       ├── configuration.jl
│       ├── utilities.jl
│       └── validation.jl
│
├── Orchestration/        ✅ Complete (no changes)
│   ├── Orchestration.jl
│   ├── disambiguation.jl
│   ├── routing.jl
│   └── method_builders.jl
│
├── Modelers/             🆕 TO CREATE
│   ├── Modelers.jl       # Module definition
│   ├── abstract_modeler.jl  # AbstractModeler <: AbstractStrategy
│   ├── adnlp_modeler.jl     # ADNLPModelerStrategy
│   ├── exa_modeler.jl       # ExaModelerStrategy
│   └── utilities.jl         # Helper functions
│
├── docp/                 🆕 TO CREATE
│   ├── docp.jl           # Module definition
│   ├── types.jl          # DOCP types
│   ├── builders.jl       # Builder types (moved from nlp/)
│   └── constructors.jl   # DOCP constructors
│
└── nlp/                  ❌ TO DELETE (after migration)
    ├── types.jl          # Legacy types
    └── nlp_backends.jl   # Legacy backend code
```

---

## Detailed Work Breakdown

### Phase 1: Modelers Module Creation

#### Task 1.1: Create Module Structure
**Estimated Effort**: 2 hours

**Files to Create**:
1. `src/Modelers/Modelers.jl` - Module definition
2. `src/Modelers/abstract_modeler.jl` - Base type
3. `src/Modelers/adnlp_modeler.jl` - ADNLPModeler strategy
4. `src/Modelers/exa_modeler.jl` - ExaModeler strategy
5. `src/Modelers/utilities.jl` - Helper functions

**Module Definition** (`Modelers.jl`):
```julia
"""
Modeler strategies for CTModels.

This module provides strategy-based modelers that convert discretized
optimal control problems into NLP backend models.

Available Modelers:
- ADNLPModelerStrategy: Based on ADNLPModels.jl
- ExaModelerStrategy: Based on ExaModels.jl

All modelers implement the AbstractStrategy contract from the Strategies module.
"""
module Modelers

using CTBase: CTBase
using DocStringExtensions
using ..CTModels.Options
using ..CTModels.Strategies

# Include submodules
include(joinpath(@__DIR__, "abstract_modeler.jl"))
include(joinpath(@__DIR__, "adnlp_modeler.jl"))
include(joinpath(@__DIR__, "exa_modeler.jl"))
include(joinpath(@__DIR__, "utilities.jl"))

# Public API
export AbstractModeler
export ADNLPModelerStrategy, ExaModelerStrategy

end # module Modelers
```

---

#### Task 1.2: Implement AbstractModeler
**Estimated Effort**: 1 hour

**File**: `src/Modelers/abstract_modeler.jl`

**Content**:
```julia
"""
$(TYPEDEF)

Abstract base type for modeler strategies.

Modelers convert discretized optimal control problems into NLP backend models
and map NLP solutions back to OCP solutions.

All modelers must implement:
- `id(::Type{<:AbstractModeler})` - Unique strategy identifier
- `metadata(::Type{<:AbstractModeler})` - Option metadata
- Constructor with keyword arguments
- Callable interface for model building
- Callable interface for solution building

See also: [`ADNLPModelerStrategy`](@ref), [`ExaModelerStrategy`](@ref).
"""
abstract type AbstractModeler <: Strategies.AbstractStrategy end

# Modelers are callable for model building
function (modeler::AbstractModeler)(
    prob::AbstractOptimizationProblem, 
    initial_guess
)
    throw(CTBase.NotImplemented(
        "Model building not implemented for $(typeof(modeler))"
    ))
end

# Modelers are callable for solution building
function (modeler::AbstractModeler)(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    throw(CTBase.NotImplemented(
        "Solution building not implemented for $(typeof(modeler))"
    ))
end
```

---

#### Task 1.3: Implement ADNLPModelerStrategy
**Estimated Effort**: 4 hours

**File**: `src/Modelers/adnlp_modeler.jl`

**Key Implementation Points**:
1. Define struct with `StrategyOptions` field
2. Implement `id()` → `:adnlp`
3. Implement `metadata()` with option definitions
4. Implement constructor using `build_strategy_options()`
5. Implement callable interface for model building
6. Implement callable interface for solution building

**Pseudo-code**:
```julia
struct ADNLPModelerStrategy <: AbstractModeler
    options::Strategies.StrategyOptions
end

# Type-level contract
Strategies.id(::Type{<:ADNLPModelerStrategy}) = :adnlp

function Strategies.metadata(::Type{<:ADNLPModelerStrategy})
    return Strategies.StrategyMetadata(
        specs = (
            show_time = Options.OptionDefinition(
                :show_time, Bool, false, (),
                "Whether to show timing information"
            ),
            backend = Options.OptionDefinition(
                :backend, Symbol, :optimized, (),
                "AD backend for ADNLPModels"
            ),
        ),
        family = AbstractModeler,
        description = "Modeler based on ADNLPModels.jl",
        package_name = "ADNLPModels"
    )
end

# Constructor
function ADNLPModelerStrategy(; kwargs...)
    opts = Strategies.build_strategy_options(
        ADNLPModelerStrategy; kwargs...
    )
    return ADNLPModelerStrategy(opts)
end

# Instance-level contract
Strategies.options(m::ADNLPModelerStrategy) = m.options

# Callable interface (model building)
function (modeler::ADNLPModelerStrategy)(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ADNLPModels.ADNLPModel
    opts = Strategies.options(modeler)
    show_time = Strategies.option_value(opts, :show_time)
    backend = Strategies.option_value(opts, :backend)
    
    builder = get_adnlp_model_builder(prob)
    return builder(initial_guess; show_time=show_time, backend=backend)
end

# Callable interface (solution building)
function (modeler::ADNLPModelerStrategy)(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    builder = get_adnlp_solution_builder(prob)
    return builder(nlp_solution)
end
```

---

#### Task 1.4: Implement ExaModelerStrategy
**Estimated Effort**: 5 hours

**File**: `src/Modelers/exa_modeler.jl`

**Key Implementation Points**:
1. Handle `BaseType` parameter (similar to current implementation)
2. Define struct with type parameter + `StrategyOptions`
3. Implement full strategy contract
4. Special handling of `base_type` option

**Pseudo-code**:
```julia
struct ExaModelerStrategy{BaseType<:AbstractFloat} <: AbstractModeler
    options::Strategies.StrategyOptions
end

# Type-level contract
Strategies.id(::Type{<:ExaModelerStrategy}) = :exa

function Strategies.metadata(::Type{<:ExaModelerStrategy})
    return Strategies.StrategyMetadata(
        specs = (
            base_type = Options.OptionDefinition(
                :base_type, Type{<:AbstractFloat}, Float64, (),
                "Floating-point type for ExaModels"
            ),
            minimize = Options.OptionDefinition(
                :minimize, Bool, missing, (),
                "Whether to minimize (true) or maximize (false)"
            ),
            backend = Options.OptionDefinition(
                :backend, Union{Nothing,KernelAbstractions.Backend}, nothing, (),
                "Execution backend (CPU, GPU, etc.)"
            ),
        ),
        family = AbstractModeler,
        description = "Modeler based on ExaModels.jl",
        package_name = "ExaModels"
    )
end

# Constructor
function ExaModelerStrategy(; kwargs...)
    opts = Strategies.build_strategy_options(
        ExaModelerStrategy; kwargs...
    )
    
    # Extract base_type for type parameter
    BaseType = Strategies.option_value(opts, :base_type)
    
    # Filter base_type from exposed options (it's in type parameter)
    filtered_opts = Strategies.filter_options(opts, (:base_type,))
    
    return ExaModelerStrategy{BaseType}(filtered_opts)
end

# Instance-level contract
Strategies.options(m::ExaModelerStrategy) = m.options

# Callable interface (model building)
function (modeler::ExaModelerStrategy{BaseType})(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ExaModels.ExaModel{BaseType} where {BaseType}
    opts = Strategies.options(modeler)
    backend = Strategies.option_value(opts, :backend)
    minimize = Strategies.option_value(opts, :minimize)
    
    builder = get_exa_model_builder(prob)
    return builder(BaseType, initial_guess; backend=backend, minimize=minimize)
end

# Callable interface (solution building)
function (modeler::ExaModelerStrategy)(
    prob::AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats
)
    builder = get_exa_solution_builder(prob)
    return builder(nlp_solution)
end
```

---

#### Task 1.5: Implement Utilities
**Estimated Effort**: 2 hours

**File**: `src/Modelers/utilities.jl`

**Functions to Implement**:
```julia
# Helper to get ADNLP model builder from DOCP
function get_adnlp_model_builder(prob::AbstractOptimizationProblem)
    # Extract from prob.backend_builders[:adnlp].model
end

# Helper to get ADNLP solution builder from DOCP
function get_adnlp_solution_builder(prob::AbstractOptimizationProblem)
    # Extract from prob.backend_builders[:adnlp].solution
end

# Helper to get Exa model builder from DOCP
function get_exa_model_builder(prob::AbstractOptimizationProblem)
    # Extract from prob.backend_builders[:exa].model
end

# Helper to get Exa solution builder from DOCP
function get_exa_solution_builder(prob::AbstractOptimizationProblem)
    # Extract from prob.backend_builders[:exa].solution
end
```

---

### Phase 2: DOCP Module Creation

#### Task 2.1: Create Module Structure
**Estimated Effort**: 1 hour

**Files to Create**:
1. `src/docp/docp.jl` - Module definition
2. `src/docp/types.jl` - DOCP types (migrated)
3. `src/docp/builders.jl` - Builder types (migrated)
4. `src/docp/constructors.jl` - DOCP constructors

**Module Definition** (`docp.jl`):
```julia
"""
Discretized Optimal Control Problem (DOCP) infrastructure.

This module provides types and utilities for representing discretized
optimal control problems ready for NLP solving.

Key Types:
- DiscretizedOptimalControlProblem: Main DOCP type
- OCPBackendBuilders: Container for model/solution builders
- Various builder types for different NLP backends
"""
module DOCP

using CTBase: CTBase
using DocStringExtensions

# Include submodules
include(joinpath(@__DIR__, "builders.jl"))
include(joinpath(@__DIR__, "types.jl"))
include(joinpath(@__DIR__, "constructors.jl"))

# Public API
export DiscretizedOptimalControlProblem, OCPBackendBuilders
export AbstractBuilder, AbstractModelBuilder, AbstractSolutionBuilder
export AbstractOCPSolutionBuilder
export ADNLPModelBuilder, ExaModelBuilder
export ADNLPSolutionBuilder, ExaSolutionBuilder

end # module DOCP
```

---

#### Task 2.2: Migrate Builder Types
**Estimated Effort**: 2 hours

**File**: `src/docp/builders.jl`

**Action**: Copy from [`src/nlp/types.jl:L68-L316`](../../../src/nlp/types.jl#L68-L316)

**Types to Migrate**:
- `AbstractBuilder`
- `AbstractModelBuilder`
- `ADNLPModelBuilder`
- `ExaModelBuilder`
- `AbstractSolutionBuilder`
- `AbstractOCPSolutionBuilder`
- `ADNLPSolutionBuilder`
- `ExaSolutionBuilder`

**Changes**: Minimal - mostly documentation updates

---

#### Task 2.3: Migrate DOCP Types
**Estimated Effort**: 2 hours

**File**: `src/docp/types.jl`

**Action**: Copy from [`src/nlp/types.jl:L330-L390`](../../../src/nlp/types.jl#L330-L390)

**Types to Migrate**:
- `OCPBackendBuilders`
- `DiscretizedOptimalControlProblem`

**Changes**: Update imports and documentation

---

#### Task 2.4: Create Constructors
**Estimated Effort**: 1 hour

**File**: `src/docp/constructors.jl`

**Action**: Extract constructor logic from types.jl

**Functions**:
- Various `DiscretizedOptimalControlProblem` constructors
- Helper functions for DOCP creation

---

### Phase 3: Integration & Testing

#### Task 3.1: Update Main Module
**Estimated Effort**: 2 hours

**File**: `src/CTModels.jl`

**Changes**:
1. Add `include("Modelers/Modelers.jl")`
2. Add `include("docp/docp.jl")`
3. Update exports
4. Add deprecation warnings for old types

**Example**:
```julia
# New modules
include("Modelers/Modelers.jl")
include("docp/docp.jl")

# Re-exports
using .Modelers
using .DOCP

export ADNLPModelerStrategy, ExaModelerStrategy
export DiscretizedOptimalControlProblem, OCPBackendBuilders

# Deprecations
@deprecate AbstractOCPTool "Use AbstractStrategy instead"
@deprecate ADNLPModeler ADNLPModelerStrategy
@deprecate ExaModeler ExaModelerStrategy
```

---

#### Task 3.2: Create Test Suite for Modelers
**Estimated Effort**: 8 hours

**Files to Create**:
1. `test/modelers/test_adnlp_modeler.jl` (~50 tests)
2. `test/modelers/test_exa_modeler.jl` (~50 tests)
3. `test/modelers/test_modeler_contract.jl` (~30 tests)
4. `test/modelers/test_integration.jl` (~20 tests)

**Test Categories**:
- Strategy contract compliance
- Option handling and validation
- Model building
- Solution building
- Error handling
- Integration with DOCP

---

#### Task 3.3: Create Test Suite for DOCP
**Estimated Effort**: 4 hours

**Files to Create**:
1. `test/docp/test_types.jl` (~30 tests)
2. `test/docp/test_builders.jl` (~20 tests)
3. `test/docp/test_constructors.jl` (~20 tests)

**Test Categories**:
- Type construction
- Builder functionality
- Constructor variants
- Integration with modelers

---

#### Task 3.4: Update Existing Tests
**Estimated Effort**: 4 hours

**Action**: Update tests that reference old types

**Files to Update**:
- All tests using `ADNLPModeler` → `ADNLPModelerStrategy`
- All tests using `ExaModeler` → `ExaModelerStrategy`
- All tests using `AbstractOCPTool` → `AbstractStrategy`

---

### Phase 4: Documentation

#### Task 4.1: Update API Documentation
**Estimated Effort**: 4 hours

**Files to Update**:
1. `docs/src/api/modelers.md` - New file
2. `docs/src/api/docp.md` - New file
3. Update existing API docs with deprecation notices

---

#### Task 4.2: Create Migration Guide
**Estimated Effort**: 3 hours

**File**: `docs/src/guides/modeler_migration.md`

**Content**:
- Overview of changes
- Side-by-side comparison (old vs new)
- Step-by-step migration instructions
- Common pitfalls and solutions

---

#### Task 4.3: Update Tutorials
**Estimated Effort**: 2 hours

**Files to Update**:
- Update any tutorials using old modeler syntax
- Add examples with new strategy-based modelers

---

### Phase 5: Cleanup

#### Task 5.1: Remove Legacy Code
**Estimated Effort**: 2 hours

**Action**: Delete obsolete files after migration is complete

**Files to Delete**:
- `src/nlp/types.jl` (after migration)
- `src/nlp/nlp_backends.jl` (after migration)
- Legacy option handling code

---

#### Task 5.2: Final Testing
**Estimated Effort**: 4 hours

**Action**: Comprehensive testing of entire system

**Tests**:
- All unit tests pass
- All integration tests pass
- Performance benchmarks (no regression)
- Documentation builds correctly

---

## Code Migration Map

### From `src/nlp/types.jl`

| Lines | Component | Target Location | Action |
|-------|-----------|-----------------|--------|
| 5-56 | `AbstractOCPTool`, `OptionSpec` | - | **DELETE** |
| 68-82 | `AbstractBuilder`, `AbstractModelBuilder` | `src/docp/builders.jl` | **MIGRATE** |
| 99-117 | `ADNLPModelBuilder`, `ExaModelBuilder` | `src/docp/builders.jl` | **MIGRATE** |
| 129-265 | `AbstractSolutionBuilder`, builders | `src/docp/builders.jl` | **MIGRATE** |
| 159-160 | `AbstractOptimizationModeler` | - | **DELETE** |
| 219-222 | `ADNLPModeler` | `src/Modelers/adnlp_modeler.jl` | **REWRITE** |
| 246-249 | `ExaModeler` | `src/Modelers/exa_modeler.jl` | **REWRITE** |
| 330-334 | `OCPBackendBuilders` | `src/docp/types.jl` | **MIGRATE** |
| 335-390 | `DiscretizedOptimalControlProblem` | `src/docp/types.jl` | **MIGRATE** |

### From `src/nlp/nlp_backends.jl`

| Lines | Component | Target Location | Action |
|-------|-----------|-----------------|--------|
| 15-24 | Default functions for ADNLPModeler | `src/Modelers/adnlp_modeler.jl` | **ADAPT** |
| 33-46 | `_option_specs(ADNLPModeler)` | `src/Modelers/adnlp_modeler.jl` | **REWRITE** as `metadata()` |
| 62-90 | ADNLPModeler constructor & methods | `src/Modelers/adnlp_modeler.jl` | **REWRITE** |
| 102-111 | Default functions for ExaModeler | `src/Modelers/exa_modeler.jl` | **ADAPT** |
| 120-138 | `_option_specs(ExaModeler)` | `src/Modelers/exa_modeler.jl` | **REWRITE** as `metadata()` |
| 155-193 | ExaModeler constructor & methods | `src/Modelers/exa_modeler.jl` | **REWRITE** |
| 206-234 | Symbol/package name functions | - | **DELETE** (use `id()` and `metadata()`) |
| 240-301 | Registration system | - | **DELETE** (use `StrategyRegistry`) |

---

## Testing Strategy

### Test Coverage Goals

| Module | Unit Tests | Integration Tests | Total | Coverage Target |
|--------|-----------|-------------------|-------|-----------------|
| Modelers | 130 | 20 | 150 | 100% |
| DOCP | 70 | 10 | 80 | 100% |
| **Total** | **200** | **30** | **230** | **100%** |

### Test Categories

#### 1. Strategy Contract Tests
**Purpose**: Verify full compliance with `AbstractStrategy` contract

**Tests for Each Modeler**:
- `id()` returns correct symbol
- `metadata()` returns valid `StrategyMetadata`
- Constructor accepts all documented options
- Constructor validates option types
- Constructor handles aliases correctly
- `options()` returns valid `StrategyOptions`
- All option introspection functions work

**Estimated**: 30 tests per modeler = 60 tests

---

#### 2. Option Handling Tests
**Purpose**: Verify option extraction, validation, and provenance

**Tests**:
- Default values applied correctly
- User values override defaults
- Invalid option types rejected
- Unknown options rejected (if strict)
- Option provenance tracked correctly
- Alias resolution works

**Estimated**: 20 tests per modeler = 40 tests

---

#### 3. Functional Tests
**Purpose**: Verify modeler functionality

**Tests**:
- Model building with valid inputs
- Solution building with valid inputs
- Error handling for invalid inputs
- Integration with DOCP types
- Backend-specific functionality

**Estimated**: 15 tests per modeler = 30 tests

---

#### 4. DOCP Tests
**Purpose**: Verify DOCP infrastructure

**Tests**:
- Type construction
- Builder extraction
- Constructor variants
- Integration with modelers

**Estimated**: 70 tests

---

#### 5. Integration Tests
**Purpose**: End-to-end testing

**Tests**:
- Full solve workflow with strategies
- Registry integration
- Orchestration integration
- Performance benchmarks

**Estimated**: 30 tests

---

## Implementation Roadmap

### Week 1: Foundation

#### Day 1-2: Modelers Module
- [ ] Create module structure
- [ ] Implement `AbstractModeler`
- [ ] Implement `ADNLPModelerStrategy` (basic)
- [ ] Write unit tests for ADNLPModeler

#### Day 3-4: ExaModeler & Utilities
- [ ] Implement `ExaModelerStrategy`
- [ ] Implement utility functions
- [ ] Write unit tests for ExaModeler
- [ ] Write contract compliance tests

#### Day 5: DOCP Module Start
- [ ] Create DOCP module structure
- [ ] Migrate builder types
- [ ] Write builder tests

---

### Week 2: Integration

#### Day 6-7: DOCP Completion
- [ ] Migrate DOCP types
- [ ] Create constructors
- [ ] Write DOCP tests
- [ ] Integration testing

#### Day 8-9: Main Module Integration
- [ ] Update `CTModels.jl`
- [ ] Add exports and deprecations
- [ ] Update existing tests
- [ ] Integration tests

#### Day 10: Testing & Fixes
- [ ] Run full test suite
- [ ] Fix any issues
- [ ] Performance benchmarks
- [ ] Code review

---

### Week 3: Documentation & Cleanup

#### Day 11-12: Documentation
- [ ] Write API documentation
- [ ] Create migration guide
- [ ] Update tutorials
- [ ] Update examples

#### Day 13-14: Cleanup
- [ ] Remove legacy code
- [ ] Final testing
- [ ] Code cleanup
- [ ] Prepare PR

#### Day 15: Review & Polish
- [ ] Final review
- [ ] Address feedback
- [ ] Merge preparation

---

## Risk Analysis

### High-Risk Items

#### 1. Type Parameter Handling (ExaModeler)
**Risk**: `BaseType` parameter may cause issues with strategy system

**Mitigation**:
- Careful design of type parameter handling
- Extensive testing with different base types
- Clear documentation of limitations

**Impact**: Medium - May require design adjustments

---

#### 2. Breaking Changes
**Risk**: Users may have code depending on old types

**Mitigation**:
- Clear deprecation warnings
- Comprehensive migration guide
- Examples of migration

**Impact**: High - User code will break

---

#### 3. Performance Regression
**Risk**: New strategy system may be slower

**Mitigation**:
- Performance benchmarks before/after
- Type-stability verification
- Optimization if needed

**Impact**: Medium - Could affect user experience

---

### Medium-Risk Items

#### 1. Test Coverage
**Risk**: Missing edge cases in tests

**Mitigation**:
- Systematic test planning
- Code coverage tools
- Review of test suite

**Impact**: Medium - Bugs in production

---

#### 2. Documentation Quality
**Risk**: Incomplete or unclear documentation

**Mitigation**:
- User review of docs
- Examples for all features
- Migration guide testing

**Impact**: Medium - User confusion

---

### Low-Risk Items

#### 1. Module Organization
**Risk**: Suboptimal module structure

**Mitigation**:
- Follow existing patterns
- Review by team
- Flexibility to adjust

**Impact**: Low - Can be refactored later

---

## Success Criteria

### Technical Metrics
- [ ] All 230 tests pass
- [ ] 100% code coverage for new code
- [ ] Zero performance regression (< 5% overhead)
- [ ] Type-stable critical paths
- [ ] Zero allocations in hot paths

### Quality Metrics
- [ ] Full strategy contract compliance
- [ ] Comprehensive documentation
- [ ] Clear migration guide
- [ ] All deprecations in place
- [ ] Clean code (no warnings)

### Integration Metrics
- [ ] Works with existing Options/Strategies/Orchestration
- [ ] Compatible with OptimalControl.jl patterns
- [ ] Registry integration functional
- [ ] Orchestration routing works

---

## Appendices

### A. Reference Documents

1. [Project Objectives](../reference/01_project_objective.md)
2. [Development Standards](../reference/00_development_standards_reference.md)
3. [Strategy Implementation Guide](../../../docs/src/interfaces/strategies.md)
4. [Strategy Family Creation](../../../docs/src/interfaces/strategy_families.md)
5. [Tools Architecture Report](../../../reports/2026-01-22_tools/todo/remaining_work_report.md)
6. [Solve Ideal Reference](../../../reports/2026-01-22_tools/reference/solve_ideal.jl)

### B. Key Code Locations

**Current (Legacy)**:
- [`src/nlp/types.jl`](../../../src/nlp/types.jl) - Legacy types
- [`src/nlp/nlp_backends.jl`](../../../src/nlp/nlp_backends.jl) - Legacy backends

**Foundation (Complete)**:
- [`src/Options/Options.jl`](../../../src/Options/Options.jl) - Options module
- [`src/Strategies/Strategies.jl`](../../../src/Strategies/Strategies.jl) - Strategies module
- [`src/Orchestration/Orchestration.jl`](../../../src/Orchestration/Orchestration.jl) - Orchestration module

**Target (To Create)**:
- `src/Modelers/` - New modelers module
- `src/docp/` - New DOCP module

---

**End of Analysis**
