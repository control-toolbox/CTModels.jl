# =============================================================================
# build.jl — resolve description → gate groups → build panels → assemble tree →
# CTBase.Plotting.Figure.
#
# `build_figure` is the single backend-agnostic entry point of the case layer:
# the `CTModelsPlots` / `CTModelsMakie` extensions call it and hand the figure to
# a `CTBase.Plotting.render` backend. It also owns the user-facing defaults, so
# the two extensions only forward keyword arguments.
#
# Docstrings deferred where the historical helpers already carried none (Handbook).
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
)
    model = CTModels.model(sol)
    desc = clean(isempty(description) ? __description() : description)
    do_state, do_costate, do_control, do_path, do_dual = do_plot(
        sol,
        desc...;
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
    )
    dec_time, dec_state_bounds, dec_control_bounds, dec_path_bounds = do_decorate(;
        model=model,
        time_style=time_style,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        path_bounds_style=path_bounds_style,
    )
    tn = _time_name(sol, time)
    # Initial/final time markers are shared by every cell (both layouts).
    vlines = dec_time ? _time_vlines(sol, model, time, time_style) : Plotting.VLine[]
    ncomp(p) = size(p.data, 2)
    L(p; hlines=Vector{Plotting.HLine}[]) = Plotting.lower(
        p; layout=layout, time=time, time_name=tn, vlines=vlines, hlines=hlines
    )

    if layout === :group
        # No bounds lines in :group (historical); only the time markers, via `vlines`.
        cells = Plotting.AbstractLayoutNode[]
        do_state && push!(cells, L(_state_panel(sol, state_style)))
        do_costate && push!(
            cells,
            L(_costate_panel(sol, costate_style; layout=layout, state_shown=do_state)),
        )
        if do_control
            for cp in _control_panels(sol, control, control_style, layout)
                push!(cells, L(cp))
            end
        end
        isempty(cells) && return nothing
        return _assemble_group(cells)
    elseif layout === :split
        state_col = nothing
        if do_state
            sp = _state_panel(sol, state_style)
            hl = if dec_state_bounds
                _box_hlines(
                    CTModels.state_constraints_box(model), ncomp(sp), state_bounds_style
                )
            else
                Vector{Plotting.HLine}[]
            end
            state_col = L(sp; hlines=hl)
        end
        costate_col = if do_costate
            L(_costate_panel(sol, costate_style; layout=layout, state_shown=do_state))
        else
            nothing
        end
        control_col = nothing
        if do_control
            cp = only(_control_panels(sol, control, control_style, layout))
            hl = if (dec_control_bounds && control !== :norm)
                _box_hlines(
                    CTModels.control_constraints_box(model),
                    ncomp(cp),
                    control_bounds_style,
                )
            else
                Vector{Plotting.HLine}[]
            end
            control_col = L(cp; hlines=hl)
        end
        path_col = nothing
        if do_path
            pp = _path_panel(sol, model, path_style)
            hl = if dec_path_bounds
                _path_hlines(model, path_bounds_style)
            else
                Vector{Plotting.HLine}[]
            end
            path_col = L(pp; hlines=hl)
        end
        dual_col = if do_dual
            L(_dual_panel(sol, model, dual_style; path_shown=do_path))
        else
            nothing
        end
        return _assemble_split(;
            state=state_col,
            costate=costate_col,
            control=control_col,
            path=path_col,
            dual=dual_col,
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
