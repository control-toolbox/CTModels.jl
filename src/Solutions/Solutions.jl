"""
    Solutions

Solutions module for CTModels — provides `Solution` and related types
(`TimeGridModel`, `DualModel`, `SolverInfos`), the `build_solution` constructor,
and all solution accessors (trajectories, duals, solver metadata).

# Organisation

- **solution_types.jl**: `Solution`, `AbstractSolution`, time-grid types, solver infos.
- **dual_model.jl**: `DualModel`, `AbstractDualModel`, and dual accessors.
- **discretization_utils.jl**: time-grid helpers used by `build_solution`.
- **interpolation_helpers.jl**: trajectory interpolation helpers.
- **build_solution.jl**: `build_solution` constructor + all solution accessors,
  `Base.show(::Solution)` (temporary — moves to Display in Phase E),
  `_serialize_solution` (temporary — moves to Serialization in Phase F).

# Public API

Exported types:
- `AbstractSolution`, `Solution`
- `AbstractTimeGridModel`, `UnifiedTimeGridModel`, `MultipleTimeGridModel`, `EmptyTimeGridModel`
- `AbstractDualModel`, `DualModel`
- `AbstractSolverInfos`, `SolverInfos`

Exported functions:
- `build_solution`: Main constructor for solutions
- `clean_component_symbols`: Clean and validate component symbols
- `is_empty`: Check if time grid is empty
- `time_grid_model`: Get time grid model from solution
- `dual`: Get dual by label
- `path_constraints_dual`, `boundary_constraints_dual`: Dual accessors
- `state_constraints_lb_dual`, `state_constraints_ub_dual`: State dual accessors
- `control_constraints_lb_dual`, `control_constraints_ub_dual`: Control dual accessors
- `variable_constraints_lb_dual`, `variable_constraints_ub_dual`: Variable dual accessors

# Dependencies

- CTBase: Core types and exceptions
- CTModels.Components: Model components
- CTModels.Models: Model types and accessors
- CTBase.Components: Time and state components
- Interpolations.jl: Trajectory interpolation
- LinearAlgebra: Vector operations

# See also

- [`CTModels.Models`](@ref): Model types and building
- [`CTModels.Components`](@ref): Model components
- [`CTModels.Building`](@ref): Model construction
- [`CTModels.Serialization`](@ref): Solution import/export
"""
module Solutions

import CTBase.Core
import CTBase.Interpolation
import CTBase.Exceptions
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using CTBase: CTBase

# Foundational types and type aliases
using ..Components

# Immutable Model type and its accessors
using ..Models

# Private defaults used by build_solution and its accessors
import ..Building:
    __constraints,
    __control_interpolation,
    __time_grid_default_component,
    __format,
    __filename_export_import

include(joinpath(@__DIR__, "solution_types.jl"))
include(joinpath(@__DIR__, "dual_functors.jl"))
include(joinpath(@__DIR__, "dual_model.jl"))
include(joinpath(@__DIR__, "discretization_utils.jl"))
include(joinpath(@__DIR__, "interpolation_helpers.jl"))
include(joinpath(@__DIR__, "build_solution.jl"))

# Solution types
export Solution, AbstractSolution
export DualModel, AbstractDualModel
export SolverInfos, AbstractSolverInfos
export TimeGridModel, AbstractTimeGridModel, EmptyTimeGridModel
export UnifiedTimeGridModel, MultipleTimeGridModel

# build_solution constructor
export build_solution

# Solution accessors — costate/time_grid owned by Components
export clean_component_symbols, time_grid_model
export control_interpolation
export dim_dual_state_constraints_box,
    dim_dual_control_constraints_box, dim_dual_variable_constraints_box
export dual
export iterations, status, message, success, successful
export constraints_violation, infos
export is_empty, is_empty_time_grid
export index
export model
export path_constraints_dual, boundary_constraints_dual
export state_constraints_lb_dual, state_constraints_ub_dual
export control_constraints_lb_dual, control_constraints_ub_dual
export variable_constraints_lb_dual, variable_constraints_ub_dual

end
