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

# Throws

- `Exceptions.PreconditionError`: If variable has already been set
- `Exceptions.PreconditionError`: If objective has already been set
- `Exceptions.PreconditionError`: If dynamics has already been set
- `Exceptions.IncorrectArgument`: If number of component names ≠ q (when q > 0)
- `Exceptions.IncorrectArgument`: If name is empty (when q > 0)
- `Exceptions.IncorrectArgument`: If any component name is empty (when q > 0)
- `Exceptions.IncorrectArgument`: If name is one of the component names (when q > 0)
- `Exceptions.IncorrectArgument`: If component names contain duplicates (when q > 0)
- `Exceptions.IncorrectArgument`: If name conflicts with existing names in other components (when q > 0)
- `Exceptions.IncorrectArgument`: If any component name conflicts with existing names (when q > 0)
"""
function variable!(
    ocp::PreModel,
    q::Dimension,
    name::T1=__variable_name(q),
    components_names::Vector{T2}=__variable_components(q, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}
    Core.@ensure __is_variable_empty(ocp) Exceptions.PreconditionError(
        "Variable already set",
        reason="variable has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing variable definition",
        context="variable! function - duplicate definition check",
    )

    Core.@ensure (q ≤ 0) || (size(components_names, 1) == q) Exceptions.IncorrectArgument(
        "Component names count mismatch",
        got="$(size(components_names, 1)) names for dimension $q",
        expected="exactly $q component names",
        suggestion="Use variable!(ocp, q, name, [\"v1\", \"v2\", ..., \"v$q\"]) or omit for auto-generation",
        context="variable!(ocp, q=$q, components_names=[...]) - validating names count",
    )

    Core.@ensure !__is_objective_set(ocp) Exceptions.PreconditionError(
        "Variable must be set before objective",
        reason="objective has already been defined but variable is not set yet",
        suggestion="Call variable!(ocp, dimension) before objective!(ocp, ...)",
        context="variable! function - objective ordering check",
    )

    Core.@ensure !__is_dynamics_set(ocp) Exceptions.PreconditionError(
        "Variable must be set before dynamics",
        reason="dynamics have already been defined but variable is not set yet",
        suggestion="Call variable!(ocp, dimension) before dynamics!(ocp, ...)",
        context="variable! function - dynamics ordering check",
    )

    # NEW: Comprehensive name validation (only if q > 0)
    if q > 0
        __validate_name_uniqueness(ocp, string(name), string.(components_names), :variable)
    end

    ocp.variable = if q == 0
        EmptyVariableModel()
    else
        VariableModel(string(name), string.(components_names))
    end

    return nothing
end

# Getters for VariableModel/VariableModelSolution/EmptyVariableModel are now in
# src/Components/accessors.jl.
