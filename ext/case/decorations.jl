# =============================================================================
# decorations.jl — reference lines (bounds and initial/final time) as IR decorations.
#
# Box bounds become per-component horizontal lines (`HLine`) attached to their cell;
# the initial/final times become vertical lines (`VLine`) shared by every cell. Base
# styles reproduce the historical appearance; user `*_bounds_style` / `time_style`
# merge on top. Gating lives in `do_decorate` (vocabulary.jl).
#
# Docstrings deferred (Handbook convention).
# =============================================================================

const _BOUND_STYLE = (color=15, linewidth=1, z_order=:back, label="")
const _TIME_STYLE = (color=:black, linestyle=:dash, linewidth=1, z_order=:back, label="")

# Per-component horizontal bound lines from a box `(lb, ind, ub, …)`, aligned to a
# panel of `ncomp` components: `hlines[i]` holds the lines for component `i`.
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
