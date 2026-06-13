# ------------------------------------------------------------------------------ #
# Accessor methods on component types
# (State, Control, Variable, Definition)
# ------------------------------------------------------------------------------ #

# --- StateModel ---

"""
$(TYPEDSIGNATURES)

Get the name of the state from the state model.
"""
function name(model::StateModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the component names of the state from the state model.
"""
function components(model::StateModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the dimension of the state from the state model.
"""
function dimension(model::StateModel)::Dimension
    return length(components(model))
end

# --- StateModelSolution ---

"""
$(TYPEDSIGNATURES)

Get the name of the state from the state model solution.
"""
function name(model::StateModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the component names of the state from the state model solution.
"""
function components(model::StateModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the dimension of the state from the state model solution.
"""
function dimension(model::StateModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Get the state function from the state model solution.
"""
function value(model::StateModelSolution{TS})::TS where {TS<:Function}
    return model.value
end

# --- ControlModel ---

"""
$(TYPEDSIGNATURES)

Get the name of the control variable.
"""
function name(model::ControlModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the names of the control components.
"""
function components(model::ControlModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the control input dimension.
"""
function dimension(model::ControlModel)::Dimension
    return length(components(model))
end

# --- ControlModelSolution ---

"""
$(TYPEDSIGNATURES)

Get the name of the control variable from the solution.
"""
function name(model::ControlModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the names of the control components from the solution.
"""
function components(model::ControlModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the control input dimension from the solution.
"""
function dimension(model::ControlModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Get the control function associated with the solution.
"""
function value(model::ControlModelSolution{TS})::TS where {TS<:Function}
    return model.value
end

"""
$(TYPEDSIGNATURES)

Get the interpolation type for the control.
"""
function interpolation(model::ControlModelSolution)::Symbol
    return model.interpolation
end

# --- EmptyControlModel ---

"""
$(TYPEDSIGNATURES)

Return an empty string, since no control is defined.
"""
function name(::EmptyControlModel)::String
    return ""
end

"""
$(TYPEDSIGNATURES)

Return an empty vector since there are no control components defined.
"""
function components(::EmptyControlModel)::Vector{String}
    return String[]
end

"""
$(TYPEDSIGNATURES)

Return `0` since no control is defined.
"""
function dimension(::EmptyControlModel)::Dimension
    return 0
end

# --- VariableModel ---

"""
$(TYPEDSIGNATURES)

Return the name of the variable stored in the model.
"""
function name(model::VariableModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.
"""
function components(model::VariableModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Return the dimension (number of components) of the variable.
"""
function dimension(model::VariableModel)::Dimension
    return length(components(model))
end

# --- VariableModelSolution ---

"""
$(TYPEDSIGNATURES)

Return the name of the variable stored in the model solution.
"""
function name(model::VariableModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Return the names of the components from the variable solution.
"""
function components(model::VariableModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Return the number of components in the variable solution.
"""
function dimension(model::VariableModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Return the value stored in the variable solution model.
"""
function value(model::VariableModelSolution{TS})::TS where {TS<:Union{ctNumber,ctVector}}
    return model.value
end

# --- EmptyVariableModel ---

"""
$(TYPEDSIGNATURES)

Return an empty string, since no variable is defined.
"""
function name(::EmptyVariableModel)::String
    return ""
end

"""
$(TYPEDSIGNATURES)

Return an empty vector since there are no variable components defined.
"""
function components(::EmptyVariableModel)::Vector{String}
    return String[]
end

"""
$(TYPEDSIGNATURES)

Return `0` since no variable is defined.
"""
function dimension(::EmptyVariableModel)::Dimension
    return 0
end

# --- FixedTimeModel / FreeTimeModel ---

"""
$(TYPEDSIGNATURES)

Get the name of the time from the fixed time model.
"""
function name(model::FixedTimeModel{<:Time})::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the name of the time from the free time model.
"""
function name(model::FreeTimeModel)::String
    return model.name
end

# --- Definition ---

"""
$(TYPEDSIGNATURES)

Return an empty block expression for an [`EmptyDefinition`](@ref CTModels.Components.EmptyDefinition).
"""
expression(::EmptyDefinition)::Expr = :(begin end)

"""
$(TYPEDSIGNATURES)

Return the symbolic expression wrapped by a [`Definition`](@ref CTModels.Components.Definition).
"""
expression(d::Definition)::Expr = d.expr
