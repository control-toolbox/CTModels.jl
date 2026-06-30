# ------------------------------------------------------------------------------ #
# Helper functions for solution reconstruction with multiple time grids
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Reconstruct a solution from imported data, detecting the format (single vs multiple time grids).

Duals and `control_interpolation` are read from `data`. Only `infos` is accepted as a
keyword argument because its deserialization is format-specific (JSON restores `Symbol` types).

# Arguments
- `ocp`: The optimal control problem model
- `data`: Dictionary containing the imported solution data, including all dual fields and
  `control_interpolation`

# Keyword Arguments
- `infos`: Solver information dictionary (`Dict{Symbol,Any}`). Passed explicitly because
  JSON deserialization must restore `Symbol` types before calling this helper.

# Returns
- `Solution`: Reconstructed solution with appropriate time grid model

# Notes
- If `time_grid_state` key exists, assumes multiple time grid format
- Otherwise, uses the current unified format (single `time_grid` key)

# Example
```julia-repl
julia> sol = _reconstruct_solution_from_data(ocp, data; infos=infos)
```

See also: [`CTModels.Serialization._extract_time_vector`](@ref).
"""
function _reconstruct_solution_from_data(ocp, data; infos=Dict{Symbol,Any}())
    control_interpolation = Symbol(data["control_interpolation"])

    path_constraints_dual = data["path_constraints_dual"]
    boundary_constraints_dual = data["boundary_constraints_dual"]
    state_constraints_lb_dual = data["state_constraints_lb_dual"]
    state_constraints_ub_dual = data["state_constraints_ub_dual"]
    control_constraints_lb_dual = data["control_constraints_lb_dual"]
    control_constraints_ub_dual = data["control_constraints_ub_dual"]
    variable_constraints_lb_dual = data["variable_constraints_lb_dual"]
    variable_constraints_ub_dual = data["variable_constraints_ub_dual"]

    # Detect format and extract time grids
    if haskey(data, "time_grid_state")
        # Multiple time grids format
        T_state = _extract_time_vector(data["time_grid_state"])
        T_control = _extract_time_vector(data["time_grid_control"])
        T_costate = _extract_time_vector(data["time_grid_costate"])
        T_path = _extract_time_vector(data["time_grid_path"])

        return Solutions.build_solution(
            ocp,
            T_state,
            T_control,
            T_costate,
            T_path,
            data["state"],
            data["control"],
            _extract_time_vector(data["variable"]),
            data["costate"];
            objective=Float64(data["objective"]),
            iterations=data["iterations"],
            constraints_violation=Float64(data["constraints_violation"]),
            message=data["message"],
            status=Symbol(data["status"]),
            successful=data["successful"],
            path_constraints_dual=path_constraints_dual,
            boundary_constraints_dual=boundary_constraints_dual,
            state_constraints_lb_dual=state_constraints_lb_dual,
            state_constraints_ub_dual=state_constraints_ub_dual,
            control_constraints_lb_dual=control_constraints_lb_dual,
            control_constraints_ub_dual=control_constraints_ub_dual,
            variable_constraints_lb_dual=variable_constraints_lb_dual,
            variable_constraints_ub_dual=variable_constraints_ub_dual,
            infos=infos,
            control_interpolation=control_interpolation,
        )
    else
        # Current unified format: single time grid
        if !haskey(data, "time_grid")
            throw(
                Exceptions.ParsingError(
                    "solution data is missing the 'time_grid' key";
                    location="imported solution dictionary",
                    suggestion="re-export the solution with a current CTModels version",
                ),
            )
        end
        T = _extract_time_vector(data["time_grid"])

        return Solutions.build_solution(
            ocp,
            T,
            data["state"],
            data["control"],
            _extract_time_vector(data["variable"]),
            data["costate"];
            objective=Float64(data["objective"]),
            iterations=data["iterations"],
            constraints_violation=Float64(data["constraints_violation"]),
            message=data["message"],
            status=Symbol(data["status"]),
            successful=data["successful"],
            path_constraints_dual=path_constraints_dual,
            boundary_constraints_dual=boundary_constraints_dual,
            state_constraints_lb_dual=state_constraints_lb_dual,
            state_constraints_ub_dual=state_constraints_ub_dual,
            control_constraints_lb_dual=control_constraints_lb_dual,
            control_constraints_ub_dual=control_constraints_ub_dual,
            variable_constraints_lb_dual=variable_constraints_lb_dual,
            variable_constraints_ub_dual=variable_constraints_ub_dual,
            infos=infos,
            control_interpolation=control_interpolation,
        )
    end
end

"""
$(TYPEDSIGNATURES)

Extract time vector from various data formats.

# Arguments
- `time_data`: Time data in various formats (Vector, Matrix, etc.)

# Returns
- `Vector{Float64}`: Time vector

# Notes
- Handles both Vector{Float64} and Matrix{Float64} (single column) formats
- Used by JSON and JLD2 importers to normalize time grid data

See also: [`CTModels.Serialization._reconstruct_solution_from_data`](@ref).
"""
function _extract_time_vector(time_data)
    if time_data isa Vector{Float64}
        return time_data
    elseif time_data isa Matrix{Float64}
        return vec(time_data)
    else
        return Vector{Float64}(time_data)
    end
end
