# ------------------------------------------------------------------------------
# Shared palette-aware display helpers
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Return the active CTBase palette codes for `io`.
"""
format_codes(io::IO) = CTBase.Core.get_format_codes(io)

"""
$(TYPEDSIGNATURES)

Print a palette-styled type header without a trailing newline.
"""
function print_header(io::IO, name; fmt=format_codes(io))
    print(io, fmt.name, name, fmt.reset)
    return nothing
end

"""
$(TYPEDSIGNATURES)

Render a nested display value while preserving the colour context of `io`.
"""
function _display_value(io::IO, value)
    return if value isa AbstractString
        value
    else
        sprint(print, value; context=IOContext(io, :color => get(io, :color, false)))
    end
end

"""
$(TYPEDSIGNATURES)

Print one labelled tree field using semantic palette roles.
"""
function print_field(
    io::IO, label, value; last::Bool=false, fmt=format_codes(io), value_style=nothing
)
    style = value_style === nothing ? fmt.value : value_style
    reset = isempty(style) ? "" : fmt.reset
    branch = last ? "└─ " : "├─ "
    value_string = _display_value(io, value)
    lines = split(value_string, '\n')

    print(io, '\n', fmt.muted, branch, fmt.reset)
    isempty(string(label)) || print(io, fmt.label, label, fmt.reset, ": ")
    print(io, style, first(lines), reset)
    if length(lines) > 1
        continuation = last ? "   " : string(fmt.muted, "│", fmt.reset, "  ")
        for line in @view lines[2:end]
            print(io, '\n', continuation, style, line, reset)
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Print a sequence of labelled fields and mark the final field with `└─`.
"""
function print_fields(io::IO, fields; fmt=format_codes(io))
    for (index, field) in enumerate(fields)
        style = length(field) >= 3 ? field[3] : nothing
        print_field(
            io, field[1], field[2]; last=index == length(fields), fmt=fmt, value_style=style
        )
    end
    return nothing
end

_callable_name(f) = nameof(typeof(f))
_callable_value(_) = "<callable>"

"""
$(TYPEDSIGNATURES)

Print a compact one-line representation with palette-styled fields.
"""
function _show_compact(io::IO, type_name; fields=(), fmt=format_codes(io))
    print(io, fmt.name, type_name, fmt.reset, "(")
    for (index, field) in enumerate(fields)
        index > 1 && print(io, ", ")
        print(io, fmt.label, field[1], fmt.reset, "=", fmt.value, field[2], fmt.reset)
    end
    return print(io, ")")
end

"""
$(TYPEDSIGNATURES)

Print a detailed tree representation with palette-styled fields.
"""
function _show_detail(io::IO, type_name; fields=(), fmt=format_codes(io))
    print_header(io, type_name; fmt=fmt)
    return print_fields(io, fields; fmt=fmt)
end
