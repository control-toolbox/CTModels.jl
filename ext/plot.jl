"""
$(TYPEDEF)

Abstract node for plot.
"""
abstract type AbstractPlotTreeElement end

"""
$(TYPEDEF)

A leaf of a plot tree.
"""
struct PlotLeaf <: AbstractPlotTreeElement end

"""
$(TYPEDEF)

A node of a plot tree.
"""
struct PlotNode{TL<:Union{Symbol,Matrix{Any}},TC<:Vector{<:AbstractPlotTreeElement}} <:
       AbstractPlotTreeElement
    layout::TL
    children::TC
    function PlotNode(
        layout::Union{Symbol,Matrix{Any}}, children::Vector{<:AbstractPlotTreeElement}
    )
        return new{typeof(layout),typeof(children)}(layout, children)
    end
end

# --------------------------------------------------------------------------------------------------
# internal plots: plot a function of time
"""
$(TYPEDSIGNATURES)

Update the plot `p` with the i-th component of a vectorial function of time `f(t) ∈ Rᵈ` where
`f` is given by the symbol `s`.
- The argument `s` can be `:state`, `:control` or `:costate`.
- `time` can be `:default` or `:normalize`.
"""
function __plot_time!(
    p::Union{Plots.Plot,Plots.Subplot},
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    s::Symbol,
    i::Int,
    time::Symbol;
    t_label::String,
    label::String,
    kwargs...,
)

    # t_label depends if time is normalize or not
    t_label = @match time begin
        :default => t_label
        :normalize => "normalized " * t_label
        :normalise => "normalised " * t_label
        _ => throw(
            CTBase.IncorrectArgument(
                "Internal error, no such choice for time: $time. Use :default, :normalize or :normalise",
            ),
        )
    end

    # reset ylims: ylims=:auto
    Plots.plot!(
        p, sol, model, :time, (s, i), time; ylims=:auto, xlabel=t_label, label=label, kwargs...
    ) # use plot recipe

    # change ylims if the gap between min and max is less than a tol
    tol = 1e-3
    ymin = Inf
    ymax = -Inf

    for s in p.series_list
        y = s[:y]
        ymin = min(minimum(y), ymin)
        ymax = max(maximum(y), ymax)
    end

    if (ymin != Inf) && (ymax != -Inf) && (abs(ymax - ymin) ≤ abs(ymin) * tol)
        ymiddle = (ymin + ymax) / 2.0
        if (abs(ymiddle) < 1e-12)
            ylims!(p, (-0.1, 0.1))
        else
            if ymiddle > 0
                ylims!(p, (0.9 * ymiddle, 1.1 * ymiddle))
            else
                ylims!(p, (1.1 * ymiddle, 0.9 * ymiddle))
            end
        end
    end

    return p
end

"""
$(TYPEDSIGNATURES)

Plot the i-th component of a vectorial function of time `f(t) ∈ Rᵈ` where `f` is given by the symbol `s`.
- The argument `s` can be `:state`, `:control` or `:costate`.
- `time` can be `:default` or `:normalize`.
"""
function __plot_time(
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    s::Symbol,
    i::Int,
    time::Symbol;
    t_label::String,
    label::String,
    kwargs...,
)
    return __plot_time!(
        Plots.plot(), sol, model, s, i, time; t_label=t_label, label=label, kwargs...
    )
end

"""
$(TYPEDSIGNATURES)

Update the plot `p` with a vectorial function of time `f(t) ∈ Rᵈ` where `f` is given by the symbol `s`.
- The argument `s` can be `:state`, `:control` or `:costate`.
- `time` can be `:default` or `:normalize`.
"""
function __plot_time!(
    p::Union{Plots.Plot,Plots.Subplot},
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    d::CTModels.Dimension,
    s::Symbol,
    time::Symbol;
    t_label::String,
    labels::Vector{String},
    title::String,
    kwargs...,
)
    Plots.plot!(p; xlabel="time", title=title, kwargs...)

    for i in range(1, d)
        __plot_time!(p, sol, model, s, i, time; t_label=t_label, label=labels[i], kwargs...)
    end

    return p
end

