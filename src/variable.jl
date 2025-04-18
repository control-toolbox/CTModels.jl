"""
$(TYPEDSIGNATURES)

Define the variable dimension and possibly the names of each component.

!!! note

    You can use variable! once to set the variable dimension.

# Examples
```@example
julia> variable!(ocp, 1, "v")
julia> variable!(ocp, 2, "v", [ "v₁", "v₂" ])
```
"""
function variable!(
    ocp::PreModel,
    q::Dimension,
    name::T1=__variable_name(q),
    components_names::Vector{T2}=__variable_components(q, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}

    # checkings
    __is_variable_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the variable has already been set."))

    (q > 0) &&
        (size(components_names, 1) ≠ q) &&
        throw(
            CTBase.IncorrectArgument(
                "the number of variable names must be equal to the variable dimension"
            ),
        )

    # the objective must not be set before the variable
    __is_objective_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the objective must be set after the variable."))

    # the dynamics must not be set before the variable
    __is_dynamics_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the dynamics must be set after the variable."))

    # set the variable
    # if the dimension is 0 then set an empty variable
    if q == 0
        ocp.variable = EmptyVariableModel()
    else
        ocp.variable = VariableModel(string(name), string.(components_names))
    end

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Get the variable name from the variable model.
"""
function name(model::VariableModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the variable name from the variable model solution.
"""
function name(model::VariableModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the variable name from the empty variable model. Return an empty string.
"""
function name(::EmptyVariableModel)::String
    return ""
end

"""
$(TYPEDSIGNATURES)

Get the components names of the variable from the variable model.
"""
function components(model::VariableModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the components names of the variable from the variable model solution.
"""
function components(model::VariableModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Get the components names of the variable from the empty variable model. Return an empty vector.
"""
function components(::EmptyVariableModel)::Vector{String}
    return String[]
end

"""
$(TYPEDSIGNATURES)

Get the variable dimension from the variable model.
"""
function dimension(model::VariableModel)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Get the variable dimension from the variable model solution.
"""
function dimension(model::VariableModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Get the variable dimension from the empty variable model. Return 0.
"""
function dimension(::EmptyVariableModel)::Dimension
    return 0
end

"""
$(TYPEDSIGNATURES)

Get the variable from the variable model solution.
"""
function value(model::VariableModelSolution{TS})::TS where {TS<:Union{ctNumber,ctVector}}
    return model.value
end
