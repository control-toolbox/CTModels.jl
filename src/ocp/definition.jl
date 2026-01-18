# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem.

# Arguments

- `ocp::PreModel`: The pre-model to modify.
- `definition::Expr`: The symbolic expression defining the problem.

# Returns

- `Nothing`
"""
function definition!(ocp::PreModel, definition::Expr)::Nothing
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

- `Expr`: The symbolic expression defining the problem.
"""
function definition(ocp::Model)::Expr
    return ocp.definition
end

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem or `nothing`.

# Arguments

- `ocp::PreModel`: The pre-model (may not have a definition set).

# Returns

- `Union{Expr, Nothing}`: The symbolic expression or `nothing` if not set.
"""
function definition(ocp::PreModel)
    return ocp.definition
end
