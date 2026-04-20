# ------------------------------------------------------------------------------
# Name Validation Helpers
# ------------------------------------------------------------------------------

"""
    __collect_used_names(ocp::PreModel)::Vector{String}

Collect all names already used in the PreModel across all components.

Returns a vector containing:
- Time name (if set)
- State name and components (if set)
- Control name and components (if set)
- Variable name and components (if set and non-empty)

# Example

```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2, "x", ["x₁", "x₂"])
julia> control!(ocp, 1, "u")
julia> __collect_used_names(ocp)
4-element Vector{String}:
 "x"
 "x₁"
 "x₂"
 "u"
```

See also: `__has_name_conflict`, `__validate_name_uniqueness`
"""
function __collect_used_names(ocp::PreModel)::Vector{String}
    names = String[]

    # Time name
    if __is_times_set(ocp)
        push!(names, time_name(ocp.times))
    end

    # State name and components
    if __is_state_set(ocp)
        push!(names, name(ocp.state))
        append!(names, components(ocp.state))
    end

    # Control name and components
    if !__is_control_empty(ocp)
        push!(names, name(ocp.control))
        append!(names, components(ocp.control))
    end

    # Variable name and components (if not empty)
    if !__is_variable_empty(ocp)
        var_model = ocp.variable
        push!(names, name(var_model))
        append!(names, components(var_model))
    end

    # Return unique names (to handle case where name == component for scalars)
    return unique(names)
end

"""
    __has_name_conflict(ocp::PreModel, new_name::String, exclude_component::Symbol=:none)::Bool

Check if a name conflicts with existing names in the PreModel.

# Arguments

- `ocp::PreModel`: The model to check against
- `new_name::String`: The new name to check
- `exclude_component::Symbol`: Component type to exclude from check (`:state`, `:control`, `:variable`, `:time`, `:none`)

The `exclude_component` parameter allows checking for conflicts while updating a component,
excluding the component's own current names from the check.

# Returns

- `Bool`: `true` if conflict exists, `false` otherwise

# Example

```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2, "x", ["x₁", "x₂"])
julia> __has_name_conflict(ocp, "x", :none)
true

julia> __has_name_conflict(ocp, "y", :none)
false
```

See also: `__collect_used_names`, `__validate_name_uniqueness`
"""
function __has_name_conflict(
    ocp::PreModel, new_name::String, exclude_component::Symbol=:none
)::Bool
    existing_names = __collect_used_names(ocp)

    # Remove names from the component being updated
    if exclude_component == :state && __is_state_set(ocp)
        filter!(x -> x != name(ocp.state), existing_names)
        filter!(x -> x ∉ components(ocp.state), existing_names)
    elseif exclude_component == :control && !__is_control_empty(ocp)
        filter!(x -> x != name(ocp.control), existing_names)
        filter!(x -> x ∉ components(ocp.control), existing_names)
    elseif exclude_component == :variable && !__is_variable_empty(ocp)
        var_model = ocp.variable
        filter!(x -> x != name(var_model), existing_names)
        filter!(x -> x ∉ components(var_model), existing_names)
    elseif exclude_component == :time && __is_times_set(ocp)
        filter!(x -> x != time_name(ocp.times), existing_names)
    end

    return new_name ∈ existing_names
end

"""
    __validate_name_uniqueness(ocp::PreModel, name::String, components::Vector{String}, 
                               component_type::Symbol)

Validate that a name and its components don't conflict with existing names.

Performs comprehensive validation:
1. Name is not empty
2. Components are not empty
3. Name not in components (internal conflict)
4. No duplicates in components
5. No conflicts with existing names in other components (global uniqueness)

# Arguments

- `ocp::PreModel`: The model to validate against
- `name::String`: The component name
- `components::Vector{String}`: The component names
- `component_type::Symbol`: Type of component (`:state`, `:control`, `:variable`, `:time`)

# Throws

- `Exceptions.IncorrectArgument`: If any validation fails

# Example

```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2, "x", ["x₁", "x₂"])
julia> __validate_name_uniqueness(ocp, "x", ["u"], :control)  # Would throw if "x" conflicts
```

See also: `__has_name_conflict`, `__collect_used_names`
"""
function __validate_name_uniqueness(
    ocp::PreModel, name::String, components::Vector{String}, component_type::Symbol
)
    component_label = String(component_type)

    # 1. Name is not empty
    @ensure !isempty(name) Exceptions.IncorrectArgument(
        "Empty $(component_label) name",
        got="empty string",
        expected="non-empty string",
        suggestion="Use a non-empty string: name=\"x\" or name=:state",
        context="$(component_label)! name validation",
    )

    # 2. Components are not empty
    @ensure all(!isempty(c) for c in components) Exceptions.IncorrectArgument(
        "Empty component name in $(component_label)",
        got="one or more empty component names",
        expected="all non-empty component names",
        suggestion="Ensure all component names are non-empty strings",
        context="$(component_label)! component names validation",
    )

    # 3. Name not in components (internal conflict)
    # Exception: when there's only one component and it equals the name (default behavior)
    if length(components) == 1 && components[1] == name
        # This is the default behavior for scalar components, allow it
    else
        @ensure !(name ∈ components) Exceptions.IncorrectArgument(
            "$(component_label) name conflicts with component names",
            got="name='$name' appears in components=$components",
            expected="name different from all component names",
            suggestion="Choose a different name or use auto-generated component names",
            context="$(component_label)! name uniqueness validation",
        )
    end

    # 4. No duplicates in components
    @ensure length(unique(components)) == length(components) Exceptions.IncorrectArgument(
        "Duplicate component names in $(component_label)",
        got="components=$components with duplicates",
        expected="all unique component names",
        suggestion="Ensure each component has a unique name",
        context="$(component_label)! component uniqueness validation",
    )

    # 5. No conflicts with existing names (global uniqueness)
    @ensure !__has_name_conflict(ocp, name, component_type) Exceptions.IncorrectArgument(
        "$(component_label) name conflicts with existing names",
        got="name='$name'",
        expected="unique name not in: $(__collect_used_names(ocp))",
        suggestion="Choose a different name that doesn't conflict with existing components",
        context="$(component_label)! global name validation",
    )

    for comp_name in components
        @ensure !__has_name_conflict(ocp, comp_name, component_type) Exceptions.IncorrectArgument(
            "$(component_label) component name conflicts with existing names",
            got="component='$comp_name'",
            expected="unique name not in: $(__collect_used_names(ocp))",
            suggestion="Choose different component names that don't conflict with existing components",
            context="$(component_label)! component global validation",
        )
    end
end
