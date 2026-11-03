# =============================================================================
# build.jl — resolve description → gate groups → build panels → assemble tree →
# CTBase.Plotting.Figure.
#
# `build_figure` is the single backend-agnostic entry point of the case layer:
# the `CTModelsPlots` / `CTModelsMakie` extensions call it and hand the figure to
# a `CTBase.Plotting.render` backend. It also owns the user-facing defaults, so
# the two extensions only forward keyword arguments.
# =============================================================================

# Time-axis name, with the historical "(normalized)" suffix when time is rescaled.
"""
$(TYPEDSIGNATURES)

Return the time-axis label, with the historical "(normalized)" suffix when time is rescaled.
"""
function _time_name(sol, time::Symbol)
    tn = CTModels.time_name(sol)
    if time === :normalize
        return tn == "" ? tn : tn * " (normalized)"
    elseif time === :normalise
        return tn == "" ? tn : tn * " (normalised)"
    else
        return tn
    end
end

"""
$(TYPEDSIGNATURES)

Return the group that receives the phase labels: `:all` for `phase_labels = :all`; for
`:control`, the control group when it is drawn, otherwise the first drawn group, in the
order of the figure (`:state`, `:costate`, `:path`, `:dual`), or `:none` when no group is
drawn. The keywords tell which groups are drawn.
"""
function _phase_label_group(
    phase_labels::Symbol; state::Bool, costate::Bool, control::Bool, path::Bool, dual::Bool
)::Symbol
    phase_labels === :all && return :all
    control && return :control
    for (group, drawn) in
        ((:state, state), (:costate, costate), (:path, path), (:dual, dual))
        drawn && return group
    end
    return :none
end

