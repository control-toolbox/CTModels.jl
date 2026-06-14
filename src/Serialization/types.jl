# Export/import types and functions

"""
$(TYPEDEF)

Abstract type for export/import functions, used to choose between JSON or JLD extensions.

See also: [`CTModels.Serialization.JLD2Tag`](@ref), [`CTModels.Serialization.JSON3Tag`](@ref).
"""
abstract type AbstractTag end

"""
$(TYPEDEF)

JLD tag for export/import functions.

# Fields
No fields (empty struct used as a type tag).

See also: [`CTModels.Serialization.AbstractTag`](@ref), [`CTModels.Serialization.JSON3Tag`](@ref).
"""
struct JLD2Tag <: AbstractTag end

"""
$(TYPEDEF)

JSON tag for export/import functions.

# Fields
No fields (empty struct used as a type tag).

See also: [`CTModels.Serialization.AbstractTag`](@ref), [`CTModels.Serialization.JLD2Tag`](@ref).
"""
struct JSON3Tag <: AbstractTag end
