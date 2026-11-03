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
"""
struct ConstraintRow
    label::Symbol
    kind::Symbol
    rows::Vector{Int}
end

"""
$(TYPEDSIGNATURES)

List the constraint rows of the plot of `sol`: the path constraints, then the state
boxes, then the control boxes, each in declaration order and one row per label.

A label whose dual is unknown to `sol` (see [`CTModels.Solutions.has_dual`](@extref))
gives no row. Boundary and variable-box labels are not plotted: their duals do not
depend on time.
"""
function _constraint_rows(sol, model)::Vector{ConstraintRow}
    labels = (
        (:path, CTModels.path_constraints_nl(model)[4]),
        (:state, CTModels.state_constraints_box(model)[4]),
        (:control, CTModels.control_constraints_box(model)[4]),
    )
    out = ConstraintRow[]
    for (kind, ls) in labels, label in unique(ls)
        Solutions.has_dual(sol, model, label) || continue
        _, rows = Models.constraint_rows(model, label)
        push!(out, ConstraintRow(label, kind, rows))
    end
    return out
end

"""
$(TYPEDSIGNATURES)

The dual of the constraint row `row`, as a function of time:
[`CTModels.Solutions.dual`](@extref)`(sol, model, row.label)`.
"""
_row_dual(sol, model, row::ConstraintRow) = Solutions.dual(sol, model, row.label)
