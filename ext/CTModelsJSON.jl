module CTModelsJSON

using CTModels
using DocStringExtensions

using JSON3

import CTModels.OCP: __control_interpolation

# ============================================================================
# Private helpers for JSON matrix conversion
# ============================================================================

# Liste des champs matriciels à convertir
const _MATRIX_FIELDS = ["state", "control", "costate"]
const _OPTIONAL_MATRIX_FIELDS = [
    "path_constraints_dual",
    "state_constraints_lb_dual",
    "state_constraints_ub_dual",
    "control_constraints_lb_dual",
    "control_constraints_ub_dual",
]

"""
Convert Matrix fields to Vector{Vector} for JSON3 export.

JSON3 flattens Matrix{Float64} into 1D arrays, losing the 2D structure.
This function converts all matrix fields to Vector{Vector} format to preserve dimensions.
"""
function _convert_matrices_for_json!(blob::Dict)
    # Convert required matrix fields
    for key in _MATRIX_FIELDS
        if haskey(blob, key) && blob[key] isa Matrix
            blob[key] = CTModels.Utils.matrix2vec(blob[key], 1)
        end
    end

    # Convert optional matrix fields (can be nothing)
    for key in _OPTIONAL_MATRIX_FIELDS
        if haskey(blob, key) && !isnothing(blob[key]) && blob[key] isa Matrix
            blob[key] = CTModels.Utils.matrix2vec(blob[key], 1)
        end
    end
end

# ============================================================================
# Private helper: broadcast with Nothing fallback
# ============================================================================

"""
Apply a function over a grid (broadcast), or return nothing if input is nothing.
"""
_apply_over_grid(f::Function, grid) = f.(grid)
_apply_over_grid(::Nothing, grid) = nothing

# ============================================================================
# Helper functions for serializing/deserializing infos Dict{Symbol,Any}
# ============================================================================

"""
Convert Dict{Symbol,Any} to Dict{String,Any} for JSON serialization.
Only serializes JSON-compatible types (numbers, strings, bools, arrays, dicts).
Returns a tuple: (serialized_dict, symbol_keys) where symbol_keys tracks which values were Symbols.
"""
function _serialize_infos(infos::Dict{Symbol,Any})::Tuple{Dict{String,Any},Vector{String}}
    result = Dict{String,Any}()
    symbol_keys = String[]
    for (k, v) in infos
        key_str = string(k)
        serialized_value, nested_symbols = _serialize_value(v, key_str)
        result[key_str] = serialized_value
        append!(symbol_keys, nested_symbols)
    end
    return (result, symbol_keys)
end

"""
Serialize a single value to JSON-compatible format.
Returns a tuple: (serialized_value, symbol_paths) where symbol_paths tracks Symbol locations.
"""
function _serialize_value(v, path::String="")
    if v isa Number || v isa String || v isa Bool || isnothing(v)
        return (v, String[])
    elseif v isa Symbol
        # Mark this path as containing a Symbol
        return (string(v), [path])
    elseif v isa AbstractVector
        serialized = []
        all_symbols = String[]
        for (i, x) in enumerate(v)
            val, syms = _serialize_value(x, "$(path)[$(i-1)]")
            push!(serialized, val)
            append!(all_symbols, syms)
        end
        return (serialized, all_symbols)
    elseif v isa AbstractDict
        result = Dict{String,Any}()
        all_symbols = String[]
        for (dk, dv) in v
            key_str = string(dk)
            new_path = isempty(path) ? key_str : "$(path).$(key_str)"
            val, syms = _serialize_value(dv, new_path)
            result[key_str] = val
            append!(all_symbols, syms)
        end
        return (result, all_symbols)
    else
        # For non-serializable types, convert to string representation
        return (string(v), String[])
    end
end

"""
Convert Dict{String,Any} back to Dict{Symbol,Any} after JSON deserialization.
Uses symbol_keys metadata to restore Symbol types where they were originally present.
"""
function _deserialize_infos(blob, symbol_keys::Vector{String}=String[])::Dict{Symbol,Any}
    if isnothing(blob) || isempty(blob)
        return Dict{Symbol,Any}()
    end
    result = Dict{Symbol,Any}()
    for (k, v) in blob
        result[Symbol(k)] = _deserialize_value(v, String(k), symbol_keys)
    end
    return result
end

