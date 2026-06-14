# ------------------------------------------------------------------------------ #
# ANSI helpers and generic Expr printing
# ------------------------------------------------------------------------------ #

"""
Generate ANSI escape sequence for the specified color and formatting.

Returns the ANSI escape code for the given color, optionally with bold formatting.

# Arguments
- `color::Symbol`: The color name (`:black`, `:red`, `:green`, etc.).
- `bold::Bool`: Whether to use bold formatting (default: `false`).

# Returns
- `String`: The ANSI escape sequence.
"""
function _ansi_color(color::Symbol, bold::Bool=false)
    color_codes = Dict(
        :black => 30,
        :red => 31,
        :green => 32,
        :yellow => 33,
        :blue => 34,
        :magenta => 35,
        :cyan => 36,
        :white => 37,
        :default => 39,
    )

    code = get(color_codes, color, 39)
    return bold ? "\033[1;$(code)m" : "\033[$(code)m"
end

"""
Generate ANSI reset sequence to clear formatting.

Returns the ANSI escape code that resets all formatting to default.

# Returns
- `String`: The ANSI reset escape sequence `\033[0m`.
"""
_ansi_reset() = "\033[0m"

"""
Print text with ANSI color formatting for Documenter compatibility.

Applies ANSI color and bold formatting to the text and prints it to the output stream.

# Arguments
- `io`: The output stream.
- `text::Union{String,Symbol,Type}`: The text to print.
- `color::Symbol`: The color name.
- `bold::Bool`: Whether to use bold formatting (default: `false`).

# Returns
- `Nothing`: Prints to `io` and returns nothing.
"""
function _print_ansi_styled(
    io, text::Union{String,Symbol,Type}, color::Symbol, bold::Bool=false
)
    return print(io, _ansi_color(color, bold), string(text), _ansi_reset())
end

"""
$(TYPEDSIGNATURES)

Print an expression with indentation.

# Arguments

- `e::Expr`: The expression to print.
- `io::IO`: The output stream.
- `l::Int`: The indentation level (number of spaces).

# Returns
- `Nothing`: Prints to `io` and returns nothing.
"""
function __print(e::Expr, io::IO, l::Int)
    MLStyle.@match e begin
        :(($a, $b)) => println(io, " "^l, a, ", ", b)
        _ => println(io, " "^l, e)
    end
end
