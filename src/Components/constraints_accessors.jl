# ------------------------------------------------------------------------------ #
# Accessor methods on ConstraintsModel
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return if the constraints model is empty or not.
"""
function Base.isempty(model::ConstraintsModel)::Bool
    return length(path_constraints_nl(model)[1]) == 0 &&
           length(boundary_constraints_nl(model)[1]) == 0 &&
           length(state_constraints_box(model)[1]) == 0 &&
           length(control_constraints_box(model)[1]) == 0 &&
           length(variable_constraints_box(model)[1]) == 0
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear path constraints from the model.
"""
function path_constraints_nl(
    model::ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple}
) where {TP}
    return model.path_nl
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear boundary constraints from the model.
"""
function boundary_constraints_nl(
    model::ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple}
) where {TB}
    return model.boundary_nl
end

"""
$(TYPEDSIGNATURES)

Get the state box constraints from the model.
"""
function state_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple}
) where {TS}
    return model.state_box
end

"""
$(TYPEDSIGNATURES)

Get the control box constraints from the model.
"""
function control_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple}
) where {TC}
    return model.control_box
end

"""
$(TYPEDSIGNATURES)

Get the variable box constraints from the model.
"""
function variable_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV}
) where {TV}
    return model.variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
function dim_path_constraints_nl(model::ConstraintsModel)::Dimension
    return length(path_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear boundary constraints.
"""
function dim_boundary_constraints_nl(model::ConstraintsModel)::Dimension
    return length(boundary_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of state box constraints.
"""
function dim_state_constraints_box(model::ConstraintsModel)::Dimension
    return length(state_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of control box constraints.
"""
function dim_control_constraints_box(model::ConstraintsModel)::Dimension
    return length(control_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of variable box constraints.
"""
function dim_variable_constraints_box(model::ConstraintsModel)::Dimension
    return length(variable_constraints_box(model)[1])
end