"""
$(TYPEDSIGNATURES)

Plot a vectorial function of time `f(t) ∈ Rᵈ` where `f` is given by the symbol `s`.
The argument `s` can be `:state`, `:control` or `:costate`.
"""
function __plot_time(
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    d::CTModels.Dimension,
    s::Symbol,
    time::Symbol;
    t_label::String,
    labels::Vector{String},
    title::String,
    kwargs...,
)
    return __plot_time!(
        Plots.plot(),
        sol,
        model,
        d,
        s,
        time;
        t_label=t_label,
        labels=labels,
        title=title,
        kwargs...,
    )
end

# --------------------------------------------------------------------------------------------------
# 
"""
$(TYPEDSIGNATURES)

Generate a{r*h} where `r` is a real number and `h` is the height of the plot.
"""
function __height(r::Real)::Expr
    i = Expr(:call, :*, r, :h)
    a = Expr(:curly, :a, i)
    return a
end

"""
$(TYPEDSIGNATURES)

Plot a leaf.
"""
function __plot_tree(leaf::PlotLeaf, depth::Int; kwargs...)
    return Plots.plot()
end

"""
$(TYPEDSIGNATURES)

Plot a node.
"""
function __plot_tree(node::PlotNode, depth::Int=0; kwargs...)
    #
    subplots = ()
    #
    for c in node.children
        pc = __plot_tree(c, depth + 1)
        subplots = (subplots..., pc)
    end
    #
    kwargs_plot = depth == 0 ? kwargs : ()
    ps = @match node.layout begin
        :row => plot(subplots...; layout=(1, size(subplots, 1)), kwargs_plot...)
        :column => plot(subplots...; layout=(size(subplots, 1), 1), kwargs_plot...)
        _ => plot(subplots...; layout=node.layout, kwargs_plot...)
    end

    return ps
end

# --------------------------------------------------------------------------------------------------
# private plots: initial plot
"""
$(TYPEDSIGNATURES)

Initial plot.
"""
function __initial_plot(
    sol::CTModels.Solution;
    layout::Symbol,
    control::Symbol,
    model::Union{CTModels.Model,Nothing},
    kwargs...,
)

    # parameters
    n = CTModels.state_dimension(sol)
    m = CTModels.control_dimension(sol)

    if layout == :group
        @match control begin
            :components => begin
                px = Plots.plot() # state
                pp = Plots.plot() # costate
                pu = Plots.plot() # control
                return Plots.plot(px, pp, pu; layout=(1, 3), bottommargin=5mm, kwargs...)
            end
            :norm => begin
                px = Plots.plot() # state
                pp = Plots.plot() # costate
                pn = Plots.plot() # control norm
                return Plots.plot(px, pp, pn; layout=(1, 3), bottommargin=5mm, kwargs...)
            end
            :all => begin
                px = Plots.plot() # state
                pp = Plots.plot() # costate
                pu = Plots.plot() # control
                pn = Plots.plot() # control norm
                return Plots.plot(px, pp, pu, pn; layout=(2, 2), bottommargin=5mm, kwargs...)
            end
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end

    elseif layout == :split

        # create tree plot
        state_plots = Vector{PlotLeaf}()
        costate_plots = Vector{PlotLeaf}()
        control_plots = Vector{PlotLeaf}()

        # create the state and costate plots
        for i in 1:n
            push!(state_plots, PlotLeaf())
            push!(costate_plots, PlotLeaf())
        end

        # create the control plots
        l = m
        @match control begin
            :components => begin
                for i in 1:m
                    push!(control_plots, PlotLeaf())
                end
            end
            :norm => begin
                push!(control_plots, PlotLeaf())
                l = 1
            end
            :all => begin
                for i in 1:m
                    push!(control_plots, PlotLeaf())
                end
                push!(control_plots, PlotLeaf())
                l = m + 1
            end
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end

        # assemble the state and costate plots
        node_x = PlotNode(:column, state_plots)
        node_p = PlotNode(:column, costate_plots)
        node_xp = PlotNode(:row, [node_x, node_p])

        # assemble the control plots
        node_u = PlotNode(:column, control_plots)

        # create the root node
        a = __height(round(n / (n + l); digits=2))
        @eval lay = @layout [
            $a
            b
        ]
        root = PlotNode(lay, [node_xp, node_u])

        # Add the path constraints and their dual variables (in two columns as for state and costate) plots 
        # if layout is :split, model is not nothing and there are path constraints
        nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
        if nc > 0
            # create the path constraints and dual variables plots
            path_constraints_plots = Vector{PlotLeaf}()
            path_constraints_dual_plots = Vector{PlotLeaf}()
            for i in 1:nc
                push!(path_constraints_plots, PlotLeaf())
                push!(path_constraints_dual_plots, PlotLeaf())
            end

            # assemble the path constraints and dual variables plots
            node_co = PlotNode(:column, path_constraints_plots)
            node_cp = PlotNode(:column, path_constraints_dual_plots)
            node_cocp = PlotNode(:row, [node_co, node_cp])

            # update the root node
            c = __height(round(nc / (n + l + nc); digits=2))
            @eval lay = @layout [
                a
                $c
            ]
            root = PlotNode(lay, [root, node_cocp])
        end

        # plot
        return __plot_tree(root; kwargs...)

    else
        throw(CTBase.IncorrectArgument("No such choice for layout. Use :group or :split"))
    end
