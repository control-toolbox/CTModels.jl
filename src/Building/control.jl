"""
$(TYPEDSIGNATURES)

Define the control input for a given optimal control problem model.

This function sets the control dimension and optionally allows specifying the control name and the names of its components.

!!! note
    This function should be called only once per model. Calling it again will raise an error.

# Arguments
- `ocp::PreModel`: The model to which the control will be added.
- `m::Dimension`: The control input dimension (must be greater than 0).
- `name::Union{String,Symbol}` (optional): The name of the control variable (default: `"u"`).
- `components_names::Vector{<:Union{String,Symbol}}` (optional): Names of the control components (default: automatically generated).

# Examples
```julia-repl
julia> control!(ocp, 1)
julia> control_dimension(ocp)
1
julia> control_components(ocp)
["u"]

julia> control!(ocp, 1, "v")
julia> control_components(ocp)
["v"]

julia> control!(ocp, 2)
julia> control_components(ocp)
["u₁", "u₂"]

julia> control!(ocp, 2, :v)
julia> control_components(ocp)
["v₁", "v₂"]

julia> control!(ocp, 2, "v", ["a", "b"])
julia> control_components(ocp)
["a", "b"]
```

# Throws

- `Exceptions.PreconditionError`: If control has already been set
- `Exceptions.IncorrectArgument`: If m ≤ 0
- `Exceptions.IncorrectArgument`: If number of component names ≠ m
- `Exceptions.IncorrectArgument`: If name is empty
- `Exceptions.IncorrectArgument`: If any component name is empty
- `Exceptions.IncorrectArgument`: If name is one of the component names
- `Exceptions.IncorrectArgument`: If component names contain duplicates
- `Exceptions.IncorrectArgument`: If name conflicts with existing names in other components
- `Exceptions.IncorrectArgument`: If any component name conflicts with existing names
"""
function control!(
    ocp::PreModel,
    m::Dimension,
    name::T1=__control_name(),
    components_names::Vector{T2}=__control_components(m, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}

    # checks using Core.@ensure
    Core.@ensure __is_control_empty(ocp) Exceptions.PreconditionError(
        "Control already set",
        reason="control has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing control definition",
        context="control! function - duplicate definition check",
    )
    Core.@ensure m > 0 Exceptions.IncorrectArgument(
        "Invalid dimension: must be positive",
        got="m=$m",
        expected="m > 0 (positive integer)",
        suggestion="Use control!(ocp, m=2) with m > 0",
        context="control!(ocp, m=$m, name=\"$name\") - validating dimension parameter",
    )
    Core.@ensure size(components_names, 1) == m Exceptions.IncorrectArgument(
        "Component names count mismatch",
        got="$(size(components_names, 1)) names for dimension $m",
        expected="exactly $m component names",
        suggestion="Use control!(ocp, m, name, [\"u1\", \"u2\", ..., \"u$m\"]) or omit for auto-generation",
        context="control!(ocp, m=$m, components_names=[...]) - validating names count",
    )

    # NEW: Comprehensive name validation
    __validate_name_uniqueness(ocp, string(name), string.(components_names), :control)

    # set the control
    ocp.control = ControlModel(string(name), string.(components_names))

    return nothing
end

# Getters for ControlModel/ControlModelSolution/EmptyControlModel are now in
# src/Components/accessors.jl.
