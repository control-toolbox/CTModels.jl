# ------------------------------------------------------------------------------ #
# Accessor methods on ConstraintsModel
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return if the constraints model is empty or not.

# Returns
- `Bool`: `true` if all constraint types are empty, `false` otherwise.

See also: [`CTModels.Components.path_constraints_nl`](@ref), [`CTModels.Components.state_constraints_box`](@ref).
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

# Returns
- `TP`: Tuple of nonlinear path constraints `(lb, f!, ub, labels)`.

See also: [`CTModels.Components.boundary_constraints_nl`](@ref), [`CTModels.Components.dim_path_constraints_nl`](@ref).
"""
function path_constraints_nl(
    model::ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple}
) where {TP}
    return model.path_nl
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear boundary constraints from the model.

# Returns
- `TB`: Tuple of nonlinear boundary constraints `(lb, f!, ub, labels)`.

See also: [`CTModels.Components.path_constraints_nl`](@ref), [`CTModels.Components.dim_boundary_constraints_nl`](@ref).
"""
function boundary_constraints_nl(
    model::ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple}
) where {TB}
    return model.boundary_nl
end

"""
$(TYPEDSIGNATURES)

Get the state box constraints from the model.

# Returns
- `TS`: Tuple of state box constraints `(lb, ind, ub, labels, aliases)`.

See also: [`CTModels.Components.control_constraints_box`](@ref), [`CTModels.Components.dim_state_constraints_box`](@ref).
"""
function state_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple}
) where {TS}
    return model.state_box
end

"""
$(TYPEDSIGNATURES)

Get the control box constraints from the model.

# Returns
- `TC`: Tuple of control box constraints `(lb, ind, ub, labels, aliases)`.

See also: [`CTModels.Components.state_constraints_box`](@ref), [`CTModels.Components.dim_control_constraints_box`](@ref).
"""
function control_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple}
) where {TC}
    return model.control_box
end

"""
$(TYPEDSIGNATURES)

Get the variable box constraints from the model.

# Returns
- `TV`: Tuple of variable box constraints `(lb, ind, ub, labels, aliases)`.

See also: [`CTModels.Components.state_constraints_box`](@ref), [`CTModels.Components.dim_variable_constraints_box`](@ref).
"""
function variable_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV}
) where {TV}
    return model.variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.

# Returns
- `Dimension`: The number of nonlinear path constraints.

See also: [`CTModels.Components.path_constraints_nl`](@ref), [`CTModels.Components.dim_boundary_constraints_nl`](@ref).
"""
function dim_path_constraints_nl(model::ConstraintsModel)::Dimension
    return length(path_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear boundary constraints.

# Returns
- `Dimension`: The number of nonlinear boundary constraints.

See also: [`CTModels.Components.boundary_constraints_nl`](@ref), [`CTModels.Components.dim_path_constraints_nl`](@ref).
"""
function dim_boundary_constraints_nl(model::ConstraintsModel)::Dimension
    return length(boundary_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of state box constraints.

# Returns
- `Dimension`: The number of state box constraints.

See also: [`CTModels.Components.state_constraints_box`](@ref), [`CTModels.Components.dim_control_constraints_box`](@ref).
"""
function dim_state_constraints_box(model::ConstraintsModel)::Dimension
    return length(state_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of control box constraints.

# Returns
- `Dimension`: The number of control box constraints.

See also: [`CTModels.Components.control_constraints_box`](@ref), [`CTModels.Components.dim_state_constraints_box`](@ref).
"""
function dim_control_constraints_box(model::ConstraintsModel)::Dimension
    return length(control_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of variable box constraints.

# Returns
- `Dimension`: The number of variable box constraints.

See also: [`CTModels.Components.variable_constraints_box`](@ref), [`CTModels.Components.dim_state_constraints_box`](@ref).
"""
function dim_variable_constraints_box(model::ConstraintsModel)::Dimension
    return length(variable_constraints_box(model)[1])
end
