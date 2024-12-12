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
    ocp::PreModel,
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
    ocp.variable = VariableModel(string(name), string.(components_names))

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# from AbstractVariableModel
name(ocp::VariableModel)::String = ocp.name
components(ocp::VariableModel)::Vector{String} = ocp.components
dimension(::EmptyVariableModel)::Dimension = 0
(dimension(ocp::VariableModel)::Dimension) = length(components(ocp))

# from Model
(variable(ocp::Model{T, S, C, V, D, O, B})::V) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:ConstraintsDictType} = ocp.variable
variable_name(ocp::Model)::String = name(variable(ocp))
variable_components(ocp::Model)::Vector{String} = components(variable(ocp))
variable_dimension(ocp::Model)::Dimension = dimension(variable(ocp))