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
| [`CTModels.Utils`](@ref) | Interpolation, matrix utilities, `@ensure` validation macro |
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
