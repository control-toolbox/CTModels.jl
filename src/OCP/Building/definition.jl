# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem from a raw `Expr`.

The expression is wrapped in a [`Definition`](@ref) and stored on the pre-model.

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
[`AbstractDefinition`](@ref) value (either a [`Definition`](@ref) or an
[`EmptyDefinition`](@ref)).

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

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem.

# Arguments

- `ocp::Model`: The built optimal control problem model.

# Returns

- `AbstractDefinition`: The [`Definition`](@ref) wrapping the symbolic
  expression, or an [`EmptyDefinition`](@ref) if the user did not attach one
  before [`build`](@ref).
"""
function definition(ocp::Model)::AbstractDefinition
    return ocp.definition
end

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem.

# Arguments

- `ocp::PreModel`: The pre-model.

# Returns

- `AbstractDefinition`: [`Definition`](@ref) when set via
  [`definition!`](@ref), [`EmptyDefinition`](@ref) by default.
"""
function definition(ocp::PreModel)::AbstractDefinition
    return ocp.definition
end
