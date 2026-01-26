"""
    OCP

Optimal Control Problem module for CTModels.

This module provides the core types and functions for defining, building, and
manipulating optimal control problems and their solutions.

# Organization

The OCP module is organized into subdirectories by responsibility:

- **Types/**: Core type definitions (Model, Solution, Components)
- **Components/**: Component manipulation functions (state, control, dynamics, etc.)
- **Building/**: Model and solution construction functions
- **Core/**: Basic utilities and defaults

# Public API

The main exported types and functions are accessible via `CTModels.function_name()`:

- `Model`, `PreModel`, `AbstractModel`
- `Solution`, `AbstractSolution`
- Component builders: `state!`, `control!`, `variable!`, etc.
- Model builders: `build_model`, `build_solution`

See also: [`CTModels`](@ref)
"""
module OCP

using DocStringExtensions
using CTBase
using MLStyle: @match
using MacroTools
using Parameters

# Import types from parent module
import ..ctNumber, ..ctVector, ..Times, ..TimesDisc, ..Dimension, ..Time, ..ConstraintsDictType

# Import macro from Utils module
import ..Utils: @ensure

# Load types first (no dependencies)
include("Types/components.jl")
include("Types/model.jl")
include("Types/solution.jl")

# Load core utilities (depend on types)
include("Core/defaults.jl")
include("Core/time_dependence.jl")

# Load component functions (depend on types and core)
include("Components/state.jl")
include("Components/control.jl")
include("Components/variable.jl")
include("Components/times.jl")
include("Components/dynamics.jl")
include("Components/objective.jl")
include("Components/constraints.jl")

# Load builders (depend on types and components)
include("Building/definition.jl")
include("Building/dual_model.jl")
include("Building/model.jl")
include("Building/solution.jl")

# Export main API - Types
export Model, PreModel, AbstractModel
export Solution, AbstractSolution
export FixedTimeModel, FreeTimeModel, TimesModel
export StateModel, ControlModel, VariableModel
export MayerObjectiveModel, LagrangeObjectiveModel, BolzaObjectiveModel

# Export main API - Construction functions
export state!, control!, variable!
export time!, dynamics!, objective!, constraint!
export build_model, build_solution, build
export definition!, time_dependence!

# Export main API - Accessors
export constraint, name, dimension, components
export initial_time, final_time, time_name
export criterion, has_mayer_cost, has_lagrange_cost
export is_mayer_cost_defined, is_lagrange_cost_defined
export has_fixed_initial_time, has_free_initial_time
export has_fixed_final_time, has_free_final_time

# Compatibility aliases for CTSolvers
"""
Type alias for [`AbstractModel`](@ref).

Provides compatibility with CTSolvers naming conventions.
"""
const AbstractOptimalControlProblem = AbstractModel

"""
Type alias for [`AbstractSolution`](@ref).

Provides compatibility with CTSolvers naming conventions.
"""
const AbstractOptimalControlSolution = AbstractSolution

# Export aliases
export AbstractOptimalControlProblem, AbstractOptimalControlSolution

end
