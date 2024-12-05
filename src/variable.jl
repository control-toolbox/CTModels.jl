"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the variables.
The default value is `"v"`.
"""
__variable_name()::String = "v"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the variables.
The default value is `["v"]` for a one dimensional variable, and `["v₁", "v₂", ...]` for a multi dimensional variable.
"""
__variable_components(q::Dimension, name::String)::Vector{String} =
    q > 1 ? [name * CTBase.ctindices(i) for i ∈ range(1, q)] : [name]

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
    ocp::OptimalControlModelMutable,
    q::Dimension,
    name::T1 = __variable_name(),
    components_names::Vector{T2} = __variable_components(q, string(name)),
)::Nothing where {T1<:Union{String, Symbol}, T2<:Union{String, Symbol}}

    # checkings
    __is_variable_set(ocp) && throw(CTBase.UnauthorizedCall("the variable has already been set."))
    (q > 1) &&
        (size(components_names, 1) ≠ q) &&
        throw(
            CTBase.IncorrectArgument(
                "the number of variable names must be equal to the variable dimension",
            ),
        )

    # the objective must not be set before the variable
    __is_objective_set(ocp) && throw(CTBase.UnauthorizedCall("the objective must be set after the variable."))

    # the dynamics must not be set before the variable
    __is_dynamics_set(ocp) && throw(CTBase.UnauthorizedCall("the dynamics must be set after the variable."))

    # set the variable
    ocp.variable = VariableModel{q}(string(name), SVector{q}(string.(components_names)))
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# from AbstractVariableModel
dimension(::EmptyVariableModel)::Dimension = 0
(dimension(::VariableModel{Q})::Dimension) where Q = Q
name(model::VariableModel)::String = model.name
components(model::VariableModel)::Vector{String} = Vector(model.components)

# from OptimalControlModel
(variable(model::OptimalControlModel{T, S, C, V, O})::V) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    O<:AbstractObjectiveModel} = model.variable
variable_dimension(model::OptimalControlModel)::Dimension = dimension(variable(model))
variable_name(model::OptimalControlModel)::String = name(variable(model))
variable_components(model::OptimalControlModel)::Vector{String} = components(variable(model))