# Build the layout tree (or `nothing` if there is nothing to draw).
"""
$(TYPEDSIGNATURES)

Build the [`CTBase.Plotting`](@extref) layout tree for a CTModels solution.

Returns `nothing` if there is nothing to draw. Decorations (bounds, initial/final time lines)
are added according to the user-supplied style keywords.
"""
function _build_root(
    sol,
    description::Symbol...;
    layout::Symbol,
    control::Symbol,
    time::Symbol,
    state_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
    time_style::Union{NamedTuple,Symbol},
    state_bounds_style::Union{NamedTuple,Symbol},
    control_bounds_style::Union{NamedTuple,Symbol},
    path_bounds_style::Union{NamedTuple,Symbol},
    switching_style::Union{NamedTuple,Symbol}=__plot_style(),
    phase_labels::Symbol=__phase_labels(),
    phase_labels_style::NamedTuple=__plot_style(),
    jumps::Symbol=__plot_jumps(),
)
    model = CTModels.model(sol)
    _check_phase_labels(phase_labels)
    _check_jumps(jumps)
    connect = jumps === :segment
    desc = clean(isempty(description) ? __description() : description)
    # the constraint rows, listed once for the figure (only the :split layout draws them)
    rows = if layout === :split && model isa CTModels.Model && (:path in desc || :dual in desc)
        _constraint_rows(sol, model)
    else
        ConstraintRow[]
    end
    do_state, do_costate, do_control, do_path, do_dual = do_plot(
        sol,
        desc...;
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
        rows=rows,
    )
    dec_time, dec_state_bounds, dec_control_bounds, dec_path_bounds = do_decorate(;
        model=model,
        time_style=time_style,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        path_bounds_style=path_bounds_style,
    )
    tn = _time_name(sol, time)
    # Initial/final time markers are shared by every cell (both layouts), and so are the
    # switching-time markers, styled like the time markers by default.
    vlines = dec_time ? _time_vlines(sol, model, time, time_style) : Plotting.VLine[]
    if switching_style !== :none
        sw_style = _switching_style(time_style, switching_style)
        vlines = vcat(vlines, _switching_vlines(sol, time, sw_style))
    end
    # Phase labels go to the control cell (`:control`, or the first drawn group when the
    # control is not drawn) or to every group (`:all`).
    texts = if phase_labels === :none
        Plotting.Annotation[]
    else
        _phase_annotations(sol, time, phase_labels_style)
    end
    # the groups the layout actually draws: `:group` draws neither constraints nor duals
    label_group = _phase_label_group(
        phase_labels;
        state=do_state,
        costate=do_costate,
        control=do_control,
        path=do_path && layout === :split,
        dual=do_dual && layout === :split,
    )
    _texts(group) =
        (label_group === :all || label_group === group) ? texts : Plotting.Annotation[]
    ncomp(p) = size(p.data, 2)
    function L(
        p;
        hlines=Vector{Plotting.HLine}[],
        group::Symbol=:none,
        time_name::String=tn,
        extra=Plotting.Annotation[],
    )
        return Plotting.lower(
            p;
            layout=layout,
            time=time,
            time_name=time_name,
            vlines=vlines,
            hlines=hlines,
            annotations=vcat(_texts(group), extra),
        )
    end

    if layout === :group
        # No bounds lines in :group (historical); only the time markers, via `vlines`.
        cells = Plotting.AbstractLayoutNode[]
        do_state &&
            push!(cells, L(_state_panel(sol, state_style; connect=connect); group=:state))
        do_costate && push!(
            cells,
            L(
                _costate_panel(
                    sol,
                    costate_style;
                    layout=layout,
                    state_shown=do_state,
                    connect=connect,
                );
                group=:costate,
            ),
        )
        if do_control
            # with `control=:all`, the labels go to the first control cell only
            for (k, cp) in enumerate(
                _control_panels(sol, control, control_style, layout; connect=connect)
            )
                push!(cells, L(cp; group=(k == 1 ? :control : :none)))
            end
        end
        isempty(cells) && return nothing
        return _assemble_group(cells)
    elseif layout === :split
        state_col = nothing
        if do_state
            sp = _state_panel(sol, state_style; connect=connect)
            hl = if dec_state_bounds
                _box_hlines(
                    CTModels.state_constraints_box(model), ncomp(sp), state_bounds_style
                )
            else
                Vector{Plotting.HLine}[]
            end
            state_col = L(sp; hlines=hl, group=:state)
        end
        costate_col = if do_costate
            L(
                _costate_panel(
                    sol,
                    costate_style;
                    layout=layout,
                    state_shown=do_state,
                    connect=connect,
                );
                group=:costate,
            )
        else
            nothing
        end
        control_col = nothing
        if do_control
            cp = only(_control_panels(sol, control, control_style, layout; connect=connect))
            hl = if (dec_control_bounds && control !== :norm)
                _box_hlines(
                    CTModels.control_constraints_box(model),
                    ncomp(cp),
                    control_bounds_style,
                )
            else
                Vector{Plotting.HLine}[]
            end
            control_col = L(cp; hlines=hl, group=:control)
        end
        # The constraint block: one row per constraint label (path, state box, control
        # box), pairing the constraint (`:path`) with its dual (`:dual`). The title is on
        # the first row, the time label on the last one, the phase labels on the first.
        row_nodes = Plotting.AbstractLayoutNode[]
        if do_path || do_dual
            drawn = [
                (r, do_path && (r.kind === :path || do_dual), do_dual && r.dual) for
                r in rows
            ]
            filter!(d -> d[2] || d[3], drawn)
            only_path = all(d -> d[1].kind === :path, drawn)
            # a block with a right column keeps it on every row (aligned time axes): a row
            # drawn on the left whose dual is not known gets an empty right cell
            two_columns = any(d -> d[2], drawn) && any(d -> d[3], drawn)
            # the samples of the path constraints and of their duals, once for all rows
            path_samples = if any(d -> d[2] && d[1].kind === :path, drawn)
                _path_samples(sol, model)
            else
                nothing
            end
            dual_samples = if any(d -> d[3] && d[1].kind === :path, drawn)
                _sample(CTModels.path_constraints_dual(sol), CTModels.time_grid(sol, :path))
            else
                nothing
            end
            for (k, (r, left, right)) in enumerate(drawn)
                top, bottom = k == 1, k == length(drawn)
                tname = bottom ? tn : ""
                grp(g) = top ? g : :none
                lnode = if left
                    title = top ? (only_path ? "path constraints" : "constraints") : ""
                    hl = if r.kind === :path && dec_path_bounds
                        _row_hlines(model, r, path_bounds_style)
                    elseif r.kind === :state && dec_state_bounds
                        _row_hlines(model, r, state_bounds_style)
                    elseif r.kind === :control && dec_control_bounds
                        _row_hlines(model, r, control_bounds_style)
                    else
                        Vector{Plotting.HLine}[]
                    end
                    L(
                        _row_left_panel(
                            sol,
                            model,
                            r,
                            path_style;
                            connect=connect,
                            title=title,
                            path_samples=path_samples,
                        );
                        hlines=hl,
                        group=grp(:path),
                        time_name=tname,
                    )
                else
                    nothing
                end
                rnode = if right
                    L(
                        _row_dual_panel(
                            sol,
                            model,
                            r,
                            dual_style;
                            left_shown=left,
                            connect=connect,
                            title=top ? "dual" : "",
                            dual_samples=dual_samples,
                        );
                        group=grp(:dual),
                        time_name=tname,
                    )
                elseif left && two_columns
                    p = _row_unknown_dual_panel(
                        sol, r, dual_style; title=top ? "dual" : ""
                    )
                    xm = _mid_time(p.x, time)
                    L(
                        p;
                        group=grp(:dual),
                        time_name=tname,
                        extra=[Plotting.Annotation(xm, "dual not known"; y=0.5)],
                    )
                else
                    nothing
                end
                push!(row_nodes, _pair(lnode, rnode))
            end
        end
        return _assemble_split(;
            state=state_col,
            costate=costate_col,
            control=control_col,
            rows=row_nodes,
        )
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid layout choice";
                got="layout=$layout",
                expected=":group or :split",
                context="CTModels.PlotCase._build_root",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Build the [`CTBase.Plotting.Figure`](@extref) for a CTModels `sol` (or `nothing`
if there is nothing to draw). Backend-agnostic entry point of the case layer: it
resolves the `description`, gates the groups, builds the panels and decorations,
assembles the layout template and wraps it in a `Figure`. The `CTModelsPlots` /
`CTModelsMakie` extensions render the result with a concrete backend.

