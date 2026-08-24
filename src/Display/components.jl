# ------------------------------------------------------------------------------
# Display for component model types
# ------------------------------------------------------------------------------

"""Return the concrete display name for a component model."""
_component_name(model) = nameof(typeof(model))

"""Collect accessor-backed fields for a state, control, or variable model."""
function _space_fields(
    model::Union{Components.StateModel,Components.ControlModel,Components.VariableModel}
)
    return [
        ("name", Components.name(model), fmt -> fmt.value),
        ("dimension", Components.dimension(model), fmt -> fmt.count),
        ("components", join(Components.components(model), ", "), fmt -> fmt.value),
    ]
end

"""Collect display fields for a component model carrying a trajectory or value."""
function _solution_space_fields(model)
    return [
        ("name", Components.name(model), fmt -> fmt.value),
        ("dimension", Components.dimension(model), fmt -> fmt.count),
        ("components", join(Components.components(model), ", "), fmt -> fmt.value),
        ("value", "<callable>", fmt -> fmt.muted),
    ]
end

"""Render a state, control, or variable model in compact or detailed form."""
function _show_space(io::IO, model; detailed::Bool=false)
    fmt = format_codes(io)
    fields = _space_fields(model)
    if detailed
        return _show_detail(
            io, string(nameof(typeof(model))); fmt=fmt, fields=_styled_fields(fields, fmt)
        )
    end
    return _show_compact(
        io, string(nameof(typeof(model))); fmt=fmt, fields=_compact_fields(fields)
    )
end

"""Apply the selected palette role to each display field."""
function _styled_fields(fields, fmt)
    return [(field[1], field[2], field[3](fmt)) for field in fields]
end

"""Remove palette callbacks from fields used by compact displays."""
_compact_fields(fields) = [(field[1], field[2]) for field in fields]

for T in (:StateModel, :ControlModel, :VariableModel)
    @eval begin
        function Base.show(io::IO, model::Components.$T)
            return _show_space(io, model)
        end
        function Base.show(io::IO, ::MIME"text/plain", model::Components.$T)
            return _show_space(io, model; detailed=true)
        end
    end
end

"""Render a solution state, control, or variable component."""
function _show_solution_space(io::IO, model; detailed::Bool=false)
    fmt = format_codes(io)
    fields = _solution_space_fields(model)
    model isa Components.ControlModelSolution && push!(
        fields, ("interpolation", Components.interpolation(model), fmt -> fmt.keyword)
    )
    return if detailed
        _show_detail(io, nameof(typeof(model)); fmt=fmt, fields=_styled_fields(fields, fmt))
    else
        _show_compact(io, nameof(typeof(model)); fmt=fmt, fields=_compact_fields(fields))
    end
end

for T in (:StateModelSolution, :ControlModelSolution, :VariableModelSolution)
    @eval begin
        Base.show(io::IO, model::Components.$T) = _show_solution_space(io, model)
        Base.show(io::IO, ::MIME"text/plain", model::Components.$T) =
            _show_solution_space(io, model; detailed=true)
    end
end

for T in (:EmptyControlModel, :EmptyVariableModel)
    @eval begin
        function Base.show(io::IO, ::Components.$T)
            fmt = format_codes(io)
            return print(io, fmt.name, string(nameof(Components.$T)), fmt.reset, "()")
        end
        function Base.show(io::IO, ::MIME"text/plain", ::Components.$T)
            fmt = format_codes(io)
            print_header(io, string(nameof(Components.$T)); fmt=fmt)
            return print_field(
                io, "status", :empty; last=true, fmt=fmt, value_style=fmt.muted
            )
        end
    end
end

"""
$(TYPEDSIGNATURES)

Display a fixed time model compactly using its name and time value.
"""
function Base.show(io::IO, model::Components.FixedTimeModel)
    fmt = format_codes(io)
    return _show_compact(
        io,
        "FixedTimeModel";
        fmt=fmt,
        fields=[("name", Components.name(model)), ("time", Base.time(model))],
    )
end

"""
$(TYPEDSIGNATURES)

Display a fixed time model as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", model::Components.FixedTimeModel)
    fmt = format_codes(io)
    return _show_detail(
        io,
        "FixedTimeModel";
        fmt=fmt,
        fields=[
            ("name", Components.name(model), fmt.value),
            ("time", Base.time(model), fmt.value),
        ],
    )
end

"""
$(TYPEDSIGNATURES)

