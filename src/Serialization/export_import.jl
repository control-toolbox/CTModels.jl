# Export/import functions (require AbstractSolution and AbstractModel types)

# -----------------------------
# to be extended by extensions
function export_ocp_solution(::JLD2Tag, ::Solutions.AbstractSolution; filename::String)
    return throw(
        Exceptions.ExtensionError(:JLD2; message="to export solutions to JLD2 format")
    )
end

function import_ocp_solution(::JLD2Tag, ::Models.AbstractModel; filename::String)
    return throw(
        Exceptions.ExtensionError(:JLD2; message="to import solutions from JLD2 format")
    )
end

function export_ocp_solution(::JSON3Tag, ::Solutions.AbstractSolution; filename::String)
    return throw(
        Exceptions.ExtensionError(:JSON3; message="to export solutions to JSON format")
    )
end

function import_ocp_solution(::JSON3Tag, ::Models.AbstractModel; filename::String)
    return throw(
        Exceptions.ExtensionError(:JSON3; message="to import solutions from JSON format")
    )
end

"""
$(TYPEDSIGNATURES)

Return `filename` with `ext` appended, unless `filename` already ends with `ext`
(case-insensitively).

# Arguments
- `filename::String`: base filename, with or without `ext`.
- `ext::String`: extension to ensure, including the leading dot (e.g. `".json"`).

# Returns
- `String`: `filename` unchanged if it already ends with `ext`; `filename * ext` otherwise.

# Example
```julia-repl
julia> using CTModels: Serialization

julia> Serialization._ensure_extension("solution", ".json")
"solution.json"

julia> Serialization._ensure_extension("solution.json", ".json")
"solution.json"
```
"""
function _ensure_extension(filename::String, ext::String)::String
    return endswith(lowercase(filename), lowercase(ext)) ? filename : filename * ext
end

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a file.

# Arguments
- `sol::AbstractSolution`: The solution to export.

# Keyword Arguments
- `format::Symbol=:JLD`: Export format, either `:JLD` or `:JSON`.
- `filename::String="solution"`: Base filename; the extension is appended automatically,
  unless `filename` already ends with it (case-insensitively).

# Returns
- `Nothing`: This function writes to a file and returns nothing.

# Notes
Requires loading the appropriate package (`JLD2` or `JSON3`) before use.

See also: [`CTModels.Serialization.import_ocp_solution`](@extref).
"""
function export_ocp_solution(
    sol::Solutions.AbstractSolution;
    format::Symbol=Building.__format(),
    filename::String=Building.__filename_export_import(),
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
$(TYPEDSIGNATURES)

Import an optimal control solution from a file.

# Arguments
- `ocp::AbstractModel`: The model associated with the solution.

# Keyword Arguments
- `format::Symbol=:JLD`: Import format, either `:JLD` or `:JSON`.
- `filename::String="solution"`: Base filename; the extension is appended automatically,
  unless `filename` already ends with it (case-insensitively).

# Returns
- `Solution`: The imported solution.

# Notes
Requires loading the appropriate package (`JLD2` or `JSON3`) before use.

See also: [`CTModels.Serialization.export_ocp_solution`](@extref).
"""
function import_ocp_solution(
    ocp::Models.AbstractModel;
    format::Symbol=Building.__format(),
    filename::String=Building.__filename_export_import(),
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
