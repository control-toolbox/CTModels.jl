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
    name::T1=__state_name(),
    components_names::Vector{T2}=__state_components(n, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}

    # checkings
    __is_state_set(ocp) && throw(CTBase.UnauthorizedCall("the state has already been set."))

    (n > 0) &&
        (size(components_names, 1) ≠ n) &&
        throw(
            CTBase.IncorrectArgument(
                "the number of state names must be equal to the state dimension"
            ),
        )

    # if the dimension is 0 then throw an error
    if n == 0
        throw(CTBase.IncorrectArgument("the state dimension must be greater than 0"))
    end

    # set the state
    ocp.state = StateModel(string(name), string.(components_names))

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Get the name of the state from the state model.
"""
function name(model::StateModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the components names of the state from the state model.
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

"""
$(TYPEDSIGNATURES)

Get the name of the state from the state model solution.
"""
function name(model::StateModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the components names of the state from the state model solution.
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
