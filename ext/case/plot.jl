# =============================================================================
# plot.jl — public Plots.plot / plot! for CTModels solutions.
#
# The thin public methods forward to `_plot` / `_plot!`, which resolve the
# description, gate the groups (`do_plot`), build the panels, assemble the layout
# tree and delegate all rendering to `CTBase.Plotting`.
#
# Docstrings deferred (Handbook convention).
# =============================================================================

# Time-axis name, with the historical "(normalized)" suffix when time is rescaled.
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

# Build the layout tree (or `nothing` if there is nothing to draw). Decorations
# (bounds, initial/final time lines) are added in Phase 3c; path/dual in Phase 3b.
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
                CTModels.control_constraints_box(model), ncomp(cp), control_bounds_style
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
                context="CTModelsPlots plot layout",
            ),
        )
    end
end

function _plot(
    sol::CTModels.Solution,
    description::Symbol...;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    state_style::Union{NamedTuple,Symbol}=__plot_style(),
    state_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    control_style::Union{NamedTuple,Symbol}=__plot_style(),
    control_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    costate_style::Union{NamedTuple,Symbol}=__plot_style(),
    time_style::Union{NamedTuple,Symbol}=__plot_style(),
    path_style::Union{NamedTuple,Symbol}=__plot_style(),
    path_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    dual_style::Union{NamedTuple,Symbol}=__plot_style(),
    size=nothing,
    color=nothing,
    kwargs...,
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
    # Nothing to draw (empty description, every group :none, or only path/dual in
    # :group): return an empty figure, as the historical CTModels plot did.
    root === nothing && return Plots.plot()
    fig = Plotting.Figure(root; size=size)
    return if color === nothing
        Plotting.render(fig; kwargs...)
    else
        Plotting.render(fig; color=color, kwargs...)
    end
end

function _plot!(
    p::Plots.Plot,
    sol::CTModels.Solution,
    description::Symbol...;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    state_style::Union{NamedTuple,Symbol}=__plot_style(),
    state_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    control_style::Union{NamedTuple,Symbol}=__plot_style(),
    control_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    costate_style::Union{NamedTuple,Symbol}=__plot_style(),
    time_style::Union{NamedTuple,Symbol}=__plot_style(),
    path_style::Union{NamedTuple,Symbol}=__plot_style(),
    path_bounds_style::Union{NamedTuple,Symbol}=__plot_style(),
    dual_style::Union{NamedTuple,Symbol}=__plot_style(),
    color=nothing,
    kwargs...,
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
    root === nothing && return p
    fig = Plotting.Figure(root)
    # Empty target (e.g. `plot!(sol)` onto a bare `plot()`): the figure has no cells to
    # overlay, so build a fresh figure and substitute it field-by-field into `p`,
    # preserving `p`'s identity — the historical empty-figure path (R1).
    if isempty(p.series_list)
        fresh = if color === nothing
            Plotting.render(fig; kwargs...)
        else
            Plotting.render(fig; color=color, kwargs...)
        end
        for k in fieldnames(typeof(p))
            setfield!(p, k, getfield(fresh, k))
        end
        return p
    end
    return if color === nothing
        Plotting.render!(p, fig; kwargs...)
    else
        Plotting.render!(p, fig; color=color, kwargs...)
    end
end

# --- public methods (thin; forward to _plot / _plot!) ------------------------

"""
$(TYPEDSIGNATURES)

Plot the components of an optimal control [`CTModels.Solution`](@ref).

Generates a set of subplots showing the state, control, costate, path constraints and
dual variables over time, depending on the problem and the given `description`.

# Arguments
- `sol`: the optimal control solution to visualise.
- `description`: symbols selecting which groups to include; any of `:state`, `:costate`,
  `:control`, `:path` (path constraints), `:dual` (their multipliers). If none is given,
  a default set is used based on the problem.

# Keyword arguments
- `layout::Symbol = :split`: `:split` (one subplot per component) or `:group` (group
  each signal into a single subplot with a legend).
- `control::Symbol = :components`: `:components` (a curve per control component), `:norm`
  (the Euclidean norm `‖u(t)‖`) or `:all` (both).
- `time::Symbol = :default`: `:default` (real time) or `:normalize`/`:normalise` (`[0, 1]`).
- `color`: colour applied to every curve.
- `size`: figure size; defaults to a heuristic based on the layout.

## Style options
Each `*_style` keyword is a `NamedTuple` of plotting attributes, or `:none` to hide the
group/decoration: `state_style`, `costate_style`, `control_style`, `path_style`,
`dual_style`, `time_style` (initial/final time markers), and the bounds decorations
`state_bounds_style`, `control_bounds_style`, `path_bounds_style`.

# Returns
A `Plots.Plot`. All layout and rendering is delegated to `CTBase.Plotting`.

# Example
```julia-repl
julia> plot(sol)
julia> plot(sol, :state, :control; layout=:group, control=:all)
julia> plot(sol; state_style=(color=:blue,), costate_style=:none)
```
"""
function Plots.plot(sol::CTModels.Solution, description::Symbol...; kwargs...)
    return _plot(sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Overlay the optimal control solution `sol` onto the existing plot `p`. Same behaviour and
keyword arguments as [`Plots.plot(::CTModels.Solution)`](@ref); an empty `p` is filled as
if by `plot`.
"""
function Plots.plot!(
    p::Plots.Plot, sol::CTModels.Solution, description::Symbol...; kwargs...
)
    return _plot!(p, sol, description...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Overlay the optimal control solution `sol` onto the current plot (`Plots.current()`).
"""
function Plots.plot!(sol::CTModels.Solution, description::Symbol...; kwargs...)
    return _plot!(Plots.current(), sol, description...; kwargs...)
end