end

"""
$(TYPEDSIGNATURES)

Return the series attributes.
"""
function __keep_series_attributes(; kwargs...)
    series_attributes = Plots.attributes(:Series)

    out = []
    for kw in kwargs
        kw[1] ∈ series_attributes && push!(out, kw)
    end

    return out
end

# --------------------------------------------------------------------------------------------------
# private plots: from a solution and optionally the model
"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- `control` can be `:components`, `:norm` or `:all`.
- `time` can be `:default` or `:normalize`.
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function __plot!(
    p::Plots.Plot,
    sol::CTModels.Solution;
    solution_label::String,
    model::Union{CTModels.Model,Nothing},
    time::Symbol,
    control::Symbol,
    layout::Symbol,
    time_style::Tuple,
    state_style::Tuple,
    state_bounds_style::Tuple,
    control_style::Tuple,
    control_bounds_style::Tuple,
    costate_style::Tuple,
    path_style::Tuple,
    path_bounds_style::Tuple,
    dual_path_style::Tuple,
    kwargs...,
)
    if solution_label != ""
        solution_label = " " * solution_label
    end

    #
    n = CTModels.state_dimension(sol)
    m = CTModels.control_dimension(sol)
    x_labels = CTModels.state_components(sol)
    u_labels = CTModels.control_components(sol)
    u_label = CTModels.control_name(sol)
    t_label = CTModels.time_name(sol)

    #
    title_font = font(12, Plots.default(:fontfamily))

    # split series attributes 
    series_attr = __keep_series_attributes(; kwargs...)

    if layout == :group
        __plot_time!(
            p[1],
            sol,
            model,
            n,
            :state,
            time;
            t_label=t_label,
            labels=x_labels .* solution_label,
            title="state",
            titlefont=title_font,
            lims=:auto,
            series_attr...,
            state_style...,
        )
        __plot_time!(
            p[2],
            sol,
            model,
            n,
            :costate,
            time;
            t_label=t_label,
            labels="p" .* x_labels .* solution_label,
            title="costate",
            titlefont=title_font,
            lims=:auto,
            series_attr...,
            costate_style...,
        )
        @match control begin
            :components => begin
                __plot_time!(
                    p[3],
                    sol,
                    model,
                    m,
                    :control,
                    time;
                    t_label=t_label,
                    labels=u_labels .* solution_label,
                    title="control",
                    titlefont=title_font,
                    lims=:auto,
                    series_attr...,
                    control_style...,
                )
            end
            :norm => begin
                __plot_time!(
                    p[3],
                    sol,
                    model,
                    :control_norm,
                    -1,
                    time;
                    t_label=t_label,
                    label="‖" * u_label * "‖" .* solution_label,
                    title="control norm",
                    titlefont=title_font,
                    lims=:auto,
                    series_attr...,
                    control_style...,
                )
            end
            :all => begin
                __plot_time!(
                    p[3],
                    sol,
                    model,
                    m,
                    :control,
                    time;
                    t_label=t_label,
                    labels=u_labels .* solution_label,
                    title="control",
                    titlefont=title_font,
                    lims=:auto,
                    series_attr...,
                    control_style...,
                )
                __plot_time!(
                    p[4],
                    sol,
                    model,
                    :control_norm,
                    -1,
                    time;
                    t_label=t_label,
                    label="‖" * u_label * "‖" .* solution_label,
                    title="control norm",
                    titlefont=title_font,
                    lims=:auto,
                    series_attr...,
                    control_style...,
                )
            end
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end

    elseif layout == :split

        # plot the state and costate
        for i in 1:n
            __plot_time!(
                p[i],
                sol,
                model,
                :state,
                i,
                time;
                t_label = i==n ? t_label : "",
                label=x_labels[i] * solution_label,
                series_attr...,
                state_style...,
            )
            __plot_time!(
                p[i + n],
                sol,
                model,
                :costate,
                i,
                time;
                t_label = i==n ? t_label : "",
                label="p" * x_labels[i] * solution_label,
                series_attr...,
                costate_style...,
            )
        end

        # plot the state constraints if layout is :split and model is not nothing
        if !(model === nothing)
            cs = CTModels.state_constraints_box(model)
            is = 1
            for i in 1:length(cs[1])
                hline!(p[is + cs[2][i] - 1], [cs[1][i]]; color=4, linewidth=1, label=:none, z_order=:back, series_attr..., state_bounds_style...) # lower bound
                hline!(p[is + cs[2][i] - 1], [cs[3][i]], color=4, linewidth=1, label=:none, z_order=:back, series_attr..., state_bounds_style...) # upper bound
            end
        end

        # plot the control
        l = m
        @match control begin
            :components => begin
                for i in 1:m
                    __plot_time!(
                        p[i + 2 * n],
                        sol,
                        model,
                        :control,
                        i,
                        time;
                        t_label = i==m ? t_label : "",
                        label=u_labels[i] * solution_label,
                        series_attr...,
                        control_style...,
                    )
                end
            end
            :norm => begin
                l = 1
                __plot_time!(
                    p[2 * n + 1],
                    sol,
                    model,
                    :control_norm,
                    -1,
                    time;
                    t_label=t_label,
                    label="‖" * u_label * "‖" * solution_label,
                    series_attr...,
                    control_style...,
                )
            end
            :all => begin
                l = m + 1
                for i in 1:m
                    __plot_time!(
                        p[i + 2 * n],
                        sol,
                        model,
                        :control,
                        i,
                        time;
                        t_label="",
                        label=u_labels[i] * solution_label,
                        series_attr...,
                        control_style...,
                    )
                end
                __plot_time!(
                    p[2 * n + m + 1],
                    sol,
                    model,
                    :control_norm,
                    -1,
                    time;
                    t_label=t_label,
                    label="‖" * u_label * "‖" * solution_label,
                    series_attr...,
                    control_style...,
                )
            end
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end

        # plot the control constraints if layout is :split and model is not nothing
        if !(model === nothing) && (control != :norm)
            cu = CTModels.control_constraints_box(model)
            iu = 2n + 1
            for i in 1:length(cu[1])
                hline!(p[iu + cu[2][i] - 1], [cu[1][i]]; color=4, linewidth=1, label=:none, z_order=:back, series_attr..., control_bounds_style...) # lower bound
                hline!(p[iu + cu[2][i] - 1], [cu[3][i]], color=4, linewidth=1, label=:none, z_order=:back, series_attr..., control_bounds_style...) # upper bound
            end
        end

        # plot the path constraints if layout is :split, model is not nothing and there are path constraints
        # and the dual variables
        nc = if model === nothing
            0
        else
            CTModels.dim_path_constraints_nl(model)
        end
        if nc >0
            # retrieve the constraints
            cp = CTModels.path_constraints_nl(model)

            # plot the constraints and the dual variables
            ic = 2n + l + 1
            for i in 1:nc
                __plot_time!(
                    p[ic + i - 1],
                    sol,
                    model,
                    :path_constraint,
                    i,
                    time;
                    t_label = i==nc ? t_label : "",
                    label = string(cp[4][i]) * solution_label,
                    series_attr...,
                    path_style...,
                )
                __plot_time!(
                    p[ic + i - 1 + nc],
                    sol,
                    model,
                    :dual_path_constraint,
                    i,
                    time;
                    t_label = i==nc ? t_label : "",
                    label = "dual " * string(cp[4][i]) * solution_label,
                    series_attr...,
                    dual_path_style...,
                )
            end

            # plot the lower and upper bounds for the path constraints
            for i in 1:nc
                hline!(p[ic + i - 1], [cp[1][i]]; color=4, linewidth=1, label=:none, z_order=:back, series_attr..., path_bounds_style...) # lower bound
                hline!(p[ic + i - 1], [cp[3][i]], color=4, linewidth=1, label=:none, z_order=:back, series_attr..., path_bounds_style...) # upper bound
            end
        end
    else
        throw(CTBase.IncorrectArgument("No such choice for layout. Use :group or :split"))
    end

    # plot vertical lines at the initial and final times if model is not nothing
    if !(model === nothing)
        if time == :normalize || time == :normalise
            t0 = 0.0
            tf = 1.0
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
        for plt ∈ p.subplots
            vline!(plt, [t0, tf]; color=:black, linestyle=:dash, linewidth=1, label=:none, z_order=:back, series_attr..., time_style...)
        end
    end

    return p
