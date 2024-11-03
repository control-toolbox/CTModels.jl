"""
$(TYPEDSIGNATURES)

Used to set the default value of the name of the state.
The default value is `"x"`.
"""
__state_name() = "x"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the states.
The default value is `["x"]` for a one dimensional state, and `["x₁", "x₂", ...]` for a multi dimensional state.
"""
__state_components(n::Dimension, name::String) =
    n > 1 ? [name * CTBase.ctindices(i) for i ∈ range(1, n)] : [name]

"""
$(TYPEDSIGNATURES)

"""
__is_state_set(ocp::OptimalControlModelMutable) = !isnothing(ocp.state)

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
    ocp::OptimalControlModelMutable,
    n::Dimension,
    name::T1 = __state_name(),
    components_names::Vector{T2} = __state_components(n, string(name)),
) where {T1<:Union{String, Symbol}, T2<:Union{String, Symbol}}

    # checkings
    __is_state_set(ocp) && throw(CTBase.UnauthorizedCall("the state has already been set."))
    (n > 1) &&
        (size(components_names, 1) ≠ n) &&
        throw(CTBase.IncorrectArgument("the number of state names must be equal to the state dimension"))

    # set the state
    ocp.state = StateModel(n, string(name), string.(components_names))
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# from StateModel
dimension(model::StateModel) = model.dimension
name(model::StateModel) = model.name
components(model::StateModel) = model.components

# from OptimalControlModel
state(model::OptimalControlModel) = model.state
state_dimension(model::OptimalControlModel) = dimension(state(model))
state_name(model::OptimalControlModel) = name(state(model))
state_components(model::OptimalControlModel) = components(state(model))

# from OptimalControlModelMutable
state(model::OptimalControlModelMutable) = model.state
state_dimension(model::OptimalControlModelMutable) = dimension(state(model))
state_name(model::OptimalControlModelMutable) = name(state(model))
state_components(model::OptimalControlModelMutable) = components(state(model))