# Keyword arguments
- `layout::Symbol = :split`: `:split` (one subplot per component) or `:group`.
- `control::Symbol = :components`: `:components`, `:norm` or `:all`.
- `time::Symbol = :default`: `:default` or `:normalize` / `:normalise`.
- `size`: figure size; `nothing` defers to the engine heuristic.
- the `*_style` / `*_bounds_style` / `time_style` keywords: a `NamedTuple` of
  attributes or `:none` to hide the group / decoration.
- `switching_style = NamedTuple()`: style of the vertical lines at the switching times
  (see [`CTModels.Solutions.switching_times`](@extref)); by default they look like the
  initial/final time lines (`time_style` included); `:none` hides them.
- `phase_labels::Symbol = :control`: where to write the phase labels (see
  [`CTModels.Solutions.phase_labels`](@extref)): `:control` (the control cell, or the
  first drawn group when the control is not drawn), `:all` (every group) or `:none`.
- `phase_labels_style::NamedTuple = NamedTuple()`: style of the phase labels (`color`,
  `fontsize`, `halign`, `valign`).
- `jumps::Symbol = :segment`: how a jump at a switching time is drawn: `:segment`, a
  vertical segment from the left to the right limit (it makes the jumps easy to see and to
  compare with a smoothed jump, e.g. from a direct method), or `:none`, the curve is broken
  between the two limits (no segment suggests values the trajectory does not take).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): for an invalid `layout`, `control`,
  `time`, `phase_labels` or `jumps`.
"""
function build_figure(
    sol::CTModels.Solution,
    description::Symbol...;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    state_style::Union{NamedTuple,Symbol}=__plot_style(),
    costate_style::Union{NamedTuple,Symbol}=__plot_style(),
    control_style::Union{NamedTuple,Symbol}=__plot_style(),
    path_style::Union{NamedTuple,Symbol}=__plot_style(),
    dual_style::Union{NamedTuple,Symbol}=__plot_style(),
    time_style::Union{NamedTuple,Symbol}=__plot_style(),
    state_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    control_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    path_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    switching_style::Union{NamedTuple,Symbol}=__plot_style(),
    phase_labels::Symbol=__phase_labels(),
    phase_labels_style::NamedTuple=__plot_style(),
    jumps::Symbol=__plot_jumps(),
    size=nothing,
)
    root = _build_root(
        sol,
        description...;
        layout=layout,
        control=control,
        time=time,
        state_style=state_style,
        costate_style=costate_style,
        control_style=control_style,
        path_style=path_style,
        dual_style=dual_style,
        time_style=time_style,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        path_bounds_style=path_bounds_style,
        switching_style=switching_style,
        phase_labels=phase_labels,
        phase_labels_style=phase_labels_style,
        jumps=jumps,
    )
    root === nothing && return nothing
    return Plotting.Figure(root; size=size)
end

"""
Keyword-argument names consumed by [`build_figure`](@ref); every other keyword a
user passes to `plot(sol; …)` is forwarded to the rendering backend.
"""
const _BUILD_KEYS = (
    :layout,
    :control,
    :time,
    :state_style,
    :costate_style,
    :control_style,
    :path_style,
    :dual_style,
    :time_style,
    :state_bounds_style,
    :control_bounds_style,
    :path_bounds_style,
    :switching_style,
    :phase_labels,
    :phase_labels_style,
    :jumps,
)

"""
$(TYPEDSIGNATURES)

Split the user keyword arguments of `plot(sol; …)` into the pair
`(build, render)`: `build` holds the `_BUILD_KEYS` consumed by [`build_figure`](@ref),
`render` holds everything else (forwarded to the `CTBase.Plotting` backend).
"""
function split_plot_kwargs(kwargs)
    build = NamedTuple(k => v for (k, v) in pairs(kwargs) if k in _BUILD_KEYS)
    render = NamedTuple(k => v for (k, v) in pairs(kwargs) if !(k in _BUILD_KEYS))
    return build, render
end
