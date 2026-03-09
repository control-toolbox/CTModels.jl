# Export/import functions (require AbstractSolution and AbstractModel types)

# -----------------------------
# to be extended by extensions
function export_ocp_solution(::JLD2Tag, ::AbstractSolution; filename::String)
    throw(Exceptions.ExtensionError(:JLD2; message="to export solutions to JLD2 format"))
end

function import_ocp_solution(::JLD2Tag, ::AbstractModel; filename::String)
    throw(Exceptions.ExtensionError(:JLD2; message="to import solutions from JLD2 format"))
end

function export_ocp_solution(::JSON3Tag, ::AbstractSolution; filename::String)
    throw(Exceptions.ExtensionError(:JSON3; message="to export solutions to JSON format"))
end

function import_ocp_solution(::JSON3Tag, ::AbstractModel; filename::String)
    throw(Exceptions.ExtensionError(:JSON3; message="to import solutions from JSON format"))
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

See also: `import_ocp_solution`
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
            Exceptions.IncorrectArgument(
                "Invalid export format specified";
                got="format=$format",
                expected=":JLD or :JSON",
                suggestion="Use format=:JLD for binary files or format=:JSON for text files",
                context="export_ocp_solution - validating export format",
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

See also: `export_ocp_solution`
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
            Exceptions.IncorrectArgument(
                "Invalid import format specified";
                got="format=$format",
                expected=":JLD or :JSON",
                suggestion="Use format=:JLD for binary files or format=:JSON for text files",
                context="import_ocp_solution - validating import format",
            ),
        )
    end
end
