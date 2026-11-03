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
or control bounded by the box, as a [`CTBase.Plotting.Panel`](@extref).
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
        labels=names[row.rows],
        style=_base_style(merge((seriestype=st,), style)),
    )
end

"""
$(TYPEDSIGNATURES)

The right-hand side of the row `row`: its dual, [`CTModels.PlotCase._row_dual`](@extref),
sampled on the grid of the row. Its ylabels are `dual <label>` for every kind of row (the
left-hand side of a box carries the name of the component, so the label is not repeated
there).
"""
function _row_dual_panel(
    sol, model, row::ConstraintRow, style::NamedTuple; connect::Bool=true, title::String=""
)
    row.kind === :path && return _dual_panel(
        sol, model, style; connect=connect, rows=row.rows, title=title
    )
    T = _row_grid(sol, row)
    d = _row_dual(sol, model, row)
    T, M = _splice_box_dual(sol, row, d, T, _sample(d, T); connect=connect)
    n = length(row.rows)
    labels = "dual " .* _row_labels(fill(row.label, n))
    return Plotting.Panel(T, M; title=title, labels=labels, style=_base_style(style))
end

"""
$(TYPEDSIGNATURES)

Insert the limits of the dual `d` of the box row `row` at the switching times into its
samples `(T, M)`, as [`CTModels.PlotCase._spliced_samples`](@extref) does for the path duals.

The limits are the signed duals per component stored in the switching model
(`:state_dual`, `:control_dual`), taken at the components of the row. The samples are
returned unchanged when the solution has no switching time or no box limits. A limit that
is unknown (`NaN`) draws no jump: the dual is continuous there, with its value at the
switching time.
"""
function _splice_box_dual(
    sol, row::ConstraintRow, d, T::AbstractVector, M::AbstractMatrix; connect::Bool=true
)
    taus = CTModels.switching_times(sol)
    component = row.kind === :state ? :state_dual : :control_dual
    left, right = Solutions.limits(CTModels.switching_model(sol), component)
    (isempty(taus) || size(left, 2) == 0) && return (T, M)
    left, right = left[:, row.rows], right[:, row.rows]
    for (i, tau) in enumerate(taus)
        value = vcat(d(tau))
        for j in eachindex(value)
            isnan(left[i, j]) && (left[i, j] = value[j])
            isnan(right[i, j]) && (right[i, j] = value[j])
        end
    end
    return Plotting.splice_jumps(T, M, taus, left, right; connect=connect)
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
