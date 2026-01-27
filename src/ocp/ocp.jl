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
using OrderedCollections: OrderedDict

# Define type aliases (moved from src/types/aliases.jl)
include("aliases.jl")

# Import macro from Utils module
import ..Utils: @ensure

# Import build_solution from Optimization to overload it
import ..Optimization: build_solution

# Import matrix2vec and ctinterpolate from Utils for solution building
import ..Utils: matrix2vec, ctinterpolate

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

# Export type aliases
export Dimension, ctNumber, Time, ctVector, Times, TimesDisc, ConstraintsDictType

# Export main API - Types
export Model, PreModel, AbstractModel
export Solution, AbstractSolution
export FixedTimeModel, FreeTimeModel, TimesModel
export StateModel, ControlModel, VariableModel, EmptyVariableModel
export MayerObjectiveModel, LagrangeObjectiveModel, BolzaObjectiveModel
export DualModel, AbstractDualModel
export SolverInfos, AbstractSolverInfos
export TimeGridModel, AbstractTimeGridModel, EmptyTimeGridModel

# Export main API - Construction functions
export state!, control!, variable!
export time!, dynamics!, objective!, constraint!
export build_model, build_solution, build
export definition!, time_dependence!

# Export main API - Accessors
export constraint, constraints, name, dimension, components
export initial_time, final_time, time_name, time_grid, times
export initial_time_name, final_time_name
export criterion, has_mayer_cost, has_lagrange_cost
export is_mayer_cost_defined, is_lagrange_cost_defined
export has_fixed_initial_time, has_free_initial_time
export has_fixed_final_time, has_free_final_time
export is_autonomous
export is_initial_time_fixed, is_initial_time_free
export is_final_time_fixed, is_final_time_free
export state_dimension, control_dimension, variable_dimension
export state_name, control_name, variable_name
export state_components, control_components, variable_components
export state, control, variable, costate, objective
export dynamics, mayer, lagrange
export definition, dual
export iterations, status, message, success, successful
export constraints_violation, infos
export get_build_examodel
# Dual constraints accessors
export path_constraints_dual, boundary_constraints_dual
export state_constraints_lb_dual, state_constraints_ub_dual
export control_constraints_lb_dual, control_constraints_ub_dual
export variable_constraints_lb_dual, variable_constraints_ub_dual


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
