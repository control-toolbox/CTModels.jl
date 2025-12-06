# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem.

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

"""
function definition(ocp::Model)::Expr
    return ocp.definition
end

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem or `nothing`.

"""
function definition(ocp::PreModel)
    return ocp.definition
end
