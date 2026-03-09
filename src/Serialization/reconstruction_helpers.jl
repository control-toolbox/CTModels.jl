# ------------------------------------------------------------------------------ #
# Helper functions for solution reconstruction with multiple time grids
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Reconstruct a solution from imported data, detecting the format (single vs multiple time grids).

# Arguments
- `ocp`: The optimal control problem model
- `data`: Dictionary containing the imported solution data
- `path_constraints_dual`: Optional path constraints dual function
- `boundary_constraints_dual`: Optional boundary constraints dual function
- `state_constraints_lb_dual`: Optional state constraints lower bound dual function
- `state_constraints_ub_dual`: Optional state constraints upper bound dual function
- `control_constraints_lb_dual`: Optional control constraints lower bound dual function
- `control_constraints_ub_dual`: Optional control constraints upper bound dual function
- `variable_constraints_lb_dual`: Optional variable constraints lower bound dual function
- `variable_constraints_ub_dual`: Optional variable constraints upper bound dual function
- `infos`: Optional solver information

# Returns
- `Solution`: Reconstructed solution with appropriate time grid model

# Notes
- If `time_grid_state` key exists, assumes new multiple time grid format
- Otherwise, uses legacy single time grid format
- Handles both raw vectors and TimeGridModel objects for legacy format

# Example
```julia-repl
julia> sol = _reconstruct_solution_from_data(ocp, data)
```
"""
function _reconstruct_solution_from_data(
    ocp,
    data;
    path_constraints_dual=nothing,
    boundary_constraints_dual=nothing,
    state_constraints_lb_dual=nothing,
    state_constraints_ub_dual=nothing,
    control_constraints_lb_dual=nothing,
    control_constraints_ub_dual=nothing,
    variable_constraints_lb_dual=nothing,
    variable_constraints_ub_dual=nothing,
    infos=nothing,
)
    # Detect format and extract time grids
    if haskey(data, "time_grid_state")
        # New format: multiple time grids
        T_state = _extract_time_vector(data["time_grid_state"])
        T_control = _extract_time_vector(data["time_grid_control"])
        T_costate = _extract_time_vector(data["time_grid_costate"])
        T_dual = _extract_time_vector(data["time_grid_dual"])

        # Reconstruct solution with multiple time grids
        return OCP.build_solution(
            ocp,
            T_state,
            T_control,
            T_costate,
            T_dual,
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
        )
    else
        # Legacy format: single time grid
        T = if haskey(data, "time_grid")
            time_grid_data = data["time_grid"]
            if time_grid_data isa OCP.TimeGridModel
                time_grid_data.value
            else
                _extract_time_vector(time_grid_data)
            end
        else
            error("Legacy format requires 'time_grid' key")
        end

        # Reconstruct solution using legacy compatibility (will create UnifiedTimeGridModel)
        return OCP.build_solution(
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
