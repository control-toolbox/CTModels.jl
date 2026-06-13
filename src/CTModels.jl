"""
    CTModels

Mathematical model layer for optimal control problems in the
[control-toolbox](https://github.com/control-toolbox) ecosystem.

Provides types and building blocks for states, controls, variables, time grids,
constraints, and cost functionals; structures for representing numerical solutions;
initial-guess management; and optional extensions for serialization and plotting.

# Modules

| Module | Responsibility |
|--------|---------------|
| [`CTModels.OCP`](@ref) | Types and builders for optimal control problems and solutions |
| [`CTModels.Display`](@ref) | `Base.show` extensions for models and solutions |
| [`CTModels.Serialization`](@ref) | `export_ocp_solution` / `import_ocp_solution` (JLD2, JSON) |
| [`CTModels.Init`](@ref) | Initial guess construction and validation |

# Extensions

| Extension | Trigger package | Adds |
|-----------|----------------|------|
| `CTModelsPlots` | `Plots.jl` | `Plots.plot(sol)` and `Plots.plot!(sol)` |
| `CTModelsJSON` | `JSON3.jl` | JSON serialization |
| `CTModelsJLD` | `JLD2.jl` | JLD2 serialization |

All public symbols are accessed as `CTModels.symbol` (no top-level exports).
"""
module CTModels

# Components — foundational types shared by all submodules
include(joinpath(@__DIR__, "Components", "Components.jl"))
using .Components

# Models — immutable Model type and its accessor methods
include(joinpath(@__DIR__, "Models", "Models.jl"))
using .Models

# Building — PreModel, all component mutators, build/build_model
include(joinpath(@__DIR__, "Building", "Building.jl"))
using .Building

# OCP module - core optimal control problem functionality
include(joinpath(@__DIR__, "OCP", "OCP.jl"))
using .OCP

# Display and visualization
include(joinpath(@__DIR__, "Display", "Display.jl"))
using .Display

# Serialization (import/export)
include(joinpath(@__DIR__, "Serialization", "Serialization.jl"))
using .Serialization

# Initial guess management
include(joinpath(@__DIR__, "Init", "Init.jl"))
using .Init

end
