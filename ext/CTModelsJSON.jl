module CTModelsJSON

using CTModels
using DocStringExtensions

using JSON3

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
    T = CTModels.time_grid(sol)

    blob = Dict(
        "time_grid" => CTModels.time_grid(sol),
        "state" => _apply_over_grid(CTModels.state(sol), T),
        "control" => _apply_over_grid(CTModels.control(sol), T),
        "variable" => CTModels.variable(sol),
        "costate" => _apply_over_grid(CTModels.costate(sol), T),
        "objective" => CTModels.objective(sol),
        "iterations" => CTModels.iterations(sol),
        "constraints_violation" => CTModels.constraints_violation(sol),
        "message" => CTModels.message(sol),
        "status" => CTModels.status(sol),
        "successful" => CTModels.successful(sol),
        "path_constraints_dual" => _apply_over_grid(CTModels.path_constraints_dual(sol), T),
        "state_constraints_lb_dual" =>
            _apply_over_grid(CTModels.state_constraints_lb_dual(sol), T),
        "state_constraints_ub_dual" =>
            _apply_over_grid(CTModels.state_constraints_ub_dual(sol), T),
        "control_constraints_lb_dual" =>
            _apply_over_grid(CTModels.control_constraints_lb_dual(sol), T),
        "control_constraints_ub_dual" =>
            _apply_over_grid(CTModels.control_constraints_ub_dual(sol), T),
        "boundary_constraints_dual" => CTModels.boundary_constraints_dual(sol),       # ctVector or Nothing
        "variable_constraints_lb_dual" => CTModels.variable_constraints_lb_dual(sol),    # ctVector or Nothing
        "variable_constraints_ub_dual" => CTModels.variable_constraints_ub_dual(sol),    # ctVector or Nothing
    )

    # Serialize infos and get Symbol type metadata
    infos_serialized, symbol_keys = _serialize_infos(CTModels.infos(sol))
    blob["infos"] = infos_serialized
    blob["infos_symbol_keys"] = symbol_keys

    open(filename * ".json", "w") do io
        JSON3.pretty(io, blob)
    end

    return nothing
end

"""
$(TYPEDSIGNATURES)

Convert JSON3 array data to `Matrix{Float64}` for trajectory import.

# Context

When importing JSON data, `stack(blob[field]; dims=1)` returns different types
depending on the dimensionality of the original trajectory:
- **1D trajectories** (e.g., scalar control): `stack()` → `Vector{Float64}`
- **Multi-D trajectories** (e.g., 2D state): `stack()` → `Matrix{Float64}`

This function normalizes both cases to `Matrix{Float64}` as required by `build_solution`.

# Arguments
- `data`: Output from `stack(blob[field]; dims=1)`, either `Vector` or `Matrix`

# Returns
- `Matrix{Float64}`: Properly shaped matrix `(n_time_points, n_dim)` for `build_solution`

# Implementation Details

- **Vector case**: Converts `Vector{Float64}` of length `n` to `Matrix{Float64}(n, 1)`
  using `reduce(hcat, data)'` to preserve time-series ordering
- **Matrix case**: Direct conversion to `Matrix{Float64}`

# Examples

```julia
# 1D control trajectory (101 time points)
control_data = [5.99, 5.93, ..., -5.99]  # Vector{Float64}
control_matrix = _json_array_to_matrix(control_data)
# → Matrix{Float64}(101, 1)

# 2D state trajectory (101 time points, 2 dimensions)
state_data = [1.0 2.0; 1.1 2.1; ...]  # Matrix{Float64}(101, 2)
state_matrix = _json_array_to_matrix(state_data)
# → Matrix{Float64}(101, 2)
```

# See Also
- Test coverage: `test/suite/serialization/test_export_import.jl` 
  (testset "JSON stack() behavior investigation")
"""
function _json_array_to_matrix(data)::Matrix{Float64}
    if data isa Vector
        return Matrix{Float64}(reduce(hcat, data)')
    else
        return Matrix{Float64}(data)
    end
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

    # get state
    X = _json_array_to_matrix(stack(blob["state"]; dims=1))

    # get control
    U = _json_array_to_matrix(stack(blob["control"]; dims=1))

    # get costate
    P = _json_array_to_matrix(stack(blob["costate"]; dims=1))

    # get dual path constraints: convert to matrix
    path_constraints_dual = if isnothing(blob["path_constraints_dual"])
        nothing
    else
        _json_array_to_matrix(stack(blob["path_constraints_dual"]; dims=1))
    end

    # get state constraints (and dual): convert to matrix
    state_constraints_lb_dual = if isnothing(blob["state_constraints_lb_dual"])
        nothing
    else
        _json_array_to_matrix(stack(blob["state_constraints_lb_dual"]; dims=1))
    end
    state_constraints_ub_dual = if isnothing(blob["state_constraints_ub_dual"])
        nothing
    else
        _json_array_to_matrix(stack(blob["state_constraints_ub_dual"]; dims=1))
    end

    # get control constraints (and dual): convert to matrix
    control_constraints_lb_dual = if isnothing(blob["control_constraints_lb_dual"])
        nothing
    else
        _json_array_to_matrix(stack(blob["control_constraints_lb_dual"]; dims=1))
    end
    control_constraints_ub_dual = if isnothing(blob["control_constraints_ub_dual"])
        nothing
    else
        _json_array_to_matrix(stack(blob["control_constraints_ub_dual"]; dims=1))
    end

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

    # NB. convert vect{vect} to matrix
    return CTModels.build_solution(
        ocp,
        Vector{Float64}(blob.time_grid),
        X,
        U,
        Vector{Float64}(blob.variable),
        P;
        objective=Float64(blob.objective),
        iterations=blob.iterations,
        constraints_violation=Float64(blob.constraints_violation),
        message=blob.message,
        status=Symbol(blob.status),
        successful=blob.successful,
        path_constraints_dual=path_constraints_dual,
        state_constraints_lb_dual=state_constraints_lb_dual,
        state_constraints_ub_dual=state_constraints_ub_dual,
        control_constraints_lb_dual=control_constraints_lb_dual,
        control_constraints_ub_dual=control_constraints_ub_dual,
        boundary_constraints_dual=boundary_constraints_dual,
        variable_constraints_lb_dual=variable_constraints_lb_dual,
        variable_constraints_ub_dual=variable_constraints_ub_dual,
        infos=infos,
    )
end

end
