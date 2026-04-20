# ------------------------------------------------------------------------------ #
# ANSI helpers and generic Expr printing
# ------------------------------------------------------------------------------ #

"""
Generate ANSI escape sequence for the specified color and formatting.
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

"""Generate ANSI reset sequence to clear formatting."""
_ansi_reset() = "\033[0m"

"""
Print text with ANSI color formatting for Documenter compatibility.
"""
function _print_ansi_styled(
    io, text::Union{String,Symbol,Type}, color::Symbol, bold::Bool=false
)
    print(io, _ansi_color(color, bold), string(text), _ansi_reset())
end

"""
$(TYPEDSIGNATURES)

Print an expression with indentation.

# Arguments

- `e::Expr`: The expression to print.
- `io::IO`: The output stream.
- `l::Int`: The indentation level (number of spaces).
"""
function __print(e::Expr, io::IO, l::Int)
    MLStyle.@match e begin
        :(($a, $b)) => println(io, " "^l, a, ", ", b)
        _ => println(io, " "^l, e)
    end
end
