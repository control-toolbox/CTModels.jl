# ------------------------------------------------------------------------------ #
# Accessor methods on component types
# (State, Control, Variable, Definition)
# ------------------------------------------------------------------------------ #

# --- StateModel ---

"""
$(TYPEDSIGNATURES)

Get the name of the state from the state model.

# Returns
- `String`: The state name.

See also: [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref).
"""
function name(model::StateModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the component names of the state from the state model.

# Returns
- `Vector{String}`: The state component names.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref).
"""
function components(model::StateModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the dimension of the state from the state model.

# Returns
- `Dimension`: The state dimension (number of components).

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref).
"""
function dimension(model::StateModel)::Dimension
    return length(components(model))
end

# --- StateModelSolution ---

"""
$(TYPEDSIGNATURES)

Get the name of the state from the state model solution.

# Returns
- `String`: The state name.

See also: [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref), [`CTModels.Components.value`](@ref).
"""
function name(model::StateModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the component names of the state from the state model solution.

# Returns
- `Vector{String}`: The state component names.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref), [`CTModels.Components.value`](@ref).
"""
function components(model::StateModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the dimension of the state from the state model solution.

# Returns
- `Dimension`: The state dimension (number of components).

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.value`](@ref).
"""
function dimension(model::StateModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Get the state function from the state model solution.

# Returns
- `TS`: A function `t -> x(t)` returning the state vector at time `t`.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref).
"""
function value(model::StateModelSolution{TS})::TS where {TS<:Function}
    return model.value
end

# --- ControlModel ---

"""
$(TYPEDSIGNATURES)

Get the name of the control variable.

# Returns
- `String`: The control name.

See also: [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref).
"""
function name(model::ControlModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the names of the control components.

# Returns
- `Vector{String}`: The control component names.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref).
"""
function components(model::ControlModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the control input dimension.

# Returns
- `Dimension`: The control dimension (number of components).

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref).
"""
function dimension(model::ControlModel)::Dimension
    return length(components(model))
end

# --- ControlModelSolution ---

"""
$(TYPEDSIGNATURES)

Get the name of the control variable from the solution.

# Returns
- `String`: The control name.

See also: [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref), [`CTModels.Components.value`](@ref), [`CTModels.Components.interpolation`](@ref).
"""
function name(model::ControlModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the names of the control components from the solution.

# Returns
- `Vector{String}`: The control component names.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref), [`CTModels.Components.value`](@ref), [`CTModels.Components.interpolation`](@ref).
"""
function components(model::ControlModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the control input dimension from the solution.

# Returns
- `Dimension`: The control dimension (number of components).

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.value`](@ref), [`CTModels.Components.interpolation`](@ref).
"""
function dimension(model::ControlModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Get the control function associated with the solution.

# Returns
- `TS`: A function `t -> u(t)` returning the control vector at time `t`.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.interpolation`](@ref).
"""
function value(model::ControlModelSolution{TS})::TS where {TS<:Function}
    return model.value
end

"""
$(TYPEDSIGNATURES)

Get the interpolation type for the control.

# Returns
- `Symbol`: The interpolation type (`:constant` or `:linear`).

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.value`](@ref).
"""
function interpolation(model::ControlModelSolution)::Symbol
    return model.interpolation
end

# --- EmptyControlModel ---

"""
$(TYPEDSIGNATURES)

Return an empty string, since no control is defined.

# Returns
- `String`: An empty string.
"""
function name(::EmptyControlModel)::String
    return ""
end

"""
$(TYPEDSIGNATURES)

Return an empty vector since there are no control components defined.

# Returns
- `Vector{String}`: An empty vector.
"""
function components(::EmptyControlModel)::Vector{String}
    return String[]
end

"""
$(TYPEDSIGNATURES)

Return `0` since no control is defined.

# Returns
- `Dimension`: Zero.
"""
function dimension(::EmptyControlModel)::Dimension
    return 0
end

# --- VariableModel ---

"""
$(TYPEDSIGNATURES)

Return the name of the variable stored in the model.

# Returns
- `String`: The variable name.

See also: [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref).
"""
function name(model::VariableModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.

# Returns
- `Vector{String}`: The variable component names.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref).
"""
function components(model::VariableModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Return the dimension (number of components) of the variable.

# Returns
- `Dimension`: The variable dimension.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref).
"""
function dimension(model::VariableModel)::Dimension
    return length(components(model))
end

# --- VariableModelSolution ---

"""
$(TYPEDSIGNATURES)

Return the name of the variable stored in the model solution.

# Returns
- `String`: The variable name.

See also: [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref), [`CTModels.Components.value`](@ref).
"""
function name(model::VariableModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Return the names of the components from the variable solution.

# Returns
- `Vector{String}`: The variable component names.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref), [`CTModels.Components.value`](@ref).
"""
function components(model::VariableModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Return the number of components in the variable solution.

# Returns
- `Dimension`: The variable dimension.

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.value`](@ref).
"""
function dimension(model::VariableModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Return the value stored in the variable solution model.

# Returns
- `TS`: The optimisation variable value (scalar or vector).

See also: [`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref).
"""
function value(model::VariableModelSolution{TS})::TS where {TS<:Union{ctNumber,ctVector}}
    return model.value
end

# --- EmptyVariableModel ---

"""
$(TYPEDSIGNATURES)

Return an empty string, since no variable is defined.

# Returns
- `String`: An empty string.
"""
function name(::EmptyVariableModel)::String
    return ""
end

"""
$(TYPEDSIGNATURES)

Return an empty vector since there are no variable components defined.

# Returns
- `Vector{String}`: An empty vector.
"""
function components(::EmptyVariableModel)::Vector{String}
    return String[]
end

"""
$(TYPEDSIGNATURES)

Return `0` since no variable is defined.

# Returns
- `Dimension`: Zero.
"""
function dimension(::EmptyVariableModel)::Dimension
    return 0
end

# --- FixedTimeModel / FreeTimeModel ---

"""
$(TYPEDSIGNATURES)

Get the name of the time from the fixed time model.

# Returns
- `String`: The time name.

See also: [`CTModels.Components.initial_time`](@ref).
"""
function name(model::FixedTimeModel{<:Time})::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the name of the time from the free time model.

# Returns
- `String`: The time name.

See also: [`CTModels.Components.index`](@ref), [`CTModels.Components.initial_time`](@ref).
"""
function name(model::FreeTimeModel)::String
    return model.name
end

# --- Definition ---

"""
$(TYPEDSIGNATURES)

Return an empty block expression for an [`CTModels.Components.EmptyDefinition`](@ref).

# Returns
- `Expr`: An empty block expression `:(begin end)`.

See also: [`CTModels.Components.expression`](@ref).
"""
expression(::EmptyDefinition)::Expr = :(begin end)

"""
$(TYPEDSIGNATURES)

Return the symbolic expression wrapped by a [`CTModels.Components.Definition`](@ref).

# Returns
- `Expr`: The symbolic expression defining the problem.

See also: [`CTModels.Components.expression`](@ref).
"""
expression(d::Definition)::Expr = d.expr
