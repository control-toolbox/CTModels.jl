# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem.

"""
function definition!(ocp::OptimalControlModelMutable, definition::Expr)::Nothing
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
definition(ocp::OptimalControlModel)::Expr = ocp.definition

# ------------------------------------------------------------------------------ #
# PRINT
# ------------------------------------------------------------------------------ #

__print(e::Expr, io::IO, l::Int) = begin
    @match e begin
        :(($a, $b)) => println(io, " "^l, a, ", ", b)
        _ => println(io, " "^l, e)
    end
end

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(
    io::IO,
    ::MIME"text/plain",
    ocp::OptimalControlModel,
)

    # some checks
    @assert hasproperty(definition(ocp), :head)

    # print the code
    tab = 4
    code = striplines(definition(ocp))
    @match code.head begin
        :block => [__print(code.args[i], io, tab) for i ∈ eachindex(code.args)]
        _ => __print(code, io, tab)
    end

end

function Base.show_default(io::IO, ocp::OptimalControlModel)
    print(io, typeof(ocp))
end