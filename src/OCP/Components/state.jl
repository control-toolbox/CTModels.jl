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

# Throws

- `CTBase.UnauthorizedCall`: If state has already been set
- `Exceptions.IncorrectArgument`: If n ≤ 0
- `Exceptions.IncorrectArgument`: If number of component names ≠ n
- `Exceptions.IncorrectArgument`: If name is empty
- `Exceptions.IncorrectArgument`: If any component name is empty
- `Exceptions.IncorrectArgument`: If name is one of the component names
- `Exceptions.IncorrectArgument`: If component names contain duplicates
- `Exceptions.IncorrectArgument`: If name conflicts with existing names in other components
- `Exceptions.IncorrectArgument`: If any component name conflicts with existing names
"""
function state!(
    ocp::PreModel,
    n::Dimension,
    name::T1=__state_name(),
    components_names::Vector{T2}=__state_components(n, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}

    # checks
    @ensure !__is_state_set(ocp) CTBase.UnauthorizedCall("the state has already been set.")
    @ensure n > 0 Exceptions.IncorrectArgument(
        "Invalid state dimension",
        got="n=$n",
        expected="n > 0",
        suggestion="Provide a positive integer for the state dimension",
        context="state!(ocp, n=$n, name=\"$name\") - validating n parameter"
    )
    @ensure size(components_names, 1) == n Exceptions.IncorrectArgument(
        "State component names count mismatch",
        got="$(size(components_names, 1)) component names",
        expected="$n component names (matching state dimension)",
        suggestion="Provide exactly $n component names or omit to use auto-generated names",
        context="state! components validation"
    )

    # NEW: Comprehensive name validation
    __validate_name_uniqueness(ocp, string(name), string.(components_names), :state)

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