end

"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function __plot(
    sol::CTModels.Solution;
    solution_label::String,
    model::Union{CTModels.Model,Nothing},
    time::Symbol,
    control::Symbol,
    layout::Symbol,
    time_style::Tuple,
    state_style::Tuple,
    state_bounds_style::Tuple,
    control_style::Tuple,
    control_bounds_style::Tuple,
    costate_style::Tuple,
    path_style::Tuple,
    path_bounds_style::Tuple,
    dual_path_style::Tuple,
    size=__size_plot(sol, model, control, layout),
    kwargs...,
)

    p = __initial_plot(sol; layout=layout, control=control, model=model, size=size, kwargs...)

    return __plot!(
        p,
        sol;
        layout=layout,
        control=control,
        time=time,
        solution_label=solution_label,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=model,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        time_style=time_style,
        path_style=path_style,
        path_bounds_style=path_bounds_style,
        dual_path_style=dual_path_style,
        kwargs...,
    )
end

# --------------------------------------------------------------------------------------------------
# public plots: from a solution
"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol` using the layout `layout`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- `control` can be `:components`, `:norm` or `:all`.
- `time` can be `:default` or `:normalize`.
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function Plots.plot!(
    p::Plots.Plot,
    sol::CTModels.Solution;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    solution_label::String=__plot_label_suffix(),
    state_style=__plot_style(),
    control_style=__plot_style(),
    costate_style=__plot_style(),
    kwargs...,
)

    return __plot!(
        p,
        sol;
        layout=layout,
        control=control,
        time=time,
        solution_label=solution_label,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=nothing,
        state_bounds_style=(),
        control_bounds_style=(),
        time_style=(),
        path_style=(),
        path_bounds_style=(),
        dual_path_style=(),
        kwargs...,
    )
