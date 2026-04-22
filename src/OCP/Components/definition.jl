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
# EXPRESSION GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return an empty block expression for an [`EmptyDefinition`](@ref).

Since no symbolic definition was attached, the canonical empty expression
`:(begin end)` (equivalent to `quote end`) is returned.

# Arguments

- `::EmptyDefinition`: The empty definition sentinel.

# Returns

- `Expr`: An empty block expression `:(begin end)`.
"""
expression(::EmptyDefinition)::Expr = :(
    begin end
)

"""
$(TYPEDSIGNATURES)

Return the symbolic expression wrapped by a [`Definition`](@ref).

# Arguments

- `d::Definition`: The definition holding the symbolic expression.

# Returns

- `Expr`: The `Expr` value stored in `d.expr`.
"""
expression(d::Definition)::Expr = d.expr
