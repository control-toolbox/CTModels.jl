# =============================================================================
# rows.jl — constraint rows of the plot (issue #506)
#
# The bottom block of the figure has one row per constraint label — a path constraint,
# a state box or a control box — pairing the constraint (left) with its dual (right).
# By ct-conventions `SGN5` a box and the same constraint written as a path constraint
# have the same dual, so both are plotted the same way. This file lists the rows; the
# panels are built from them in `panels.jl`.
# =============================================================================

"""
$(TYPEDEF)

A row of the constraint block of the plot: the constraint labelled `label`.

# Fields
- `label::Symbol`: The label of the constraint.
- `kind::Symbol`: `:path`, `:state` (state box) or `:control` (control box).
- `rows::Vector{Int}`: The rows of the constraint in the stacked path constraint (for
  `:path`), or the components it bounds (for a box), as returned by
  [`CTModels.Models.constraint_rows`](@extref).
- `dual::Bool`: Whether `sol` knows the dual of the constraint
  ([`CTModels.Solutions.has_dual`](@extref)); the right-hand side of the row exists only
  then.
"""
struct ConstraintRow
    label::Symbol
    kind::Symbol
    rows::Vector{Int}
    dual::Bool
end

"""
$(TYPEDSIGNATURES)

List the constraint rows of the plot of `sol`: the path constraints, then the state
boxes, then the control boxes, each in declaration order and one row per label.

A path constraint is always a row, with or without a dual (`row.dual`). A box is a row
only when its dual is known to `sol` (see [`CTModels.Solutions.has_dual`](@extref)): without
its dual, the left-hand side would only repeat the component of the state or control
panel. Boundary and variable-box labels are not plotted: their duals do not depend on
time.
"""
function _constraint_rows(sol, model)::Vector{ConstraintRow}
    labels = (
        (:path, CTModels.path_constraints_nl(model)[4]),
        (:state, CTModels.state_constraints_box(model)[4]),
        (:control, CTModels.control_constraints_box(model)[4]),
    )
    out = ConstraintRow[]
    for (kind, ls) in labels, label in unique(ls)
        known = Solutions.has_dual(sol, model, label)
        (known || kind === :path) || continue
        _, rows = Models.constraint_rows(model, label)
        push!(out, ConstraintRow(label, kind, rows, known))
    end
    return out
end

"""
$(TYPEDSIGNATURES)

The dual of the constraint row `row`, as a function of time:
[`CTModels.Solutions.dual`](@extref)`(sol, model, row.label)`.
"""
_row_dual(sol, model, row::ConstraintRow) = Solutions.dual(sol, model, row.label)

# --- panels of a row ----------------------------------------------------------

# The time grid of the data of a row: the path grid for a path constraint, the grid of the
# state or of the control for a box (the box duals live on those grids).
"""
$(TYPEDSIGNATURES)

The time grid on which the row `row` is sampled.
"""
function _row_grid(sol, row::ConstraintRow)
    return CTModels.time_grid(sol, row.kind === :path ? :path : row.kind)
end

"""
$(TYPEDSIGNATURES)

The left-hand side of the row `row`: the path constraint, or the components of the state
or control bounded by the box, as a [`CTBase.Plotting.Panel`](@extref). A box cell is
labelled with the component and the label of the constraint, e.g. `x₂ (x2_box)`.
`title` is the title of the panel (shown on its first cell).
"""
function _row_left_panel(
    sol, model, row::ConstraintRow, style::NamedTuple; connect::Bool=true, title::String=""
)
    row.kind === :path && return _path_panel(
        sol, model, style; connect=connect, rows=row.rows, title=title
    )
    state = row.kind === :state
    T = _row_grid(sol, row)
    f = state ? CTModels.state(sol) : CTModels.control(sol)
    T, M = _spliced_samples(
        sol,
        T,
        _sample(f, T)[:, row.rows],
        row.kind;
        connect=connect,
        cols=row.rows,
    )
    names = state ? CTModels.state_components(sol) : CTModels.control_components(sol)
    st = (!state && CTModels.control_interpolation(sol) == :constant) ? :steppost : :path
    return Plotting.Panel(
        T,
        M;
        title=title,
        labels=["$(names[j]) ($(row.label))" for j in row.rows],
        style=_base_style(merge((seriestype=st,), style)),
    )
end

"""
$(TYPEDSIGNATURES)

The right-hand side of the row `row`: its dual, [`CTModels.PlotCase._row_dual`](@extref),
sampled on the grid of the row. As for the costate, its ylabels are dropped when the
left-hand side is shown alongside (the left cell carries the name), otherwise `dual <label>`.
"""
function _row_dual_panel(
    sol,
    model,
    row::ConstraintRow,
    style::NamedTuple;
    left_shown::Bool,
    connect::Bool=true,
    title::String="",
)
    row.kind === :path && return _dual_panel(
        sol,
        model,
        style;
        path_shown=left_shown,
        connect=connect,
        rows=row.rows,
        title=title,
    )
    T = _row_grid(sol, row)
    # the jumps at the switching times: the signed limits of the box dual, per component
    T, M = _spliced_samples(
        sol,
        T,
        _sample(_row_dual(sol, model, row), T),
        row.kind === :state ? :state_dual : :control_dual;
        connect=connect,
        cols=row.rows,
    )
    n = length(row.rows)
    # one rule for every row: the left cell carries the name, the paired right cell none
    labels = left_shown ? fill("", n) : ["dual $(row.label)" for _ in 1:n]
    return Plotting.Panel(T, M; title=title, labels=labels, style=_base_style(style))
end

"""
$(TYPEDSIGNATURES)

The horizontal bound lines of the left-hand side of the row `row`, one vector per component
of the panel: the bounds of the path constraint, or of the state or control box
components.
"""
function _row_hlines(model, row::ConstraintRow, style::NamedTuple)
    row.kind === :path && return _path_hlines(model, style)[row.rows]
    box = if row.kind === :state
        CTModels.state_constraints_box(model)
    else
        CTModels.control_constraints_box(model)
    end
    n = row.kind === :state ? CTModels.state_dimension(model) : CTModels.control_dimension(model)
    return _box_hlines(box, n, style)[row.rows]
end
