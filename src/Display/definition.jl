# ------------------------------------------------------------------------------ #
# Abstract (symbolic) definition printing
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print a [`CTModels.Components.EmptyDefinition`](@extref): no output is produced.

# Returns
- `Bool`: `false` to indicate that nothing was printed.
"""
_print_abstract_definition(::IO, ::Components.EmptyDefinition)::Bool = false

"""
$(TYPEDSIGNATURES)

Print a [`CTModels.Components.Definition`](@extref) under an "Abstract definition:" header.

Block expressions are unfolded line-by-line; other expression heads are
printed as a single indented entry.

# Arguments

- `io::IO`: The output stream.
- `d::Definition`: The symbolic definition to display.

# Returns
- `Bool`: `true` to indicate that output was produced.

See also: [`CTModels.Display.__print`](@extref).
"""
function _print_abstract_definition(io::IO, d::Components.Definition)::Bool
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.emphasis, "Abstract definition:\n\n", fmt.reset)
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

Display method for any [`CTModels.Components.AbstractDefinition`](@extref).

Delegates to [`CTModels.Display._print_abstract_definition`](@extref).

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Display._print_abstract_definition`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", d::Components.AbstractDefinition)
    return _print_abstract_definition(io, d)
end
