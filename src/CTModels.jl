"""
    CTModels

Control Toolbox Models (CTModels) - A Julia package for optimal control problems.

This module provides a comprehensive framework for defining, building, and solving
optimal control problems with a modular architecture that separates concerns and
facilitates extensibility.

# Architecture Overview

CTModels is organized into specialized modules, each with clear responsibilities:

## Core Modules

- **OCP**: Optimal Control Problem core
  - Types: `Model`, `PreModel`, `Solution`, `AbstractModel`, `AbstractSolution`
  - Components: state, control, dynamics, objective, constraints
  - Builders: model construction and solution building
  - Type aliases: `Dimension`, `ctNumber`, `Time`, `Times`, `TimesDisc`, `ConstraintsDictType`

- **Utils**: General utilities
  - Interpolation: `ctinterpolate`
  - Matrix operations: `matrix2vec`
  - Macros: `@ensure` for validation

- **Display**: Formatting and visualization
  - Text display via `Base.show` extensions
  - Plotting stubs via `RecipesBase.plot`

- **Serialization**: Import/export functionality
  - `export_ocp_solution`, `import_ocp_solution`
  - Format tags: `JLD2Tag`, `JSON3Tag`

- **InitialGuess**: Initial guess management
  - `initial_guess`, `build_initial_guess`, `validate_initial_guess`
  - Types: `InitialGuess`, `PreInitialGuess`

## Supporting Modules

- **Options**: Configuration and options management
- **Strategies**: Strategy patterns for optimization
- **Orchestration**: High-level orchestration and coordination
- **Optimization**: General optimization types and builders
- **Modelers**: Modeler implementations (ADNLPModeler, ExaModeler)
- **DOCP**: Discretized Optimal Control Problem types

# Loading Order

Modules are loaded in dependency order to ensure all types and functions are available
when needed:

1. **Foundational types** → **Utils** → **OCP** → **Display/Serialization/InitialGuess**
2. **Supporting modules** → **Optimization** → **Modelers** → **DOCP**

# Public API

All exported functions and types are accessible via `CTModels.function_name()`.
The modular architecture ensures that:

- Types are defined where they belong
- Dependencies are explicit and minimal
- Extensions can target specific modules
- The public API remains stable and clean
"""
module CTModels

# Utils module - must load before OCP (uses @ensure macro)
include(joinpath(@__DIR__, "Utils", "Utils.jl"))
using .Utils
import .Utils: @ensure

# OCP module - core optimal control problem functionality
# Contains type aliases, types, components, builders, and compatibility aliases
include(joinpath(@__DIR__, "OCP", "OCP.jl"))
using .OCP

# Display and visualization
include(joinpath(@__DIR__, "Display", "Display.jl"))
using .Display

# Import and export plot and plot! from RecipesBase for public API
import RecipesBase: RecipesBase, plot, plot!
export plot, plot!

# Serialization (import/export)
include(joinpath(@__DIR__, "Serialization", "Serialization.jl"))
using .Serialization

# Initial guess management
include(joinpath(@__DIR__, "Init", "Init.jl"))
using .Init

end
