"""
$(TYPEDSIGNATURES)

Define the state dimension and possibly the names of each component.

!!! note

    You must use state! only once to set the state dimension.

# Arguments
- `ocp::PreModel`: The optimal control problem model.
- `n::Dimension`: The state dimension (number of state components).
- `name::Union{String,Symbol}` (optional): The name of the state variable (default: "x").
- `components_names::Vector{<:Union{String,Symbol}}` (optional): Names of the state components (default: automatically generated).

# Examples

Each call below starts from a fresh `PreModel` (`state!` may be used only once per
problem). The forms illustrate the default name, a custom name, and explicit component
names:

```julia-repl
julia> using CTModels

julia> ocp = PreModel(); state!(ocp, 1);

julia> state_dimension(ocp), state_components(ocp)
(1, ["x"])

julia> ocp = PreModel(); state!(ocp, 2);

julia> state_dimension(ocp), state_components(ocp)
(2, ["x₁", "x₂"])

julia> ocp = PreModel(); state!(ocp, 2, "y");

julia> state_dimension(ocp), state_components(ocp)
(2, ["y₁", "y₂"])

julia> ocp = PreModel(); state!(ocp, 2, "y", ["u", "v"]);

julia> state_dimension(ocp), state_components(ocp)
(2, ["u", "v"])
```

# Throws

- `Exceptions.PreconditionError`: If state has already been set
- `Exceptions.IncorrectArgument`: If n ≤ 0
- `Exceptions.IncorrectArgument`: If number of component names ≠ n
- `Exceptions.IncorrectArgument`: If name is empty
- `Exceptions.IncorrectArgument`: If any component name is empty
- `Exceptions.IncorrectArgument`: If name is one of the component names
- `Exceptions.IncorrectArgument`: If component names contain duplicates
- `Exceptions.IncorrectArgument`: If name conflicts with existing names in other components
- `Exceptions.IncorrectArgument`: If any component name conflicts with existing names

# Returns
- `Nothing`

See also: [`CTModels.Building.control!`](@ref), [`CTModels.Building.variable!`](@ref), [`CTModels.Building.time!`](@ref), [`CTModels.Components.state_dimension`](@ref).
"""
function state!(
    ocp::PreModel,
    n::Dimension,
    name::T1=__state_name(),
    components_names::Vector{T2}=__state_components(n, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}

    # checks
    Core.@ensure !__is_state_set(ocp) Exceptions.PreconditionError(
        "State already set",
        reason="state has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing state definition",
        context="state! function - duplicate definition check",
    )
    Core.@ensure n > 0 Exceptions.IncorrectArgument(
        "Invalid dimension: must be positive",
        got="n=$n",
        expected="n > 0 (positive integer)",
        suggestion="Use state!(ocp, n=3) with n > 0",
        context="state!(ocp, n=$n, name=\"$name\") - validating dimension parameter",
    )
    Core.@ensure size(components_names, 1) == n Exceptions.IncorrectArgument(
        "Component names count mismatch",
        got="$(size(components_names, 1)) names for dimension $n",
        expected="exactly $n component names",
        suggestion="Use state!(ocp, n, name, [\"x1\", \"x2\", ..., \"x$n\"]) or omit for auto-generation",
        context="state!(ocp, n=$n, components_names=[...]) - validating names count",
    )

    # NEW: Comprehensive name validation
    __validate_name_uniqueness(ocp, string(name), string.(components_names), :state)

    # set the state
    ocp.state = StateModel(string(name), string.(components_names))

    return nothing
end

# Getters for StateModel/StateModelSolution are now in src/Components/accessors.jl.
