# ------------------------------------------------------------------------------ #
# Abstract (symbolic) definition printing
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the abstract definition of an optimal control problem.

# Arguments

- `io::IO`: The output stream.
- `ocp::Union{Model,PreModel}`: The optimal control problem.

# Returns

- `Bool`: `true` if something was printed.
"""
function __print_abstract_definition(io::IO, ocp::Union{Model,PreModel})
    @assert hasproperty(definition(ocp), :head)
    _print_ansi_styled(io, "Abstract definition:\n\n", :default, true)
    tab = 4
    code = MacroTools.striplines(definition(ocp))
    MLStyle.@match code.head begin
        :block => [__print(code.args[i], io, tab) for i in eachindex(code.args)]
        _ => __print(code, io, tab)
    end
    return true
end