"""
Deserialize a single value from JSON format.
Uses symbol_keys to restore Symbol types at the correct paths.
"""
function _deserialize_value(v, path::String, symbol_keys::Vector{String})
    if v isa Number || v isa Bool || isnothing(v)
        return v
    elseif v isa String
        # Check if this path should be a Symbol
        if path in symbol_keys
            return Symbol(v)
        else
            return v
        end
    elseif v isa AbstractVector
        return [
            _deserialize_value(x, "$(path)[$(i-1)]", symbol_keys) for (i, x) in enumerate(v)
        ]
    elseif v isa AbstractDict
        result = Dict{Symbol,Any}()
        for (dk, dv) in v
            key_str = string(dk)
            new_path = isempty(path) ? key_str : "$(path).$(key_str)"
            result[Symbol(dk)] = _deserialize_value(dv, new_path, symbol_keys)
        end
        return result
    else
        return v
    end
end

# ============================================================================
# Export function
# ============================================================================

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a `.json` file using the JSON3 format.

This function serializes a `CTModels.Solution` into a structured JSON dictionary,
including all primal and dual information, which can be read by external tools.

# Arguments
- `::CTModels.JSON3Tag`: A tag used to dispatch the export method for JSON3.
- `sol::CTModels.Solution`: The solution to be saved.

# Keyword Arguments
- `filename::String = "solution"`: Base filename. The `.json` extension is automatically appended.

# Notes
The exported JSON includes the time grid, state, control, costate, objective, solver info, and all constraint duals (if available).

# Example
```julia-repl
julia> using JSON3
julia> export_ocp_solution(JSON3Tag(), sol; filename="mysolution")
# → creates "mysolution.json"
```
"""
function CTModels.export_ocp_solution(
    ::CTModels.JSON3Tag, sol::CTModels.Solution; filename::String
)
    # Use unified serialization that handles both unified and multiple time grids
    blob = CTModels.OCP._serialize_solution(sol)

    # Convert Matrix → Vector{Vector} for JSON (to avoid JSON3 flattening)
    _convert_matrices_for_json!(blob)

    # Serialize infos and get Symbol type metadata
    infos_serialized, symbol_keys = _serialize_infos(blob["infos"])
    blob["infos"] = infos_serialized
    blob["infos_symbol_keys"] = symbol_keys

    open(filename * ".json", "w") do io
        JSON3.pretty(io, blob)
    end

    return nothing
end

"""
Convert a JSON field (Vector{Vector} via stack) to Matrix{Float64}.

JSON exports matrices as Vector{Vector}. After `stack(blob[field]; dims=1)`,
we get either a Matrix (multi-D) or Vector (1D). This normalizes to Matrix.

# Arguments
- `blob_field`: JSON array field (Vector of Vectors)

# Returns
- `Matrix{Float64}`: (n_time_points, n_dim)
"""
function _json_to_matrix(blob_field)::Matrix{Float64}
    stacked = stack(blob_field; dims=1)
    # 1D case: stack() returns Vector → reshape to (n, 1) Matrix
    # Multi-D case: stack() returns Matrix → use directly
    return stacked isa Vector ? reshape(stacked, :, 1) : Matrix{Float64}(stacked)
end

"""
Convert an optional JSON field to Matrix{Float64} or nothing.

# Arguments
- `blob_field`: JSON array field or nothing