Display a free time model compactly using its name and variable index.
"""
function Base.show(io::IO, model::Components.FreeTimeModel)
    fmt = format_codes(io)
    return _show_compact(
        io,
        "FreeTimeModel";
        fmt=fmt,
        fields=[("name", Components.name(model)), ("index", Components.index(model))],
    )
end

"""
$(TYPEDSIGNATURES)

Display a free time model as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", model::Components.FreeTimeModel)
    fmt = format_codes(io)
    return _show_detail(
        io,
        "FreeTimeModel";
        fmt=fmt,
        fields=[
            ("name", Components.name(model), fmt.value),
            ("index", Components.index(model), fmt.count),
        ],
    )
end

"""
$(TYPEDSIGNATURES)

Display the initial and final time models compactly.
"""
function Base.show(io::IO, model::Components.TimesModel)
    fmt = format_codes(io)
    return _show_compact(
        io,
        "TimesModel";
        fmt=fmt,
        fields=[
            ("initial", Components.initial(model)),
            ("final", Components.final(model)),
            ("time_name", Components.time_name(model)),
        ],
    )
end

"""
$(TYPEDSIGNATURES)

Display the initial and final time models as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", model::Components.TimesModel)
    fmt = format_codes(io)
    return _show_detail(
        io,
        "TimesModel";
        fmt=fmt,
        fields=[
            ("initial", Components.initial(model), ""),
            ("final", Components.final(model), ""),
            ("time_name", Components.time_name(model), fmt.value),
        ],
    )
end

"""
$(TYPEDSIGNATURES)

Render an objective model without expanding its callable fields.
"""
function _show_objective(io::IO, model, fields; detailed::Bool=false)
    fmt = format_codes(io)
    values = Any[("criterion", Components.criterion(model), fmt -> fmt.keyword)]
    Components.has_mayer_cost(model) &&
        push!(values, ("mayer", "<callable>", fmt -> fmt.muted))
    Components.has_lagrange_cost(model) &&
        push!(values, ("lagrange", "<callable>", fmt -> fmt.muted))
    return if detailed
        _show_detail(io, nameof(typeof(model)); fmt=fmt, fields=_styled_fields(values, fmt))
    else
        _show_compact(io, nameof(typeof(model)); fmt=fmt, fields=_compact_fields(values))
    end
end

for T in (:MayerObjectiveModel, :LagrangeObjectiveModel, :BolzaObjectiveModel)
    @eval begin
        Base.show(io::IO, model::Components.$T) = _show_objective(io, model, nothing)
        Base.show(io::IO, ::MIME"text/plain", model::Components.$T) =
            _show_objective(io, model, nothing; detailed=true)
    end
end

"""
$(TYPEDSIGNATURES)

Display a compact summary of the five constraint families.
"""
function Base.show(io::IO, model::Components.ConstraintsModel)
    fmt = format_codes(io)
    fields = [
        ("path nonlinear", length(Components.path_constraints_nl(model))),
        ("boundary nonlinear", length(Components.boundary_constraints_nl(model))),
        ("state box", length(Components.state_constraints_box(model))),
        ("control box", length(Components.control_constraints_box(model))),
        ("variable box", length(Components.variable_constraints_box(model))),
    ]
    return _show_compact(io, "ConstraintsModel"; fmt=fmt, fields=fields)
end

"""
$(TYPEDSIGNATURES)

Display a detailed tree summary of the five constraint families.
"""
function Base.show(io::IO, ::MIME"text/plain", model::Components.ConstraintsModel)
    fmt = format_codes(io)
    fields = [
        ("path nonlinear", length(Components.path_constraints_nl(model)), fmt.count),
        (
            "boundary nonlinear",
            length(Components.boundary_constraints_nl(model)),
            fmt.count,
        ),
        ("state box", length(Components.state_constraints_box(model)), fmt.count),
        ("control box", length(Components.control_constraints_box(model)), fmt.count),
        ("variable box", length(Components.variable_constraints_box(model)), fmt.count),
    ]
    return _show_detail(io, "ConstraintsModel"; fmt=fmt, fields=fields)
end

"""
$(TYPEDSIGNATURES)

Display the empty symbolic definition explicitly.
"""
function Base.show(io::IO, ::Components.EmptyDefinition)
    fmt = format_codes(io)
    return print(io, fmt.name, "EmptyDefinition", fmt.reset, "()")
end

"""
$(TYPEDSIGNATURES)

Display the empty symbolic definition as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", ::Components.EmptyDefinition)
    fmt = format_codes(io)
    print_header(io, "EmptyDefinition"; fmt=fmt)
    return print_field(io, "status", :empty; last=true, fmt=fmt, value_style=fmt.muted)
end
