# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem.

"""
function definition!(ocp::PreModel, definition::Expr)::Nothing
    ocp.definition = definition
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem or `nothing`.

"""
function definition(ocp::Model)::Expr
    return ocp.definition
end

# ------------------------------------------------------------------------------ #
# PRINT
# ------------------------------------------------------------------------------ #
function __print(e::Expr, io::IO, l::Int)
    @match e begin
        :(($a, $b)) => println(io, " "^l, a, ", ", b)
        _ => println(io, " "^l, e)
    end
end

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::Model)

    # some checks
    @assert hasproperty(definition(ocp), :head)

    # print the code
    tab = 4
    code = striplines(definition(ocp))
    @match code.head begin
        :block => [__print(code.args[i], io, tab) for i in eachindex(code.args)]
        _ => __print(code, io, tab)
    end
end

function Base.show_default(io::IO, ocp::Model)
    return print(io, typeof(ocp))
end
