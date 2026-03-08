module CTModelsJLD

using CTModels
using DocStringExtensions
using JLD2

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a `.jld2` file using the JLD2 format.

This function serializes and saves a `CTModels.Solution` object to disk,
allowing it to be reloaded later. The solution is discretized to avoid
serialization warnings for function objects.

# Arguments
- `::CTModels.JLD2Tag`: A tag used to dispatch the export method for JLD2.
- `sol::CTModels.Solution`: The optimal control solution to be saved.

# Keyword Arguments
- `filename::String = "solution"`: Base name of the file. The `.jld2` extension is automatically appended.

# Example
```julia-repl
julia> using JLD2
julia> export_ocp_solution(JLD2Tag(), sol; filename="mysolution")
# → creates "mysolution.jld2"
```

# Notes
- Functions are discretized on the time grid to avoid JLD2 serialization warnings
- The solution can be perfectly reconstructed via `import_ocp_solution`
- Uses the same discretization logic as JSON export for consistency
"""
function CTModels.export_ocp_solution(
    ::CTModels.JLD2Tag, sol::CTModels.Solution; filename::String
)
    # Serialize solution to discrete data
    data = CTModels.OCP._serialize_solution(sol)

    # Save only the serialized data (no more OCP model)
    jldsave(filename * ".jld2"; solution_data=data)

    return nothing
end

"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a `.jld2` file.

This function loads a previously saved `CTModels.Solution` from disk and
reconstructs it using `build_solution` from the discretized data.

# Arguments
- `::CTModels.JLD2Tag`: A tag used to dispatch the import method for JLD2.
- `ocp::CTModels.Model`: The associated optimal control problem model.

# Keyword Arguments
- `filename::String = "solution"`: Base name of the file. The `.jld2` extension is automatically appended.

# Returns
- `CTModels.Solution`: The reconstructed solution object.

# Example
```julia-repl
julia> using JLD2
julia> sol = import_ocp_solution(JLD2Tag(), model; filename="mysolution")
```

# Notes
- The solution is reconstructed from discretized data via `build_solution`
- This ensures perfect round-trip consistency with the export
- The OCP model from the file is used if the provided one is not compatible
"""
function CTModels.import_ocp_solution(
    ::CTModels.JLD2Tag, ocp::CTModels.Model; filename::String
)
    # Load the saved data
    file_data = load(filename * ".jld2")
    data = file_data["solution_data"]

    # Extract solver infos if present
    infos = if haskey(data, "infos")
        data["infos"]
    else
        Dict{Symbol,Any}()
    end

    # Reconstruct solution using helper function (handles both single and multiple time grids)
    sol = CTModels.Serialization._reconstruct_solution_from_data(
        ocp,
        data;
        path_constraints_dual=data["path_constraints_dual"],
        boundary_constraints_dual=data["boundary_constraints_dual"],
        state_constraints_lb_dual=data["state_constraints_lb_dual"],
        state_constraints_ub_dual=data["state_constraints_ub_dual"],
        control_constraints_lb_dual=data["control_constraints_lb_dual"],
        control_constraints_ub_dual=data["control_constraints_ub_dual"],
        variable_constraints_lb_dual=data["variable_constraints_lb_dual"],
        variable_constraints_ub_dual=data["variable_constraints_ub_dual"],
        infos=infos,
    )

    return sol
end

end
