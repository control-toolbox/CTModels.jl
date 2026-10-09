"""
$(TYPEDSIGNATURES)

Normalize constraint labels to strings, mapping the unique labels generated for
unnamed constraints (`gensym(:unnamed)`, which differ from one model instance to
another) to the empty string.

# Arguments
- `labels`: Collection of constraint labels.

# Returns
- `Vector{String}`: The normalized labels.
"""
function _label_strings(labels)::Vector{String}
    return String[startswith(string(l), "##unnamed") ? "" : string(l) for l in labels]
end

"""
$(TYPEDSIGNATURES)

Return a plain-data description of the structure of a model, used to check, at import time,
that a serialized solution is compatible with the model it is rebuilt against.

The signature only contains values that can be stored as is in JLD2 and JSON files
(integers, booleans, strings, vectors of strings, floats or `nothing`). It never contains
functions: dynamics, costs and constraint functions are not compared.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dict{String,Any}`: The signature, with the keys:
  - dimensions: `dim_x`, `dim_u`, `dim_v`, `dim_path_nl`, `dim_boundary_nl`,
    `dim_state_box`, `dim_control_box`, `dim_variable_box`;
  - names: `state_name`, `state_components`, `control_name`, `control_components`,
    `variable_name`, `variable_components`, `time_name`, `initial_time_name`,
    `final_time_name`;
  - constraint labels: `labels_path_nl`, `labels_boundary_nl`, `labels_state_box`,
    `labels_control_box`, `labels_variable_box` (unnamed constraints have an empty label);
  - objective: `criterion`, `has_mayer`, `has_lagrange`;
  - times: `fixed_initial_time`, `fixed_final_time`, `initial_time`, `final_time`
    (the value is `nothing` when the time is free).

See also: [`CTModels.Serialization._validate_solution_against_model`](@extref).
"""
function _model_signature(ocp::Model)::Dict{String,Any}
    cons = constraints(ocp)
    tm = Components.times(ocp)
    obj = Components.objective(ocp)
    fixed0 = Components.has_fixed_initial_time(tm)
    fixedf = Components.has_fixed_final_time(tm)
    return Dict{String,Any}(
        "dim_x" => state_dimension(ocp),
        "dim_u" => control_dimension(ocp),
        "dim_v" => variable_dimension(ocp),
        "dim_path_nl" => Components.dim_path_constraints_nl(cons),
        "dim_boundary_nl" => Components.dim_boundary_constraints_nl(cons),
        "dim_state_box" => Components.dim_state_constraints_box(cons),
        "dim_control_box" => Components.dim_control_constraints_box(cons),
        "dim_variable_box" => Components.dim_variable_constraints_box(cons),
        "state_name" => state_name(ocp),
        "state_components" => String.(state_components(ocp)),
        "control_name" => control_name(ocp),
        "control_components" => String.(control_components(ocp)),
        "variable_name" => variable_name(ocp),
        "variable_components" => String.(variable_components(ocp)),
        "time_name" => Components.time_name(tm),
        "initial_time_name" => Components.initial_time_name(tm),
        "final_time_name" => Components.final_time_name(tm),
        "labels_path_nl" => _label_strings(Components.path_constraints_nl(cons)[4]),
        "labels_boundary_nl" => _label_strings(Components.boundary_constraints_nl(cons)[4]),
        "labels_state_box" => _label_strings(Components.state_constraints_box(cons)[4]),
        "labels_control_box" => _label_strings(Components.control_constraints_box(cons)[4]),
        "labels_variable_box" => _label_strings(
            Components.variable_constraints_box(cons)[4]
        ),
        "criterion" => string(Components.criterion(obj)),
        "has_mayer" => Components.has_mayer_cost(obj),
        "has_lagrange" => Components.has_lagrange_cost(obj),
        "fixed_initial_time" => fixed0,
        "fixed_final_time" => fixedf,
        "initial_time" => fixed0 ? Float64(Components.initial_time(tm)) : nothing,
        "final_time" => fixedf ? Float64(Components.final_time(tm)) : nothing,
    )
end
