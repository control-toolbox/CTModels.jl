# ------------------------------------------------------------------------------ #
# Abstract (symbolic) definition printing
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print a [`CTModels.Components.EmptyDefinition`](@ref): no output is produced.

# Returns
- `Bool`: `false` to indicate that nothing was printed.
"""
_print_abstract_definition(::IO, ::Components.EmptyDefinition)::Bool = false

"""
$(TYPEDSIGNATURES)

Print a [`CTModels.Components.Definition`](@ref) under an "Abstract definition:" header.

Block expressions are unfolded line-by-line; other expression heads are
printed as a single indented entry.

# Arguments

- `io::IO`: The output stream.
- `d::Definition`: The symbolic definition to display.

# Returns
- `Bool`: `true` to indicate that output was produced.

See also: [`CTModels.Display.__print`](@ref).
"""
function _print_abstract_definition(io::IO, d::Components.Definition)::Bool
    _print_ansi_styled(io, "Abstract definition:\n\n", :default, true)
    tab = 4
    code = MacroTools.striplines(d.expr)
    MLStyle.@match code.head begin
        :block => [__print(code.args[i], io, tab) for i in eachindex(code.args)]
        _ => __print(code, io, tab)
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Display method for any [`CTModels.Components.AbstractDefinition`](@ref).

Delegates to [`_print_abstract_definition`](@ref).

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Display._print_abstract_definition`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", d::Components.AbstractDefinition)
    return _print_abstract_definition(io, d)
end