end

"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function Plots.plot(
    sol::CTModels.Solution;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    solution_label::String=__plot_label_suffix(),
    state_style=__plot_style(),
    control_style=__plot_style(),
    costate_style=__plot_style(),
    size=__size_plot(sol, nothing, control, layout),
    kwargs...,
)
    return __plot(
        sol;
        layout=layout,
        control=control,
        time=time,
        solution_label=solution_label,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=nothing,
        state_bounds_style=(),
        control_bounds_style=(),
        time_style=(),
        path_style=(),
        path_bounds_style=(),
        dual_path_style=(),
        size=size,
        kwargs...,
    )
end

# --------------------------------------------------------------------------------------------------
# public plots: from a solution and the model
"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol` using the layout `layout`. The model is used to represent the initial and final times and the constraints.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- `control` can be `:components`, `:norm` or `:all`.
- `time` can be `:default` or `:normalize`.
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
- The keyword arguments `time_style` are passed to the `vline!` function of the `Plots` package. The `time_style` is passed to the plot of the vertical lines at the initial and final times.
"""
function Plots.plot!(
    p::Plots.Plot,
    sol::CTModels.Solution,
    model::CTModels.Model;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    solution_label::String=__plot_label_suffix(),
    state_style::Tuple=__plot_style(),
    state_bounds_style::Tuple=__plot_style(),
    control_style::Tuple=__plot_style(),
    control_bounds_style::Tuple=__plot_style(),
    costate_style::Tuple=__plot_style(),
    time_style::Tuple=__plot_style(),
    path_style::Tuple=__plot_style(),
    path_bounds_style::Tuple=__plot_style(),
    dual_path_style::Tuple=__plot_style(),
    kwargs...,
)

    # plot the solution with infos from the model
    return __plot!(
        p,
        sol;
        layout=layout,
        control=control,
        time=time,
        solution_label=solution_label,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=model,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        time_style=time_style,
        path_style=path_style,
        path_bounds_style=path_bounds_style,
        dual_path_style=dual_path_style,
        kwargs...,
    )

end


"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol` using the layout `layout`. The model is used to represent the initial and final times and the constraints.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
- The keyword arguments `time_style` are passed to the `vline!` function of the `Plots` package. The `time_style` is passed to the plot of the vertical lines at the initial and final times.
"""
function Plots.plot(
    sol::CTModels.Solution,
    model::CTModels.Model;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    solution_label::String=__plot_label_suffix(),
    state_style::Tuple=__plot_style(),
    state_bounds_style::Tuple=__plot_style(),
    control_style::Tuple=__plot_style(),
    control_bounds_style::Tuple=__plot_style(),
    costate_style::Tuple=__plot_style(),
    time_style::Tuple=__plot_style(),
    path_style::Tuple=__plot_style(),
    path_bounds_style::Tuple=__plot_style(),
    dual_path_style::Tuple=__plot_style(),
    size=__size_plot(sol, model, control, layout),
    kwargs...,
)
    return __plot(
        sol;
        layout=layout,
        control=control,
        time=time,
        solution_label=solution_label,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=model,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        time_style=time_style,
        path_style=path_style,
        path_bounds_style=path_bounds_style,
        dual_path_style=dual_path_style,
        size=size,
        kwargs...,
    )