# Returns
- `Matrix{Float64}` or `nothing`
"""
function _json_to_optional_matrix(blob_field)
    return isnothing(blob_field) ? nothing : _json_to_matrix(blob_field)
end

"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a `.json` file exported with `export_ocp_solution`.

This function reads the JSON contents and reconstructs a `CTModels.Solution` object,
including the discretized primal and dual trajectories.

# Arguments
- `::CTModels.JSON3Tag`: A tag used to dispatch the import method for JSON3.
- `ocp::CTModels.Model`: The model associated with the optimal control problem. Used to rebuild the full solution.

# Keyword Arguments
- `filename::String = "solution"`: Base filename. The `.json` extension is automatically appended.

# Returns
- `CTModels.Solution`: A reconstructed solution instance.

# Notes
Handles both vector and matrix encodings of signals. If dual fields are missing or `null`, the corresponding attributes are set to `nothing`.

# Example
```julia-repl
julia> using JSON3
julia> sol = import_ocp_solution(JSON3Tag(), model; filename="mysolution")
```
"""
function CTModels.import_ocp_solution(
    ::CTModels.JSON3Tag, ocp::CTModels.Model; filename::String
)
    json_string = read(filename * ".json", String)
    blob = JSON3.read(json_string)

    # Convert JSON arrays (Vector{Vector}) back to Matrix{Float64}
    X = _json_to_matrix(blob["state"])
    U = _json_to_matrix(blob["control"])
    P = _json_to_matrix(blob["costate"])

    # Convert optional dual matrices
    path_constraints_dual = _json_to_optional_matrix(blob["path_constraints_dual"])
    state_constraints_lb_dual = _json_to_optional_matrix(blob["state_constraints_lb_dual"])
    state_constraints_ub_dual = _json_to_optional_matrix(blob["state_constraints_ub_dual"])
    control_constraints_lb_dual = _json_to_optional_matrix(
        blob["control_constraints_lb_dual"]
    )
    control_constraints_ub_dual = _json_to_optional_matrix(
        blob["control_constraints_ub_dual"]
    )

    # get dual of boundary constraints: no conversion needed
    boundary_constraints_dual = blob["boundary_constraints_dual"]
    if !isnothing(boundary_constraints_dual)
        boundary_constraints_dual = Vector{Float64}(boundary_constraints_dual)
    end

    # get variable constraints dual: no conversion needed
    variable_constraints_lb_dual = blob["variable_constraints_lb_dual"]
    if !isnothing(variable_constraints_lb_dual)
        variable_constraints_lb_dual = Vector{Float64}(blob["variable_constraints_lb_dual"])
    end
    variable_constraints_ub_dual = blob["variable_constraints_ub_dual"]
    if !isnothing(variable_constraints_ub_dual)
        variable_constraints_ub_dual = Vector{Float64}(blob["variable_constraints_ub_dual"])
    end

    # get additional solver infos with Symbol type restoration
    symbol_keys_raw = get(blob, "infos_symbol_keys", String[])
    symbol_keys = collect(String, symbol_keys_raw)  # Convert JSON3.Array/empty array to Vector{String}
    infos = if haskey(blob, "infos")
        _deserialize_infos(blob["infos"], symbol_keys)
    else
        Dict{Symbol,Any}()
    end

    # Create data dictionary compatible with helper function
    data = Dict{String,Any}(
        "objective" => blob.objective,
        "iterations" => blob.iterations,
        "constraints_violation" => blob.constraints_violation,
        "message" => blob.message,
        "status" => blob.status,
        "successful" => blob.successful,
        "state" => X,
        "control" => U,
        "variable" => Vector{Float64}(blob.variable),
        "costate" => P,
        "path_constraints_dual" => path_constraints_dual,
        "boundary_constraints_dual" => boundary_constraints_dual,
        "state_constraints_lb_dual" => state_constraints_lb_dual,
        "state_constraints_ub_dual" => state_constraints_ub_dual,
        "control_constraints_lb_dual" => control_constraints_lb_dual,
        "control_constraints_ub_dual" => control_constraints_ub_dual,
        "variable_constraints_lb_dual" => variable_constraints_lb_dual,
        "variable_constraints_ub_dual" => variable_constraints_ub_dual,
        "control_interpolation" =>
            get(blob, "control_interpolation", string(__control_interpolation())),
    )

    # Add time grid data (format detection handled by helper)
    if haskey(blob, "time_grid_state")
        # Multiple time grids format
        data["time_grid_state"] = blob.time_grid_state
        data["time_grid_control"] = blob.time_grid_control
        # Support time_grid_costate (backward compatibility: if missing, will use T_state in reconstruction)
        if haskey(blob, "time_grid_costate")
            data["time_grid_costate"] = blob.time_grid_costate
        end
        # Support both new (time_grid_path) and legacy (time_grid_dual) keys
        if haskey(blob, "time_grid_path")
            data["time_grid_path"] = blob.time_grid_path
        elseif haskey(blob, "time_grid_dual")
            data["time_grid_path"] = blob.time_grid_dual
        end
    else
        # Legacy format: single time grid
        data["time_grid"] = blob.time_grid
    end

    # Reconstruct solution using helper function (handles both single and multiple time grids)
    return CTModels.Serialization._reconstruct_solution_from_data(
        ocp,
        data;
        path_constraints_dual=path_constraints_dual,
        boundary_constraints_dual=boundary_constraints_dual,
        state_constraints_lb_dual=state_constraints_lb_dual,
        state_constraints_ub_dual=state_constraints_ub_dual,
        control_constraints_lb_dual=control_constraints_lb_dual,
        control_constraints_ub_dual=control_constraints_ub_dual,
        variable_constraints_lb_dual=variable_constraints_lb_dual,
        variable_constraints_ub_dual=variable_constraints_ub_dual,
        infos=infos,
    )
end

end
