"""
$(TYPEDSIGNATURES)

Define a new variable in the optimal control problem `ocp` with dimension `q`.

This function registers a named variable (e.g. "state", "control", or other) to be used in the problem definition. You may optionally specify a name and individual component names.

!!! note
    You can call `variable!` only once. It must be called before setting the objective or dynamics.

# Arguments
- `ocp`: The `PreModel` where the variable is registered.
- `q`: The dimension of the variable (number of components).
- `name`: A name for the variable (default: auto-generated from `q`).
- `components_names`: A vector of strings or symbols for each component (default: `["v₁", "v₂", ...]`).

# Examples
```julia-repl
julia> variable!(ocp, 1, "v")
julia> variable!(ocp, 2, "v", ["v₁", "v₂"])
```
"""
function variable!(
    ocp::PreModel,
    q::Dimension,
    name::T1=__variable_name(q),
    components_names::Vector{T2}=__variable_components(q, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}
    @ensure !__is_variable_set(ocp) CTBase.UnauthorizedCall(
        "the variable has already been set."
    )

    @ensure (q ≤ 0) || (size(components_names, 1) == q) CTBase.IncorrectArgument(
        "the number of variable names must be equal to the variable dimension"
    )

    @ensure !__is_objective_set(ocp) CTBase.UnauthorizedCall(
        "the objective must be set after the variable."
    )

    @ensure !__is_dynamics_set(ocp) CTBase.UnauthorizedCall(
        "the dynamics must be set after the variable."
    )

    ocp.variable = if q == 0
        EmptyVariableModel()
    else
        VariableModel(string(name), string.(components_names))
    end

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the name of the variable stored in the model.
"""
function name(model::VariableModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Return the name of the variable stored in the model solution.
"""
function name(model::VariableModelSolution)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Return an empty string, since no variable is defined.
"""
function name(::EmptyVariableModel)::String
    return ""
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.
"""
function components(model::VariableModel)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Return the names of the components from the variable solution.
"""
function components(model::VariableModelSolution)::Vector{String}
    return model.components
end

"""
$(TYPEDSIGNATURES)

Return an empty vector since there are no variable components defined.
"""
function components(::EmptyVariableModel)::Vector{String}
    return String[]
end

"""
$(TYPEDSIGNATURES)

Return the dimension (number of components) of the variable.
"""
function dimension(model::VariableModel)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Return the number of components in the variable solution.
"""
function dimension(model::VariableModelSolution)::Dimension
    return length(components(model))
end

"""
$(TYPEDSIGNATURES)

Return `0` since no variable is defined.
"""
function dimension(::EmptyVariableModel)::Dimension
    return 0
end

"""
$(TYPEDSIGNATURES)

Return the value stored in the variable solution model.
"""
function value(model::VariableModelSolution{TS})::TS where {TS<:Union{ctNumber,ctVector}}
    return model.value
end