end

# --------------------------------------------------------------------------------------------------
# plot recipe
"""
$(TYPEDSIGNATURES)

Return `x` and `y` for the plot of the optimal control solution `sol` 
corresponding respectively to the argument `xx` and the argument `yy`.

**Notes.**

- The argument `xx` can be `:time`, `:state`, `:control` or `:costate`.
- If `xx` is `:time`, then, a label is added to the plot.
- The argument `yy` can be `:state`, `:control` or `:costate`.
"""
@recipe function f(
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    xx::Union{Symbol,Tuple{Symbol,Int}},
    yy::Union{Symbol,Tuple{Symbol,Int}},
    time::Symbol=:default,
)

    #
    x = __get_data_plot(sol, model, xx; time=time)
    y = __get_data_plot(sol, model, yy; time=time)

    #
    #label := recipe_label(sol, xx, yy)
    color := 1           # default color
    linestyle := :solid  # default linestyle
    linewidth := 2       # default linewidth
    z_order := :front    # default z_order

    return x, y
end

"""
$(TYPEDSIGNATURES)

Get the data for plotting.
"""
function __get_data_plot(
    sol::CTModels.Solution, 
    model::Union{CTModels.Model,Nothing},
    xx::Union{Symbol,Tuple{Symbol,Int}}; 
    time::Symbol=:default
)

    # if the time grid is empty then throw an error
    if CTModels.is_empty_time_grid(sol) == true
        throw(CTBase.IncorrectArgument("The time grid is empty"))
    end

    vv, ii = @match xx begin
        ::Symbol => (xx, 1)
        _ => xx
    end

    T = CTModels.time_grid(sol)
    m = size(T, 1)
    return @match vv begin
        :time => begin
            @match time begin
                :default => T
                :normalize => (T .- T[1]) ./ (T[end] - T[1])
                :normalise => (T .- T[1]) ./ (T[end] - T[1])
                _ => error(
                    "Internal error, no such choice for time: $time. Use :default, :normalize or :normalise",
                )
            end
        end
        :state => begin
            X = CTModels.state(sol).(T)
            [X[i][ii] for i in 1:m] 
        end
        :control => begin
            U = CTModels.control(sol).(T)
            [U[i][ii] for i in 1:m] 
        end
        :costate => begin
            P = CTModels.costate(sol).(T)
            [P[i][ii] for i in 1:m] 
        end
        :control_norm => begin
            U = CTModels.control(sol).(T)
            [norm(U[i]) for i in 1:m]
        end
        :path_constraint => begin 
            X = CTModels.state(sol).(T)
            U = CTModels.control(sol).(T)
            v = CTModels.variable(sol)
            pc = CTModels.path_constraints_nl(model)
            C = zeros(Float64, m)
            g = zeros(Float64, length(pc[1]))
            for i in 1:m
                pc[2](g, T[i], X[i], U[i], v)
                C[i] = g[ii]
            end
            C
        end
        :dual_path_constraint => begin
            D = CTModels.path_constraints_dual(sol).(T)
            [D[i][ii] for i in 1:m]
        end
        _ => error("Internal error, no such choice for xx")
    end
end
