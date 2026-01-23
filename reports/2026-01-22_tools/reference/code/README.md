# Code Annexes - Implementation Reference

This directory contains the detailed implementation code for the three-module architecture described in [13_module_dependencies_architecture.md](../13_module_dependencies_architecture.md).

## Purpose

These code files serve as **implementation references** for developers who need to understand the detailed implementation of each module. The main architecture document focuses on high-level concepts and module responsibilities, while these annexes provide the actual code implementations.

## Structure

The code is organized by module:

### Options Module

Generic option extraction, validation, and aliasing with no external dependencies.

- [`option_value.jl`](Options/option_value.jl) - `OptionValue` type definition
- [`option_schema.jl`](Options/option_schema.jl) - `OptionSchema` type definition
- [`extraction.jl`](Options/extraction.jl) - Option extraction functions

### Strategies Module

Strategy registration, construction, and metadata management. Depends on Options.

- [`abstract_strategy.jl`](Strategies/abstract_strategy.jl) - `AbstractStrategy` contract
- [`metadata.jl`](Strategies/metadata.jl) - Metadata types and functions
- [`registry.jl`](Strategies/registry.jl) - Registry implementation
- [`builders.jl`](Strategies/builders.jl) - Strategy builder functions

### Orchestration Module

Orchestration of actions, routing, and multi-mode dispatch. Depends on Options and Strategies.

- [`routing.jl`](Orchestration/routing.jl) - Option routing logic
- [`method_builders.jl`](Orchestration/method_builders.jl) - Method-based strategy builders

## Usage

These files are **not meant to be executed directly**. They are reference implementations that should be:

1. **Studied** to understand the architecture
2. **Adapted** when implementing the actual modules in `CTModels.jl`
3. **Referenced** when writing tests or documentation

## Key Principles

1. **Options** provides generic tools with no knowledge of strategies
2. **Strategies** manages strategy-specific logic using Options tools
3. **Orchestration** coordinates everything, using both Options and Strategies

## See Also

- [13_module_dependencies_architecture.md](../13_module_dependencies_architecture.md) - Main architecture document
- [solve_ideal.jl](../../solve_ideal.jl) - Complete example showing all three modules in action
- [11_explicit_registry_architecture.md](../11_explicit_registry_architecture.md) - Registry design details
