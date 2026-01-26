# Export/import types and functions

"""
$(TYPEDEF)

Abstract type for export/import functions, used to choose between JSON or JLD extensions.
"""
abstract type AbstractTag end

"""
$(TYPEDEF)

JLD tag for export/import functions.
"""
struct JLD2Tag <: AbstractTag end

"""
$(TYPEDEF)

JSON tag for export/import functions.
"""
struct JSON3Tag <: AbstractTag end
