module CTModelsJLD

using CTModels
using DocStringExtensions
using JLD2

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a `.jld2` file using the JLD2 format.

This function serializes and saves a `CTModels.Solution` object to disk,
allowing it to be reloaded later.

# Arguments
- `::CTModels.JLD2Tag`: A tag used to dispatch the export method for JLD2.
- `sol::CTModels.Solution`: The optimal control solution to be saved.

# Keyword Arguments
- `filename::String = "solution"`: Base name of the file. The `.jld2` extension is automatically appended.

# Example
```julia-repl
julia> export_ocp_solution(JLD2Tag(), sol; filename="mysolution")
# → creates "mysolution.jld2"
```
"""
function CTModels.export_ocp_solution(
    ::CTModels.JLD2Tag, sol::CTModels.Solution; filename::String="solution"
)
    save_object(filename * ".jld2", sol)
    return nothing
end

"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a `.jld2` file.

This function loads a previously saved `CTModels.Solution` from disk.

# Arguments
- `::CTModels.JLD2Tag`: A tag used to dispatch the import method for JLD2.
- `ocp::CTModels.Model`: The associated model (used for dispatch consistency; not used internally).

# Keyword Arguments
- `filename::String = "solution"`: Base name of the file. The `.jld2` extension is automatically appended.

# Returns
- `CTModels.Solution`: The loaded solution object.

# Example
```julia-repl
julia> sol = import_ocp_solution(JLD2Tag(), model; filename="mysolution")
```
"""
function CTModels.import_ocp_solution(
    ::CTModels.JLD2Tag, ocp::CTModels.Model; filename::String="solution"
)
    return load_object(filename * ".jld2")
end

end
