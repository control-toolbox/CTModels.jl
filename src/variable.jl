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
name(model::VariableModel)::String = model.name
name(model::VariableModelSolution)::String = model.name
name(::EmptyVariableModel)::String = ""

components(model::VariableModel)::Vector{String} = model.components
components(model::VariableModelSolution)::Vector{String} = model.components
components(::EmptyVariableModel)::Vector{String} = String[]

dimension(model::VariableModel)::Dimension = length(components(model))
dimension(model::VariableModelSolution)::Dimension = length(components(model))
dimension(::EmptyVariableModel)::Dimension = 0

(value(model::VariableModelSolution{TS})::TS) where {TS} = model.value