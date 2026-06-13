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

# Load types (PreModel — Model/AbstractModel come from ..Models)
include(joinpath(@__DIR__, "Types", "model.jl"))
include(joinpath(@__DIR__, "Types", "solution.jl"))

# Load core utilities (depend on types)
include(joinpath(@__DIR__, "Core", "defaults.jl"))
include(joinpath(@__DIR__, "Core", "time_dependence.jl"))

# Load validation helpers (depend on types and core)
include(joinpath(@__DIR__, "Validation", "name_validation.jl"))

# Load component functions (depend on types, core, and validation)
include(joinpath(@__DIR__, "Components", "state.jl"))
include(joinpath(@__DIR__, "Components", "control.jl"))
include(joinpath(@__DIR__, "Components", "variable.jl"))
include(joinpath(@__DIR__, "Components", "times.jl"))
include(joinpath(@__DIR__, "Components", "dynamics.jl"))
include(joinpath(@__DIR__, "Components", "objective.jl"))
include(joinpath(@__DIR__, "Components", "constraints.jl"))
include(joinpath(@__DIR__, "Components", "definition.jl"))

# Load builders (depend on types and components)
include(joinpath(@__DIR__, "Building", "dual_model.jl"))
include(joinpath(@__DIR__, "Building", "discretization_utils.jl"))
include(joinpath(@__DIR__, "Building", "interpolation_helpers.jl"))
include(joinpath(@__DIR__, "Building", "model.jl"))
include(joinpath(@__DIR__, "Building", "solution.jl"))

# Types defined in OCP (Model/AbstractModel come from ..Models; Component types from ..Components)
export PreModel
export Solution, AbstractSolution
export DualModel, AbstractDualModel
export SolverInfos, AbstractSolverInfos
export TimeGridModel, AbstractTimeGridModel, EmptyTimeGridModel
export UnifiedTimeGridModel, MultipleTimeGridModel

# Construction functions
export state!, control!, variable!
export time!, dynamics!, objective!, constraint!
export build_solution, build, build_model
export definition!, time_dependence!
export append_box_constraints!

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
