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
expression(::EmptyDefinition)::Expr = :(begin end)

"""
$(TYPEDSIGNATURES)

Return the symbolic expression wrapped by a [`Definition`](@ref).

# Arguments

- `d::Definition`: The definition holding the symbolic expression.

# Returns

- `Expr`: The `Expr` value stored in `d.expr`.
"""
expression(d::Definition)::Expr = d.expr

"""
$(TYPEDSIGNATURES)

Return the symbolic expression of the model definition attached to the pre-model.

Delegates to [`expression`](@ref) on the underlying [`AbstractDefinition`](@ref):
returns `d.expr` if a [`Definition`](@ref) was set, or `:(begin end)` if the
definition is still an [`EmptyDefinition`](@ref).

# Arguments

- `ocp::PreModel`: The pre-model.

# Returns

- `Expr`: The symbolic expression, or `:(begin end)` if no definition was set.
"""
expression(ocp::PreModel)::Expr = expression(definition(ocp))

"""
$(TYPEDSIGNATURES)

Return the symbolic expression of the model definition of a built optimal control
problem.

Delegates to [`expression`](@ref) on the underlying [`AbstractDefinition`](@ref):
returns `d.expr` if a [`Definition`](@ref) was attached before [`build`](@ref),
or `:(begin end)` if the definition is an [`EmptyDefinition`](@ref).

# Arguments

- `ocp::Model`: The built optimal control problem model.

# Returns

- `Expr`: The symbolic expression, or `:(begin end)` if no definition was attached.
"""
expression(ocp::Model)::Expr = expression(definition(ocp))
