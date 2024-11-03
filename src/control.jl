"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the control.
The default value is `"u"`.
"""
__control_name() = "u"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the controls.
The default value is `["u"]` for a one dimensional control, and `["u₁", "u₂", ...]` for a multi dimensional control.
"""
__control_components(m::Dimension, name::String) =
    m > 1 ? [name * CTBase.ctindices(i) for i ∈ range(1, m)] : [name]

"""
$(TYPEDSIGNATURES)

"""
__is_control_set(ocp::OptimalControlModelMutable) = !isnothing(ocp.control)

"""
$(TYPEDSIGNATURES)

Define the control dimension and possibly the names of each coordinate.

!!! note

    You must use control! only once to set the control dimension.

# Examples

```@example
julia> control!(ocp, 1)
julia> control_dimension(ocp)
1
julia> control_components(ocp)
["u"]

julia> control!(ocp, 1, "v")
julia> control_dimension(ocp)
1
julia> control_components(ocp)
["v"]

julia> control!(ocp, 2)
julia> control_dimension(ocp)
2
julia> control_components(ocp)
["u₁", "u₂"]

julia> control!(ocp, 2, :v)
julia> control_dimension(ocp)
2
julia> control_components(ocp)
["v₁", "v₂"]

julia> control!(ocp, 2, "v")
julia> control_dimension(ocp)
2
julia> control_components(ocp)
["v₁", "v₂"]

julia> control!(ocp, 2, "v", ["a", "b"])
julia> control_dimension(ocp)
2
julia> control_components(ocp)
["a", "b"]

julia> control!(ocp, 2, "v", [:a, :b])
julia> control_dimension(ocp)
2
julia> control_components(ocp)
["a", "b"]
```
"""
function control!(
    ocp::OptimalControlModelMutable,
    m::Dimension,
    name::T1 = __control_name(),
    components_names::Vector{T2} = __control_components(m, string(name)),
) where {T1<:Union{String, Symbol}, T2<:Union{String, Symbol}}

    # checkings
    __is_control_set(ocp) && throw(CTBase.UnauthorizedCall("the control has already been set."))
    (m > 1) &&
        (size(components_names, 1) ≠ m) &&
        throw(
            CTBase.IncorrectArgument("the number of control names must be equal to the control dimension"),
        )

    # set the control
    ocp.control = ControlModel(m, string(name), string.(components_names))
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# from ControlModel
dimension(model::ControlModel) = model.dimension
name(model::ControlModel) = model.name
components(model::ControlModel) = model.components

# from OptimalControlModel
control(model::OptimalControlModel) = model.control
control_dimension(model::OptimalControlModel) = dimension(control(model))
control_name(model::OptimalControlModel) = name(control(model))
control_components(model::OptimalControlModel) = components(control(model))

# from OptimalControlModelMutable
control(model::OptimalControlModelMutable) = model.control
control_dimension(model::OptimalControlModelMutable) = dimension(control(model))
control_name(model::OptimalControlModelMutable) = name(control(model))
control_components(model::OptimalControlModelMutable) = components(control(model))