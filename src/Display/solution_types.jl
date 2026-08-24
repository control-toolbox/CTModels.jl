# ------------------------------------------------------------------------------
# Display for solution support types
# ------------------------------------------------------------------------------

"""Summarize a time grid by its size and endpoint values."""
function _grid_summary(grid)
    isempty(grid) && return "0 points"
    return string(length(grid), " points [", first(grid), ", ", last(grid), "]")
end

"""
$(TYPEDSIGNATURES)

Display a unified time grid compactly with its size and endpoints.
"""
function Base.show(io::IO, grid::Solutions.UnifiedTimeGridModel)
    fmt = format_codes(io)
    return _show_compact(
        io,
        "UnifiedTimeGridModel";
        fmt=fmt,
        fields=[
            ("points", length(grid.value)),
            ("first", first(grid.value)),
            ("last", last(grid.value)),
        ],
    )
end

"""
$(TYPEDSIGNATURES)

Display a unified time grid as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", grid::Solutions.UnifiedTimeGridModel)
    fmt = format_codes(io)
    fields = if isempty(grid.value)
        [("points", 0, fmt.count)]
    else
        [
        ("points", length(grid.value), fmt.count),
        ("first", first(grid.value), fmt.value),
        ("last", last(grid.value), fmt.value),
    ]
    end
    return _show_detail(io, "UnifiedTimeGridModel"; fmt=fmt, fields=fields)
end

"""
$(TYPEDSIGNATURES)

Display the component sizes of a multiple time grid compactly.
"""
function Base.show(io::IO, grid::Solutions.MultipleTimeGridModel)
    fmt = format_codes(io)
    fields = [
        (string(name), _grid_summary(getfield(grid.grids, name))) for
        name in keys(grid.grids)
    ]
    return _show_compact(io, "MultipleTimeGridModel"; fmt=fmt, fields=fields)
end

"""
$(TYPEDSIGNATURES)

Display each component grid as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", grid::Solutions.MultipleTimeGridModel)
    fmt = format_codes(io)
    fields = [
        (string(name), _grid_summary(getfield(grid.grids, name)), fmt.value) for
        name in keys(grid.grids)
    ]
    return _show_detail(io, "MultipleTimeGridModel"; fmt=fmt, fields=fields)
end

function Base.show(io::IO, ::Solutions.EmptyTimeGridModel)
    fmt = format_codes(io)
    return print(io, fmt.name, "EmptyTimeGridModel", fmt.reset, "()")
end

function Base.show(io::IO, ::MIME"text/plain", ::Solutions.EmptyTimeGridModel)
    fmt = format_codes(io)
    print_header(io, "EmptyTimeGridModel"; fmt=fmt)
    return print_field(io, "status", :empty; last=true, fmt=fmt, value_style=fmt.muted)
end

"""
$(TYPEDSIGNATURES)

Display solver information compactly.
"""
function Base.show(io::IO, infos::Solutions.SolverInfos)
    fmt = format_codes(io)
    fields = [
        ("status", infos.status),
        ("successful", infos.successful),
        ("iterations", infos.iterations),
        ("constraints_violation", infos.constraints_violation),
    ]
    return _show_compact(io, "SolverInfos"; fmt=fmt, fields=fields)
end

"""
$(TYPEDSIGNATURES)

Display provided solver information as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", infos::Solutions.SolverInfos)
    fmt = format_codes(io)
    candidates = [
        ("status", infos.status, fmt.keyword),
        ("successful", infos.successful, infos.successful ? fmt.success : fmt.error),
        ("iterations", infos.iterations, fmt.count),
        ("message", infos.message, fmt.value),
        ("constraints violation", infos.constraints_violation, fmt.value),
    ]
    fields = [field for field in candidates if !(field[2] isa CTBase.Core.NotProvidedType)]
    return _show_detail(io, "SolverInfos"; fmt=fmt, fields=fields)
end

"""Return whether an optional dual value is present."""
function _dual_presence(value)
    return value === nothing ? :none : :present
end

"""
$(TYPEDSIGNATURES)

Display which dual constraint families are present.
"""
function Base.show(io::IO, dual::Solutions.DualModel)
    fmt = format_codes(io)
    fields = [
        ("path", _dual_presence(dual.path_constraints_dual)),
        ("boundary", _dual_presence(dual.boundary_constraints_dual)),
        (
            "state box",
            if _dual_presence(dual.state_constraints_lb_dual) !== :none ||
               _dual_presence(dual.state_constraints_ub_dual) !== :none
                :present
            else
                :none
            end,
        ),
        (
            "control box",
            if _dual_presence(dual.control_constraints_lb_dual) !== :none ||
               _dual_presence(dual.control_constraints_ub_dual) !== :none
                :present
            else
                :none
            end,
        ),
        (
            "variable box",
            if _dual_presence(dual.variable_constraints_lb_dual) !== :none ||
               _dual_presence(dual.variable_constraints_ub_dual) !== :none
                :present
            else
                :none
            end,
        ),
    ]
    return _show_compact(io, "DualModel"; fmt=fmt, fields=fields)
end

"""
$(TYPEDSIGNATURES)

Display dual presence as a labelled tree.
"""
function Base.show(io::IO, ::MIME"text/plain", dual::Solutions.DualModel)
    fmt = format_codes(io)
    fields = [
        ("path", _dual_presence(dual.path_constraints_dual), fmt.keyword),
        ("boundary", _dual_presence(dual.boundary_constraints_dual), fmt.keyword),
        (
            "state box",
            if _dual_presence(dual.state_constraints_lb_dual) !== :none ||
               _dual_presence(dual.state_constraints_ub_dual) !== :none
                :present
            else
                :none
            end,
            fmt.keyword,
        ),
        (
            "control box",
            if _dual_presence(dual.control_constraints_lb_dual) !== :none ||
               _dual_presence(dual.control_constraints_ub_dual) !== :none
                :present
            else
                :none
            end,
            fmt.keyword,
        ),
        (
            "variable box",
            if _dual_presence(dual.variable_constraints_lb_dual) !== :none ||
               _dual_presence(dual.variable_constraints_ub_dual) !== :none
                :present
            else
                :none
            end,
            fmt.keyword,
        ),
    ]
    return _show_detail(io, "DualModel"; fmt=fmt, fields=fields)
end

function Base.show(io::IO, ::Solutions.EmptyDualModel)
    fmt = format_codes(io)
    return print(io, fmt.name, "EmptyDualModel", fmt.reset, "()")
end

function Base.show(io::IO, ::MIME"text/plain", ::Solutions.EmptyDualModel)
    fmt = format_codes(io)
    print_header(io, "EmptyDualModel"; fmt=fmt)
    return print_field(io, "status", :empty; last=true, fmt=fmt, value_style=fmt.muted)
end
