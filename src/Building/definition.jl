# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem from a raw `Expr`.

The expression is wrapped in a [`CTModels.Components.Definition`](@ref) and stored on the pre-model.

# Arguments

- `ocp::PreModel`: The pre-model to modify.
- `definition::Expr`: The symbolic expression defining the problem.

# Returns

- `Nothing`
"""
function definition!(ocp::PreModel, definition::Expr)::Nothing
    ocp.definition = Definition(definition)
    return nothing
end

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem from an existing
[`CTModels.Components.AbstractDefinition`](@ref) value (either a [`CTModels.Components.Definition`](@ref) or an
[`CTModels.Components.EmptyDefinition`](@ref)).

# Arguments

- `ocp::PreModel`: The pre-model to modify.
- `definition::AbstractDefinition`: The definition value to store.

# Returns

- `Nothing`
"""
function definition!(ocp::PreModel, definition::AbstractDefinition)::Nothing
    ocp.definition = definition
    return nothing
end

# expression() getters for Definition/EmptyDefinition are now in
# src/Components/accessors.jl.
