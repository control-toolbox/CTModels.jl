"""
$(TYPEDSIGNATURES)

Used to set the default value of the name of the state.
The default value is `"x"`.
"""
__state_name()::String = "x"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the states.
The default value is `["x"]` for a one dimensional state, and `["x₁", "x₂", ...]` for a multi dimensional state.
"""
__state_components(n::Dimension, name::String)::Vector{String} =
    n > 1 ? [name * CTBase.ctindices(i) for i ∈ range(1, n)] : [name]

"""
$(TYPEDSIGNATURES)

Define the state dimension and possibly the names of each component.

!!! note

    You must use state! only once to set the state dimension.

# Examples

```@example
julia> state!(ocp, 1)
julia> state_dimension(ocp)
1
julia> state_components(ocp)
["x"]

julia> state!(ocp, 1, "y")
julia> state_dimension(ocp)
1
julia> state_components(ocp)
["y"]

julia> state!(ocp, 2)
julia> state_dimension(ocp)
2
julia> state_components(ocp)
["x₁", "x₂"]

julia> state!(ocp, 2, :y)
julia> state_dimension(ocp)
2
julia> state_components(ocp)
["y₁", "y₂"]

julia> state!(ocp, 2, "y")
julia> state_dimension(ocp)
2
julia> state_components(ocp)
["y₁", "y₂"]

julia> state!(ocp, 2, "y", ["u", "v"])
julia> state_dimension(ocp)
2
julia> state_components(ocp)
["u", "v"]

julia> state!(ocp, 2, "y", [:u, :v])
julia> state_dimension(ocp)
2
julia> state_components(ocp)
["u", "v"]
```
"""
function state!(
    ocp::PreModel,
    n::Dimension,
    name::T1 = __state_name(),
    components_names::Vector{T2} = __state_components(n, string(name)),
)::Nothing where {T1<:Union{String, Symbol}, T2<:Union{String, Symbol}}

    # checkings
    __is_state_set(ocp) && throw(CTBase.UnauthorizedCall("the state has already been set."))
    (n > 1) &&
        (size(components_names, 1) ≠ n) &&
        throw(CTBase.IncorrectArgument("the number of state names must be equal to the state dimension"))

    # set the state
    ocp.state = StateModel(string(name), string.(components_names))

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# from StateModel
name(ocp::StateModel)::String = ocp.name
components(ocp::StateModel)::Vector{String} = ocp.components
(dimension(ocp::StateModel)::Dimension) = length(components(ocp))

# from Model
(state(ocp::Model{T, S, C, V, D, O, B})::S) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:ConstraintsDictType} = ocp.state
state_name(ocp::Model)::String = name(state(ocp))
state_components(ocp::Model)::Vector{String} = components(state(ocp))
state_dimension(ocp::Model)::Dimension = dimension(state(ocp))