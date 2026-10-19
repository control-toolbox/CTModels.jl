# =============================================================================
# decorations.jl — reference lines (bounds, initial/final and switching times) and
# phase labels as IR decorations.
#
# Box bounds become per-component horizontal lines (`HLine`) attached to their cell;
# the initial/final times and the switching times become vertical lines (`VLine`)
# shared by every cell; the phase labels become texts (`Annotation`) centred on each
# phase. Base styles reproduce the historical appearance; user `*_bounds_style` /
# `time_style` / `switching_style` / `phase_labels_style` merge on top. Gating lives in
# `do_decorate` (vocabulary.jl).
# =============================================================================

"""$(TYPEDSIGNATURES)

Default style for box-bound and path-bound horizontal reference lines.
"""
const _BOUND_STYLE = (color=15, linewidth=1, z_order=:back, label="")

"""$(TYPEDSIGNATURES)

Default style for initial/final time vertical reference lines.
"""
const _TIME_STYLE = (color=:black, linestyle=:dash, linewidth=1, z_order=:back, label="")

# Per-component horizontal bound lines from a box `(lb, ind, ub, …)`, aligned to a
# panel of `ncomp` components: `hlines[i]` holds the lines for component `i`.
"""
$(TYPEDSIGNATURES)

Build per-component horizontal bound lines from a box constraint tuple.

For a panel with `ncomp` components, `hlines[i]` holds the lines for component `i`.
"""
function _box_hlines(box, ncomp::Int, style::NamedTuple)
    lb, ind, ub = box[1], box[2], box[3]
    s = merge(_BOUND_STYLE, style)
    hl = [Plotting.HLine[] for _ in 1:ncomp]
    for k in eachindex(lb)
        j = ind[k]
        push!(hl[j], Plotting.HLine(lb[k]; style=s))
        push!(hl[j], Plotting.HLine(ub[k]; style=s))
    end
    return hl
end

# Path-constraint bound lines: every one of the `nc` components carries `[lb, ub]`.
"""
$(TYPEDSIGNATURES)

Build bound lines for nonlinear path constraints.

Each of the `nc` components carries lower and upper bound lines.
"""
function _path_hlines(model, style::NamedTuple)
    cp = CTModels.path_constraints_nl(model)
    nc = length(cp[1])
    s = merge(_BOUND_STYLE, style)
    return [
        Plotting.HLine[
            Plotting.HLine(cp[1][i]; style=s), Plotting.HLine(cp[3][i]; style=s)
        ] for i in 1:nc
    ]
end

# Initial/final time vertical lines, shared by every cell. Positions are `[0, 1]`
# under time normalisation, else read from the model (variable-dependent for free time).
"""
$(TYPEDSIGNATURES)

Build initial/final time vertical lines shared by every cell.

Positions are `[0, 1]` under time normalisation, otherwise read from the model
(variable-dependent for free time).
"""
function _time_vlines(sol, model, time::Symbol, style::NamedTuple)
    if time === :normalize || time === :normalise
        t0, tf = 0.0, 1.0
    else
        t0 = if CTModels.has_fixed_initial_time(model)
            CTModels.initial_time(model)
        else
            CTModels.initial_time(model, CTModels.variable(sol))
        end
        tf = if CTModels.has_fixed_final_time(model)
            CTModels.final_time(model)
        else
            CTModels.final_time(model, CTModels.variable(sol))
        end
    end
    s = merge(_TIME_STYLE, style)
    return Plotting.VLine[Plotting.VLine(t0; style=s), Plotting.VLine(tf; style=s)]
end

"""
$(TYPEDSIGNATURES)

Style of the switching-time lines. By default they look like the initial/final time lines:
the base time style, merged with the user `time_style` when it is a `NamedTuple`; a user
`switching_style` merges on top.
"""
function _switching_style(time_style, switching_style::NamedTuple)
    base = time_style isa NamedTuple ? merge(_TIME_STYLE, time_style) : _TIME_STYLE
    return merge(base, switching_style)
end

"""
$(TYPEDSIGNATURES)

Build the vertical lines at the switching times of `sol`, shared by every cell, with
[`CTBase.Plotting.switching_vlines`](@extref) over the state time grid. Empty when the
solution has no switching time.
"""
function _switching_vlines(sol, time::Symbol, style::NamedTuple)
    return Plotting.switching_vlines(
        CTModels.time_grid(sol, :state),
        CTModels.switching_times(sol);
        time=time,
        style=style,
    )
end

"""
$(TYPEDSIGNATURES)

Build the phase labels of `sol` as texts centred on each phase, with
[`CTBase.Plotting.phase_annotations`](@extref) over the state time grid. A phase with an
empty label gets no text; a solution with no label gets none.
"""
function _phase_annotations(sol, time::Symbol, style::NamedTuple)
    return Plotting.phase_annotations(
        CTModels.time_grid(sol, :state),
        CTModels.switching_times(sol),
        CTModels.phase_labels(sol);
        time=time,
        style=style,
    )
end
