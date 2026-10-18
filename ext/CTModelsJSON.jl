"""
Weak-dependency extension of CTModels providing JSON-based serialization.

Loaded automatically when both `CTModels` and `JSON` are available in the session.
Adds methods for [`CTModels.export_ocp_solution`](@extref) and
[`CTModels.import_ocp_solution`](@extref) dispatching on [`CTModels.JSONTag`](@extref).
"""
module CTModelsJSON

using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

using CTBase: Core
using CTModels: CTModels
using JSON: JSON

# ============================================================================
# Private helpers for JSON matrix conversion
# ============================================================================

"Solution fields that are always serialized as `Matrix{Float64}` and must be converted to `Vector{Vector}` for JSON."
const _MATRIX_FIELDS = ["state", "control", "costate"]

"Solution fields that may be present (non-empty duals) and require the same `Matrix → Vector{Vector}` conversion."
const _OPTIONAL_MATRIX_FIELDS = [
    "path_constraints_dual",
    "state_constraints_lb_dual",
    "state_constraints_ub_dual",
    "control_constraints_lb_dual",
    "control_constraints_ub_dual",
]

"Switching limits (present when the solution holds a switching structure), converted like the other matrices."
const _SWITCHING_MATRIX_FIELDS = [first(k) for k in CTModels.Solutions._SWITCHING_LIMIT_KEYS]

"""
Convert Matrix fields to Vector{Vector} for JSON export.

JSON writes a Matrix{Float64} as a flat 1D array, losing the 2D structure.
This function converts all matrix fields to Vector{Vector} format to preserve dimensions.
"""
function _convert_matrices_for_json!(blob::Dict)
    # Convert required matrix fields
    for key in _MATRIX_FIELDS
        if haskey(blob, key) && blob[key] isa Matrix
            blob[key] = Core.matrix2vec(blob[key], 1)
        end
    end

    # Convert optional matrix fields (can be nothing)
    for key in _OPTIONAL_MATRIX_FIELDS
        if haskey(blob, key) && !isnothing(blob[key]) && blob[key] isa Matrix
            blob[key] = Core.matrix2vec(blob[key], 1)
        end
    end

    # Switching limits: one row per switching time (rows may be empty)
    for key in _SWITCHING_MATRIX_FIELDS
        if haskey(blob, key) && blob[key] isa Matrix
            M = blob[key]
            blob[key] = [Vector{Float64}(M[i, :]) for i in axes(M, 1)]
        end
    end
end

"""
Convert the rows of a JSON switching-limit field back to a `Matrix{Float64}` with `n` rows
(one per switching time); `0 × 0` when there is no switching time.
"""
function _json_rows_to_matrix(rows, n::Int)::Matrix{Float64}
    n == 0 && return zeros(0, 0)
    ncols = length(rows[1])
    M = zeros(n, ncols)
    for i in 1:n
        M[i, :] .= Float64.(rows[i])
    end
    return M
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

Export an optimal control solution to a `.json` file using the JSON format.

This function serializes a `CTModels.Solution` into a structured JSON dictionary,
including all primal and dual information, which can be read by external tools.

# Arguments
- `::CTModels.JSONTag`: A tag used to dispatch the export method for JSON.
- `sol::CTModels.Solution`: The solution to be saved.

# Keyword Arguments
- `filename::String = "solution"`: Base filename. The `.json` extension is appended
  automatically, unless `filename` already ends with it (case-insensitively).

# Notes
The exported JSON includes the time grid, state, control, costate, objective, solver info, all constraint duals (if available), and the switching structure (switching times, phase labels, left/right limits) when the solution holds one.

