# Export/import functions (require AbstractSolution and AbstractModel types)

# -----------------------------
# to be extended
function RecipesBase.plot(sol::AbstractSolution, description::Symbol...; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
end

function export_ocp_solution(::JLD2Tag, ::AbstractSolution; filename::String)
    throw(CTBase.ExtensionError(:JLD2))
end

function import_ocp_solution(::JLD2Tag, ::AbstractModel; filename::String)
    throw(CTBase.ExtensionError(:JLD2))
end

function export_ocp_solution(::JSON3Tag, ::AbstractSolution; filename::String)
    throw(CTBase.ExtensionError(:JSON))
end

function import_ocp_solution(::JSON3Tag, ::AbstractModel; filename::String)
    throw(CTBase.ExtensionError(:JSON))
end

"""
    export_ocp_solution(sol; format=:JLD, filename="solution")

Export an optimal control solution to a file.

# Arguments
- `sol::AbstractSolution`: The solution to export.

# Keyword Arguments
- `format::Symbol=:JLD`: Export format, either `:JLD` or `:JSON`.
- `filename::String="solution"`: Base filename (extension added automatically).

# Notes
Requires loading the appropriate package (`JLD2` or `JSON3`) before use.

See also: [`import_ocp_solution`](@ref)
"""
function export_ocp_solution(
    sol::AbstractSolution;
    format::Symbol=__format(),
    filename::String=__filename_export_import(),
)
    if format == :JLD
        return export_ocp_solution(JLD2Tag(), sol; filename=filename)
    elseif format == :JSON
        return export_ocp_solution(JSON3Tag(), sol; filename=filename)
    else
        throw(
            CTBase.IncorrectArgument(
                "unknown format (should be :JLD or :JSON): " * string(format)
            ),
        )
    end
end

"""
    import_ocp_solution(ocp; format=:JLD, filename="solution")

Import an optimal control solution from a file.

# Arguments
- `ocp::AbstractModel`: The model associated with the solution.

# Keyword Arguments
- `format::Symbol=:JLD`: Import format, either `:JLD` or `:JSON`.
- `filename::String="solution"`: Base filename (extension added automatically).

# Returns
- `Solution`: The imported solution.

# Notes
Requires loading the appropriate package (`JLD2` or `JSON3`) before use.

See also: [`export_ocp_solution`](@ref)
"""
function import_ocp_solution(
    ocp::AbstractModel;
    format::Symbol=__format(),
    filename::String=__filename_export_import(),
)
    if format == :JLD
        return import_ocp_solution(JLD2Tag(), ocp; filename=filename)
    elseif format == :JSON
        return import_ocp_solution(JSON3Tag(), ocp; filename=filename)
    else
        throw(
            CTBase.IncorrectArgument(
                "unknown format (should be :JLD or :JSON): " * string(format)
            ),
        )
    end
end
