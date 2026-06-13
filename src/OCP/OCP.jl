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

"""
module OCP

import CTBase.Core
import CTBase.Interpolation
import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import Parameters: @with_kw

using CTBase: CTBase
using MLStyle: MLStyle

# Components provides all foundational types and type aliases
using ..Components

# Models provides AbstractModel, Model and their accessors
using ..Models

# Building provides PreModel, all mutators, and build/build_model
using ..Building

# Import private helpers from Building so OCP.__ accessors remain valid for tests
# and for internal callers in solution.jl / Serialization (OCP.__format, etc.)
import ..Building:
    __is_set,
    __is_autonomous_set,
    __is_times_set,
    __is_state_set,
    __is_control_empty,
    __is_variable_empty,
    __is_definition_empty,
    __is_dynamics_set,
    __is_objective_set,
    __is_dynamics_complete,
    __is_consistent,
    __is_empty,
    __collect_used_names,
    __has_name_conflict,
    __validate_name_uniqueness,
    __constraint!,
    __build_dynamics_from_parts,
    __constraints,
    __format,
    __constraint_label,
    __control_name,
    __control_components,
    __criterion_type,
    __state_name,
    __state_components,
    __time_name,
    __variable_name,
    __variable_components,
    __filename_export_import,
    __control_interpolation,
    __time_grid_default_component

# Load types (Solution — PreModel/Model/AbstractModel come from ..Building/..Models)
include(joinpath(@__DIR__, "Types", "solution.jl"))

# Load builders (depend on types and components)
include(joinpath(@__DIR__, "Building", "dual_model.jl"))
include(joinpath(@__DIR__, "Building", "discretization_utils.jl"))
include(joinpath(@__DIR__, "Building", "interpolation_helpers.jl"))
include(joinpath(@__DIR__, "Building", "solution.jl"))

# Types defined in OCP (PreModel/Model/AbstractModel from ..Building/..Models;
# Component types from ..Components)
export Solution, AbstractSolution
export DualModel, AbstractDualModel
export SolverInfos, AbstractSolverInfos
export TimeGridModel, AbstractTimeGridModel, EmptyTimeGridModel
export UnifiedTimeGridModel, MultipleTimeGridModel

# Construction functions — Building exports: state!, control!, variable!, time!,
# dynamics!, objective!, constraint!, definition!, time_dependence!, build,
# build_model, append_box_constraints!, PreModel
export build_solution

# Accessors — solution and solver (Models/Components functions are extended, not re-exported)
export time_grid
export clean_component_symbols, time_grid_model
export control_interpolation
export dim_dual_state_constraints_box,
    dim_dual_control_constraints_box, dim_dual_variable_constraints_box
export costate
export dual
export iterations, status, message, success, successful
export constraints_violation, infos
export is_empty, is_empty_time_grid
export index
export model
# State/control/variable solution accessors (extend Models functions — no re-export)
# Dual constraints accessors
export path_constraints_dual, boundary_constraints_dual
export state_constraints_lb_dual, state_constraints_ub_dual
export control_constraints_lb_dual, control_constraints_ub_dual
export variable_constraints_lb_dual, variable_constraints_ub_dual

end
