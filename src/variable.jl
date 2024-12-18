"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the variables.
The default value is `"v"`.
"""
function __variable_name(q::Dimension)::String
    return q > 0 ? "v" : ""
end

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the variables.
The default value is `["v"]` for a one dimensional variable, and `["v₁", "v₂", ...]` for a multi dimensional variable.
"""
function __variable_components(q::Dimension, name::String)::Vector{String}
    if q == 0
        return String[]
    else
        return q > 1 ? [name * CTBase.ctindices(i) for i in range(1, q)] : [name]
    end
end

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

# from AbstractVariableModel
name(model::VariableModel)::String = model.name
name(::EmptyVariableModel)::String = ""
components(model::VariableModel)::Vector{String} = model.components
components(::EmptyVariableModel)::Vector{String} = String[]
(dimension(model::VariableModel)::Dimension) = length(components(model))
dimension(::EmptyVariableModel)::Dimension = 0

# from Model
variable_name(ocp::Model)::String = name(ocp.variable)
variable_components(ocp::Model)::Vector{String} = components(ocp.variable)
variable_dimension(ocp::Model)::Dimension = dimension(ocp.variable)
