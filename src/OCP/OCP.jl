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

# Components provides all foundational types and type aliases
using ..Components

# Models provides AbstractModel, Model and their accessors
using ..Models

# Building provides PreModel, all mutators, and build/build_model
using ..Building

# Solutions provides Solution types, build_solution, and all solution accessors
using ..Solutions

# Import private helpers from Building so OCP.__xxx remains valid for tests
# and for any remaining callers that qualify via OCP (e.g. OCP.__format).
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

# Import private helpers from Solutions so OCP._xxx accessors remain valid for tests.
import ..Solutions:
    _serialize_solution,
    _discretize_function,
    _discretize_dual,
    _extend_grid_to_match,
    _interpolate_from_data,
    _wrap_scalar_and_deepcopy,
    build_interpolated_function

end
