# ------------------------------------------------------------------------------ #
# Generic Expr printing
# ------------------------------------------------------------------------------ #

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