# Example
```julia-repl
julia> using JSON, CTModels

julia> CTModels.export_ocp_solution(CTModels.JSONTag(), sol; filename="mysolution")
# → creates "mysolution.json"
```
"""
function CTModels.export_ocp_solution(
    ::CTModels.JSONTag, sol::CTModels.Solution; filename::String
)
    # Use unified serialization that handles both unified and multiple time grids
    blob = CTModels.Solutions._serialize_solution(sol)

    # Convert Matrix → Vector{Vector} for JSON (a Matrix would be written flat)
    _convert_matrices_for_json!(blob)

    # Serialize infos and get Symbol type metadata
    infos_serialized, symbol_keys = _serialize_infos(blob["infos"])
    blob["infos"] = infos_serialized
    blob["infos_symbol_keys"] = symbol_keys

    # serialize first: an error (e.g. a NaN, not allowed in JSON) leaves no half-written file
    text = JSON.json(blob; pretty=true)
    write(CTModels.Serialization._ensure_extension(filename, ".json"), text)

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
- `::CTModels.JSONTag`: A tag used to dispatch the import method for JSON.
- `ocp::CTModels.Model`: The model associated with the optimal control problem. Used to rebuild the full solution.

# Keyword Arguments
- `filename::String = "solution"`: Base filename. The `.json` extension is appended
  automatically, unless `filename` already ends with it (case-insensitively).

# Returns
- `CTModels.Solution`: A reconstructed solution instance.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the file does not match `ocp` (dimensions,
  number or labels of constraints, fixed versus free times). Pass the model the solution
  was computed from.

# Notes
Handles both vector and matrix encodings of signals. If dual fields are missing or `null`, the corresponding attributes are set to `nothing`.

The file is checked against `ocp` before the solution is rebuilt; see
[`CTModels.Serialization.import_ocp_solution`](@extref).

# Example
```julia-repl
julia> using JSON, CTModels

julia> sol = CTModels.import_ocp_solution(CTModels.JSONTag(), model; filename="mysolution")
```
"""
function CTModels.import_ocp_solution(
    ::CTModels.JSONTag, ocp::CTModels.Model; filename::String
)
    json_string = read(CTModels.Serialization._ensure_extension(filename, ".json"), String)
    blob = JSON.parse(json_string; dicttype=Dict{String,Any})

    # Restore Symbol types in infos (JSON reads all strings as String; metadata tracks which were Symbols)
    symbol_keys_raw = get(blob, "infos_symbol_keys", String[])
    symbol_keys = collect(String, symbol_keys_raw)
    infos = if haskey(blob, "infos")
        _deserialize_infos(blob["infos"], symbol_keys)
    else
        Dict{Symbol,Any}()
    end

    # Build data dictionary: convert JSON arrays back to the types expected by the helper
    bcd = blob["boundary_constraints_dual"]
    vclbd = blob["variable_constraints_lb_dual"]
    vcubd = blob["variable_constraints_ub_dual"]

    data = Dict{String,Any}(
        "objective" => blob["objective"],
        "iterations" => blob["iterations"],
        "constraints_violation" => blob["constraints_violation"],
        "message" => blob["message"],
        "status" => blob["status"],
        "successful" => blob["successful"],
        "state" => _json_to_matrix(blob["state"]),
        "control" => _json_to_matrix(blob["control"]),
        "costate" => _json_to_matrix(blob["costate"]),
        "variable" => CTModels.Serialization._extract_time_vector(blob["variable"]),
        "path_constraints_dual" => _json_to_optional_matrix(blob["path_constraints_dual"]),
        "boundary_constraints_dual" => isnothing(bcd) ? nothing : Vector{Float64}(bcd),
        "state_constraints_lb_dual" =>
            _json_to_optional_matrix(blob["state_constraints_lb_dual"]),
        "state_constraints_ub_dual" =>
            _json_to_optional_matrix(blob["state_constraints_ub_dual"]),
        "control_constraints_lb_dual" =>
            _json_to_optional_matrix(blob["control_constraints_lb_dual"]),
        "control_constraints_ub_dual" =>
            _json_to_optional_matrix(blob["control_constraints_ub_dual"]),
        "variable_constraints_lb_dual" =>
            CTModels.Serialization._extract_optional_vector(vclbd),
        "variable_constraints_ub_dual" =>
            CTModels.Serialization._extract_optional_vector(vcubd),
        "control_interpolation" => blob["control_interpolation"],
    )

    # Switching structure (absent when the solution holds none, and from older files)
    if haskey(blob, "switching_times")
        n = length(blob["switching_times"])
        data["switching_times"] = Vector{Float64}(collect(blob["switching_times"]))
        data["phase_labels"] = collect(String, blob["phase_labels"])
        for key in _SWITCHING_MATRIX_FIELDS
            data[key] = _json_rows_to_matrix(blob[key], n)
        end
    end

    # Model signature (absent from files exported by older versions)
    if haskey(blob, "model_signature")
        data["model_signature"] = blob["model_signature"]
    end

    # Time grid: multi-grid format (4 separate grids) or unified format (single time_grid)
    if haskey(blob, "time_grid_state")
        data["time_grid_state"] = blob["time_grid_state"]
        data["time_grid_control"] = blob["time_grid_control"]
        data["time_grid_costate"] = blob["time_grid_costate"]
        data["time_grid_path"] = blob["time_grid_path"]
    else
        data["time_grid"] = blob["time_grid"]
    end

    return CTModels.Serialization._reconstruct_solution_from_data(ocp, data; infos=infos)
end

end
