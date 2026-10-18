# Export/import types and functions

"""
$(TYPEDEF)

Abstract type for export/import functions, used to choose between JSON or JLD extensions.

See also: [`CTModels.Serialization.JLD2Tag`](@extref), [`CTModels.Serialization.JSONTag`](@extref).
"""
abstract type AbstractTag end

"""
$(TYPEDEF)

JLD tag for export/import functions.

# Fields
No fields (empty struct used as a type tag).

See also: [`CTModels.Serialization.AbstractTag`](@extref), [`CTModels.Serialization.JSONTag`](@extref).
"""
struct JLD2Tag <: AbstractTag end

"""
$(TYPEDEF)

JSON tag for export/import functions.

# Fields
No fields (empty struct used as a type tag).

See also: [`CTModels.Serialization.AbstractTag`](@extref), [`CTModels.Serialization.JLD2Tag`](@extref).
"""
struct JSONTag <: AbstractTag end

function Base.show(io::IO, ::JLD2Tag)
    fmt = CTBase.Core.get_format_codes(io)
    return print(io, fmt.name, "JLD2Tag", fmt.reset, "()")
end

function Base.show(io::IO, ::MIME"text/plain", ::JLD2Tag)
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "JLD2Tag", fmt.reset)
    return print(
        io, "\n  ", fmt.label, "kind: ", fmt.reset, fmt.keyword, ":format_tag", fmt.reset
    )
end

function Base.show(io::IO, ::JSONTag)
    fmt = CTBase.Core.get_format_codes(io)
    return print(io, fmt.name, "JSONTag", fmt.reset, "()")
end

function Base.show(io::IO, ::MIME"text/plain", ::JSONTag)
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "JSONTag", fmt.reset)
    return print(
        io, "\n  ", fmt.label, "kind: ", fmt.reset, fmt.keyword, ":format_tag", fmt.reset
    )
end
