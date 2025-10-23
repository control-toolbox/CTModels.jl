"""
$(TYPEDEF)

Abstract supertype for nodes used in the plot tree structure.
This serves as a base for elements like `PlotLeaf`, `PlotNode`, and `EmptyPlot`.
"""
abstract type AbstractPlotTreeElement end

"""
$(TYPEDEF)

Represents a leaf node in a plot tree.

Typically used as an individual plot element without any children.
"""
struct PlotLeaf <: AbstractPlotTreeElement end

"""
$(TYPEDEF)

Represents a node with a layout and children in a plot tree.

# Fields
- `layout::Union{Symbol, Matrix{Any}}`: Layout specification, e.g., `:row`, `:column`, or a custom layout matrix.
- `children::Vector{<:AbstractPlotTreeElement}`: Subplots or nested plot nodes.
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

"""
$(TYPEDEF)

Represents an empty placeholder in the plot tree.

Used to maintain layout consistency when certain plots are omitted.
"""
struct EmptyPlot <: AbstractPlotTreeElement end

# --------------------------------------------------------------------------------------------------
# internal plots: plot a function of time
"""
$(TYPEDSIGNATURES)

Plot a single component `i` of a time-dependent vector-valued quantity (`:state`, `:control`, `:costate`, etc.).

# Arguments
- `p`: A `Plots.Plot` or `Plots.Subplot` object to update.
- `sol`: An optimal control `Solution`.
- `model`: The associated `Model` or `nothing`.
- `s`: Symbol indicating the signal type (`:state`, `:control`, `:costate`, `:control_norm`, etc.).
- `i`: Component index (use `-1` for `:control_norm`).
- `time`: Time normalization option (`:default`, `:normalize`, `:normalise`).

# Keyword Arguments
- `t_label`: Label for the time axis.
- `y_label`: Label for the vertical axis.
- `color`: color of the graph
- `kwargs...`: Additional plotting options.
"""
function __plot_time!(
    p::Union{Plots.Plot,Plots.Subplot},
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    s::Symbol,
    i::Int,
    time::Symbol;
    t_label::String,
    y_label::String="",
    color,
    kwargs...,
)

    # t_label depends if time is normalize or not
    t_label = @match time begin
        :default => t_label
        :normalize => t_label == "" ? "" : t_label * " (normalized)"
        :normalise => t_label == "" ? "" : t_label * " (normalised)"
        _ => throw(
            CTBase.IncorrectArgument(
                "Internal error, no such choice for time: $time. Use :default, :normalize or :normalise",
            ),
        )
    end

    #
    f(; kwargs...) = kwargs
    kwargs_plot = if isnothing(color)
        f(; ylims=:auto, xlabel=t_label, ylabel=y_label, linewidth=2, z_order=:front, kwargs...)
    else
        f(;
            color=color,
            ylims=:auto,
            xlabel=t_label,
            ylabel=y_label,
            linewidth=2,
            z_order=:front,
            kwargs...,
        )
    end

    # reset ylims: ylims=:auto
    Plots.plot!(p, sol, model, :time, (s, i), time; kwargs_plot...) # use plot recipe

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

Plot all components of a vector-valued signal over time.

# Arguments
- `d`: Dimension of the signal (number of components).
- `labels`: Vector of string labels for each component.
- `title`: Title of the subplot.

Other arguments are the same as for the scalar version of `__plot_time!`.
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
    color,
    kwargs...,
)
    Plots.plot!(p; xlabel="time", title=title, kwargs...)

    for i in range(1, d)
        __plot_time!(
            p,
            sol,
            model,
            s,
            i,
            time;
            color=color,
            t_label=t_label,
            label=labels[i],
            kwargs...,
        )
    end

    return p
end

# --------------------------------------------------------------------------------------------------
# 
"""
$(TYPEDSIGNATURES)

Return an empty plot for a `PlotLeaf`.

Used as a placeholder in layout trees.
"""
function __plot_tree(leaf::PlotLeaf, depth::Int; kwargs...)
    return Plots.plot()
end

"""
$(TYPEDSIGNATURES)

Recursively assemble a hierarchical plot layout from a `PlotNode`.

Each node may represent a row, column, or custom layout and contain children (subplots or nested nodes).

# Arguments
- `node`: The root of a plot subtree.
- `depth`: Current depth (used to control spacing/layout).
"""
function __plot_tree(node::PlotNode, depth::Int=0; kwargs...)
    #
    subplots = ()
    #
    for c in node.children
        if !(c isa EmptyPlot)
            pc = __plot_tree(c, depth + 1)
            subplots = (subplots..., pc)
        end
    end
    #
    kwargs_plot = depth == 0 ? kwargs : ()
    ps = @match node.layout begin
        :row => plot(subplots...; layout=(1, size(subplots, 1)), kwargs_plot...)
        :column =>
            plot(subplots...; layout=(size(subplots, 1), 1), leftmargin=3mm, kwargs_plot...)
        _ => plot(subplots...; layout=node.layout, kwargs_plot...)
    end

    return ps
end

# --------------------------------------------------------------------------------------------------
# private plots: initial plot
"""
$(TYPEDSIGNATURES)

Initialize the layout and create an empty plot canvas according to `layout` and `control` parameters.

# Keyword Arguments
- `layout`: Plot layout style (`:group` or `:split`).
- `control`: What to plot for controls (`:components`, `:norm`, `:all`).
- `state_style`, `control_style`, etc.: Plot styles for various signals.
"""
function __initial_plot(
    sol::CTModels.Solution,
    description::Symbol...;
    layout::Symbol,
    control::Symbol,
    model::Union{CTModels.Model,Nothing},
    state_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
    kwargs...,
)

    # set the default description if not given and then clean it
    description = description == () ? __description() : description
    description = clean(description)

    # check what to plot
    do_plot_state, do_plot_costate, do_plot_control, do_plot_path, do_plot_dual = do_plot(
        sol,
        description...;
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
    )

    # parameters
    n = CTModels.state_dimension(sol)
    m = CTModels.control_dimension(sol)

    if layout == :group
        plots = Vector{Plots.Plot}()
        @match control begin
            :components => begin
                do_plot_state && push!(plots, Plots.plot()) # state
                do_plot_costate && push!(plots, Plots.plot()) # costate
                do_plot_control && push!(plots, Plots.plot()) # control
                return Plots.plot(
                    plots...; layout=(1, length(plots)), bottommargin=5mm, kwargs...
                )
            end
            :norm => begin
                do_plot_state && push!(plots, Plots.plot()) # state
                do_plot_costate && push!(plots, Plots.plot()) # costate
                do_plot_control && push!(plots, Plots.plot()) # control norm
                return Plots.plot(
                    plots...; layout=(1, length(plots)), bottommargin=5mm, kwargs...
                )
            end
            :all => begin
                do_plot_state && push!(plots, Plots.plot()) # state
                do_plot_costate && push!(plots, Plots.plot()) # costate
                do_plot_control && push!(plots, Plots.plot()) # control
                do_plot_control && push!(plots, Plots.plot()) # control norm
                if length(plots) == 4
                    return Plots.plot(plots...; layout=(2, 2), kwargs...)
                else
                    return Plots.plot(
                        plots...; layout=(1, length(plots)), bottommargin=5mm, kwargs...
                    )
                end
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
            do_plot_state && push!(state_plots, PlotLeaf())
            do_plot_costate && push!(costate_plots, PlotLeaf())
        end

        # create the control plots
        if do_plot_control
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
        end

        # assemble the state and costate plots
        node_x = isempty(state_plots) ? EmptyPlot() : PlotNode(:column, state_plots)
        node_p = isempty(costate_plots) ? EmptyPlot() : PlotNode(:column, costate_plots)
        node_xp = if node_x isa EmptyPlot && node_p isa EmptyPlot
            EmptyPlot()
        else
            PlotNode(:row, [node_x, node_p])
        end

        # assemble the control plots
        node_u = isempty(control_plots) ? EmptyPlot() : PlotNode(:column, control_plots)

        # create the root node
        root = EmptyPlot()
        nblines = 0
        if (!(node_xp isa EmptyPlot) && !(node_u isa EmptyPlot))
            nblines = n + l
            h = round(n / nblines; digits=2)
            lay = Matrix{Any}(undef, 2, 1)
            lay[1, 1] = (label = :a, width = :auto, height = h)
            lay[2, 1] = (label = :b, blank = false)
            root = PlotNode(lay, [node_xp, node_u])
        elseif !(node_xp isa EmptyPlot)
            root = node_xp
            nblines = n
        elseif !(node_u isa EmptyPlot)
            root = node_u
            nblines = l
        end

        # Add the path constraints and their dual variables (in two columns as for state and costate) plots 
        # if layout is :split, model is not nothing and there are path constraints
        nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
        if nc > 0
            # create the path constraints and dual variables plots
            path_constraints_plots = Vector{PlotLeaf}()
            path_constraints_dual_plots = Vector{PlotLeaf}()
            for i in 1:nc
                do_plot_path && push!(path_constraints_plots, PlotLeaf())
                do_plot_dual && push!(path_constraints_dual_plots, PlotLeaf())
            end

            # assemble the path constraints and dual variables plots
            node_co = if isempty(path_constraints_plots)
                EmptyPlot()
            else
                PlotNode(:column, path_constraints_plots)
            end
            node_cp = if isempty(path_constraints_dual_plots)
                EmptyPlot()
            else
                PlotNode(:column, path_constraints_dual_plots)
            end
            node_cocp = if node_co isa EmptyPlot && node_cp isa EmptyPlot
                EmptyPlot()
            else
                PlotNode(:row, [node_co, node_cp])
            end

            # update the root node
            if !(node_cocp isa EmptyPlot)
                nblines += nc
                h = round(nc / nblines; digits=2)
                lay = Matrix{Any}(undef, 2, 1)
                lay[1, 1] = (label = :a, blank = false)
                lay[2, 1] = (label = :b, width = :auto, height = h)
                root = PlotNode(lay, [root, node_cocp])
            end
        end

        # plot
        return if nblines==1
            __plot_tree(root; bottommargin=5mm, kwargs...)
        else
            __plot_tree(root; kwargs...)
        end

    else
        throw(CTBase.IncorrectArgument("No such choice for layout. Use :group or :split"))
    end
end

"""
$(TYPEDSIGNATURES)

Filter keyword arguments to retain only those relevant for plotting series.

Returns a list of key-value pairs recognized by `Plots`.
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

Plot an optimal control `Solution` on a given plot `p`.

This updates an existing plot object with the trajectory of states, controls, costates,
constraints, and duals based on the provided `layout` and `description`.

# Keyword Arguments
Includes options such as:
- `layout`, `control`, `time`
- `state_style`, `control_style`, `costate_style`, etc.
"""
function __plot!(
    p::Plots.Plot,
    sol::CTModels.Solution,
    description::Symbol...;
    model::Union{CTModels.Model,Nothing},
    time::Symbol,
    control::Symbol,
    layout::Symbol,
    time_style::Union{NamedTuple,Symbol},
    state_style::Union{NamedTuple,Symbol},
    state_bounds_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    control_bounds_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    path_bounds_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
    color,
    kwargs...,
)

    # set the default description if not given and then clean it
    description = description == () ? __description() : description
    description = clean(description)

    # check what to plot
    do_plot_state, do_plot_costate, do_plot_control, do_plot_path, do_plot_dual = do_plot(
        sol,
        description...;
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
    )

    # check what to decorate
    do_decorate_time, do_decorate_state_bounds, do_decorate_control_bounds, do_decorate_path_bounds = do_decorate(;
        model=model,
        time_style=time_style,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        path_bounds_style=path_bounds_style,
    )

    #
    n = CTModels.state_dimension(sol)
    m = CTModels.control_dimension(sol)
    x_labels = CTModels.state_components(sol)
    u_labels = CTModels.control_components(sol)
    u_label = CTModels.control_name(sol)
    t_label = CTModels.time_name(sol)

    #
    title_font = font(10, Plots.default(:fontfamily))
    label_font_size = 10

    # split series attributes 
    series_attr = __keep_series_attributes(; kwargs...)

    #
    if layout == :group

        # the current index of the plot
        icur = 1

        # state
        if do_plot_state
            __plot_time!(
                p[icur],
                sol,
                model,
                n,
                :state,
                time;
                t_label=t_label,
                labels=x_labels,
                title="state",
                titlefont=title_font,
                lims=:auto,
                color=nothing,
                series_attr...,
                state_style...,
            )
            icur += 1
        end

        # costate
        if do_plot_costate
            __plot_time!(
                p[icur],
                sol,
                model,
                n,
                :costate,
                time;
                t_label=t_label,
                labels="p" .* x_labels,
                title="costate",
                titlefont=title_font,
                lims=:auto,
                color=nothing,
                series_attr...,
                costate_style...,
            )
            icur += 1
        end

        # control
        if do_plot_control
            @match control begin
                :components => begin
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        m,
                        :control,
                        time;
                        t_label=t_label,
                        labels=u_labels,
                        title="control",
                        titlefont=title_font,
                        lims=:auto,
                        color=nothing,
                        series_attr...,
                        control_style...,
                    )
                    icur += 1
                end
                :norm => begin
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        :control_norm,
                        -1,
                        time;
                        t_label=t_label,
                        label="‖" * u_label * "‖",
                        title="control norm",
                        titlefont=title_font,
                        lims=:auto,
                        color=nothing,
                        series_attr...,
                        control_style...,
                    )
                    icur += 1
                end
                :all => begin
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        m,
                        :control,
                        time;
                        t_label=t_label,
                        labels=u_labels,
                        title="control",
                        titlefont=title_font,
                        lims=:auto,
                        color=nothing,
                        series_attr...,
                        control_style...,
                    )
                    icur += 1
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        :control_norm,
                        -1,
                        time;
                        t_label=t_label,
                        label="‖" * u_label * "‖",
                        title="control norm",
                        titlefont=title_font,
                        lims=:auto,
                        color=nothing,
                        series_attr...,
                        control_style...,
                    )
                    icur += 1
                end
                _ => throw(
                    CTBase.IncorrectArgument(
                        "No such choice for control. Use :components, :norm or :all"
                    ),
                )
            end
        end

    elseif layout == :split

        # the current index of the plot
        icur = 1

        # state
        if do_plot_state

            # index for first state plot
            is = icur

            # state trajectory
            for i in 1:n
                title = i==1 ? "state" : ""
                __plot_time!(
                    p[icur],
                    sol,
                    model,
                    :state,
                    i,
                    time;
                    t_label=i==n ? t_label : "",
                    xguidefontsize=label_font_size,
                    y_label=x_labels[i],
                    yguidefontsize=label_font_size,
                    label="",
                    title=title,
                    titlefont=title_font,
                    color=color,
                    series_attr...,
                    state_style...,
                )
                icur += 1
            end

            # state constraints if model is not nothing
            if do_decorate_state_bounds
                cs = CTModels.state_constraints_box(model)
                for i in 1:length(cs[1])
                    hline!(
                        p[is + cs[2][i] - 1],
                        [cs[1][i]];
                        color=15,
                        linewidth=1,
                        z_order=:back,
                        series_attr...,
                        state_bounds_style...,
                        label=:none,
                    ) # lower bound
                    hline!(
                        p[is + cs[2][i] - 1],
                        [cs[3][i]];
                        color=15,
                        linewidth=1,
                        z_order=:back,
                        series_attr...,
                        state_bounds_style...,
                        label=:none,
                    ) # upper bound
                end
            end
        end # end state

        # costate
        if do_plot_costate
            for i in 1:n
                title = i==1 ? "costate" : ""
                y_label = do_plot_state ? "" : "p" * x_labels[i]
                __plot_time!(
                    p[icur],
                    sol,
                    model,
                    :costate,
                    i,
                    time;
                    t_label=i==n ? t_label : "",
                    xguidefontsize=label_font_size,
                    y_label=y_label,
                    yguidefontsize=label_font_size,
                    label="",
                    title=title,
                    titlefont=title_font,
                    color=color,
                    series_attr...,
                    costate_style...,
                )
                icur += 1
            end
        end # end costate

        # control
        if do_plot_control

            # index for first control plot
            iu = icur

            # control trajectory
            l = m
            @match control begin
                :components => begin
                    for i in 1:m
                        title = i==1 ? "control" : ""
                        __plot_time!(
                            p[icur],
                            sol,
                            model,
                            :control,
                            i,
                            time;
                            t_label=i==m ? t_label : "",
                            xguidefontsize=label_font_size,
                            y_label=u_labels[i],
                            yguidefontsize=label_font_size,
                            label="",
                            title=title,
                            titlefont=title_font,
                            color=color,
                            series_attr...,
                            control_style...,
                        )
                        icur += 1
                    end
                end
                :norm => begin
                    l = 1
                    title = "control"
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        :control_norm,
                        -1,
                        time;
                        t_label=t_label,
                        xguidefontsize=label_font_size,
                        y_label="‖" * u_label * "‖",
                        yguidefontsize=label_font_size,
                        label="",
                        title=title,
                        titlefont=title_font,
                        color=color,
                        series_attr...,
                        control_style...,
                    )
                    icur += 1
                end
                :all => begin
                    l = m + 1
                    for i in 1:m
                        title = i==1 ? "control" : ""
                        __plot_time!(
                            p[icur],
                            sol,
                            model,
                            :control,
                            i,
                            time;
                            t_label="",
                            y_label=u_labels[i],
                            yguidefontsize=label_font_size,
                            label="",
                            title=title,
                            titlefont=title_font,
                            color=color,
                            series_attr...,
                            control_style...,
                        )
                        icur += 1
                    end
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        :control_norm,
                        -1,
                        time;
                        t_label=t_label,
                        xguidefontsize=label_font_size,
                        y_label="‖" * u_label * "‖",
                        yguidefontsize=label_font_size,
                        label="",
                        color=color,
                        series_attr...,
                        control_style...,
                    )
                    icur += 1
                end
                _ => throw(
                    CTBase.IncorrectArgument(
                        "No such choice for control. Use :components, :norm or :all"
                    ),
                )
            end

            # control constraints if model is not nothing
            if do_decorate_control_bounds && (control != :norm)
                cu = CTModels.control_constraints_box(model)
                for i in 1:length(cu[1])
                    hline!(
                        p[iu + cu[2][i] - 1],
                        [cu[1][i]];
                        color=15,
                        linewidth=1,
                        z_order=:back,
                        series_attr...,
                        control_bounds_style...,
                        label=:none,
                    ) # lower bound
                    hline!(
                        p[iu + cu[2][i] - 1],
                        [cu[3][i]];
                        color=15,
                        linewidth=1,
                        z_order=:back,
                        series_attr...,
                        control_bounds_style...,
                        label=:none,
                    ) # upper bound
                end
            end
        end # end control

        # path constraints and the dual variables if model is not nothing and there are path constraints
        nc = if model === nothing
            0
        else
            CTModels.dim_path_constraints_nl(model)
        end
        if nc > 0

            # retrieve the constraints
            cp = CTModels.path_constraints_nl(model)

            # path constraints
            if do_plot_path

                # index for first path constraints plot
                ic = icur

                # path constraints trajectory
                for i in 1:nc
                    title = i==1 ? "path constraints" : ""
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        :path_constraint,
                        i,
                        time;
                        t_label=i==nc ? t_label : "",
                        xguidefontsize=label_font_size,
                        y_label=string(cp[4][i]),
                        yguidefontsize=label_font_size,
                        label="",
                        title=title,
                        titlefont=title_font,
                        color=color,
                        series_attr...,
                        path_style...,
                    )
                    icur += 1
                end

                # path constraints bounds
                if do_decorate_path_bounds
                    for i in 1:nc
                        hline!(
                            p[ic + i - 1],
                            [cp[1][i]];
                            color=15,
                            linewidth=1,
                            z_order=:back,
                            series_attr...,
                            path_bounds_style...,
                            label=:none,
                        ) # lower bound
                        hline!(
                            p[ic + i - 1],
                            [cp[3][i]];
                            color=15,
                            linewidth=1,
                            z_order=:back,
                            series_attr...,
                            path_bounds_style...,
                            label=:none,
                        ) # upper bound
                    end
                end
            end # end path constraints

            # dual variables
            if do_plot_dual
                for i in 1:nc
                    title = i==1 ? "dual" : ""
                    y_label = do_plot_path ? "" : "dual " * string(cp[4][i])
                    __plot_time!(
                        p[icur],
                        sol,
                        model,
                        :dual_path_constraint,
                        i,
                        time;
                        t_label=i==nc ? t_label : "",
                        xguidefontsize=label_font_size,
                        y_label=y_label,
                        yguidefontsize=label_font_size,
                        label="",
                        title=title,
                        titlefont=title_font,
                        color=color,
                        series_attr...,
                        dual_style...,
                    )
                    icur += 1
                end
            end
        end
    else
        throw(CTBase.IncorrectArgument("No such choice for layout. Use :group or :split"))
    end # end layout

    # plot vertical lines at the initial and final times if model is not nothing
    if do_decorate_time
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
        for plt in p.subplots
            vline!(
                plt,
                [t0, tf];
                color=:black,
                linestyle=:dash,
                linewidth=1,
                z_order=:back,
                series_attr...,
                time_style...,
                label=:none,
            )
        end
    end

    return p
end

"""
$(TYPEDSIGNATURES)

Construct and return a new plot for the provided `Solution`.

This is a wrapper that calls `__initial_plot` and then fills it using `__plot!`.

Use this to obtain a standalone plot.
"""
function __plot(
    sol::CTModels.Solution,
    description::Symbol...;
    model::Union{CTModels.Model,Nothing},
    time::Symbol,
    control::Symbol,
    layout::Symbol,
    time_style::Union{NamedTuple,Symbol},
    state_style::Union{NamedTuple,Symbol},
    state_bounds_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    control_bounds_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    path_bounds_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
    size::Tuple=__size_plot(
        sol,
        model,
        control,
        layout,
        description...;
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
    ),
    color,
    kwargs...,
)
    p = __initial_plot(
        sol,
        description...;
        layout=layout,
        control=control,
        model=model,
        size=size,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
        kwargs...,
    )

    return __plot!(
        p,
        sol,
        description...;
        layout=layout,
        control=control,
        time=time,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=model,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        time_style=time_style,
        path_style=path_style,
        path_bounds_style=path_bounds_style,
        dual_style=dual_style,
        color=color,
        kwargs...,
    )
end

# --------------------------------------------------------------------------------------------------
# public plots
"""
$(TYPEDSIGNATURES)

Modify Plot `p` with the optimal control solution `sol`.

See [`plot`](@ref plot(::CTModels.Solution)) for full behavior and keyword arguments.
"""
function Plots.plot!(
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
    model = CTModels.model(sol)

    # check if the plot is empty
    if isempty(p.series_list)
        attr = NamedTuple((Symbol(key), value) for (key, value) in p.attr if key != :layout)

        pnew = __initial_plot(
            sol,
            description...;
            layout=layout,
            control=control,
            model=model,
            size=__size_plot(
                sol,
                model,
                control,
                layout,
                description...;
                state_style=state_style,
                control_style=control_style,
                costate_style=costate_style,
                path_style=path_style,
                dual_style=dual_style,
            ),
            state_style=state_style,
            control_style=control_style,
            costate_style=costate_style,
            path_style=path_style,
            dual_style=dual_style,
            attr...,
            kwargs...,
        )

        # replace p by pnew, must have a side effect
        for k in fieldnames(typeof(p))
            setfield!(p, k, getfield(pnew, k))
        end
    end

    # plot the solution with infos from the model
    return __plot!(
        p,
        sol,
        description...;
        layout=layout,
        control=control,
        time=time,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=model,
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        time_style=time_style,
        path_style=path_style,
        path_bounds_style=path_bounds_style,
        dual_style=dual_style,
        color=color,
        kwargs...,
    )
end

"""
$(TYPEDSIGNATURES)

Modify Plot `current()` with the optimal control solution `sol`.

See [`plot`](@ref plot(::CTModels.Solution)) for full behavior and keyword arguments.
"""
function Plots.plot!(
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
    return Plots.plot!(
        Plots.current(),
        sol,
        description...;
        layout,
        control,
        time,
        state_style,
        state_bounds_style,
        control_style,
        control_bounds_style,
        costate_style,
        time_style,
        path_style,
        path_bounds_style,
        dual_style,
        color=color,
        kwargs...,
    )
end

"""
$(TYPEDSIGNATURES)

Plot the components of an optimal control solution.

This is the main user-facing function to visualise the solution of an optimal control problem
solved with the control-toolbox ecosystem.

It generates a set of subplots showing the evolution of the state, control, costate,
path constraints, and dual variables over time, depending on the problem and the user’s choices.

# Arguments

- `sol::CTModels.Solution`: The optimal control solution to visualise.
- `description::Symbol...`: A variable number of symbols indicating which components to include in the plot. Common values include:
  - `:state` – plot the state.
  - `:costate` – plot the costate (adjoint).
  - `:control` – plot the control.
  - `:path` – plot the path constraints.
  - `:dual` – plot the dual variables (or Lagrange multipliers) associated with path constraints.

If no symbols are provided, a default set is used based on the problem and styles.

# Keyword Arguments (Optional)

- `layout::Symbol = :group`: Specifies how to arrange plots.
  - `:group`: Fewer plots, grouping similar variables together (e.g., all states in one subplot).
  - `:split`: One plot per variable component, stacked in a layout.

- `control::Symbol = :components`: Defines how to represent control inputs.
  - `:components`: One curve per control component.
  - `:norm`: Single curve showing the Euclidean norm ‖u(t)‖.
  - `:all`: Plot both components and norm.

- `time::Symbol = :default`: Time normalisation for plots.
  - `:default`: Real time scale.
  - `:normalize` or `:normalise`: Normalised to the interval [0, 1].

- `color`: set the color of the all the graphs.

## Style Options (Optional)

All style-related keyword arguments can be either a `NamedTuple` of plotting attributes or the `Symbol` `:none` referring to not plot the associated element. These allow you to customise color, line style, markers, etc.

- `time_style`: Style for vertical lines at initial and final times.
- `state_style`: Style for state components.
- `costate_style`: Style for costate components.
- `control_style`: Style for control components.
- `path_style`: Style for path constraint values.
- `dual_style`: Style for dual variables.

## Bounds Decorations (Optional)

Use these options to customise bounds on the plots if applicable and defined in the model. Set to `:none` to hide.

- `state_bounds_style`: Style for state bounds.
- `control_bounds_style`: Style for control bounds.
- `path_bounds_style`: Style for path constraint bounds.

# Returns

- A `Plots.Plot` object, which can be displayed, saved, or further customised.

# Example

```julia-repl
# basic plot
julia> plot(sol)

# plot only the state and control
julia> plot(sol, :state, :control)

# customise layout and styles, no costate
julia> plot(sol;
       layout = :group,
       control = :all,
       state_style = (color=:blue, linestyle=:solid),
       control_style = (color=:red, linestyle=:dash),
       costate_style = :none)       
```
"""
function Plots.plot(
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
    size::Tuple=__size_plot(
        sol,
        CTModels.model(sol),
        control,
        layout,
        description...;
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        path_style=path_style,
        dual_style=dual_style,
    ),
    color=nothing,
    kwargs...,
)
    return __plot(
        sol,
        description...;
        layout=layout,
        control=control,
        time=time,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        model=CTModels.model(sol),
        state_bounds_style=state_bounds_style,
        control_bounds_style=control_bounds_style,
        time_style=time_style,
        path_style=path_style,
        path_bounds_style=path_bounds_style,
        dual_style=dual_style,
        size=size,
        color=color,
        kwargs...,
    )
end

# --------------------------------------------------------------------------------------------------
# plot recipe
"""
$(TYPEDSIGNATURES)

A Plots.jl recipe for plotting `Solution` data.

Returns the `(x, y)` values based on symbolic references like `:state`, `:control`, `:time`, etc.

# Arguments
- `xx`: Symbol or `(Symbol, Int)` indicating the x-axis.
- `yy`: Symbol or `(Symbol, Int)` indicating the y-axis.
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
    # label := recipe_label(sol, xx, yy)
    # color := 1           # default color
    # linestyle := :solid  # default linestyle
    # linewidth := 2       # default linewidth
    # z_order := :front    # default z_order

    return x, y
end

"""
$(TYPEDSIGNATURES)

Extract data for plotting from a `Solution` and optional `Model`.

# Arguments
- `xx`: Symbol or `(Symbol, Int)` indicating the quantity and component.
- `time`: Whether to normalize the time grid.

Supported values for `xx`:
- `:time`, `:state`, `:control`, `:costate`, `:control_norm`
- `:path_constraint`, `:dual_path_constraint`
"""
function __get_data_plot(
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    xx::Union{Symbol,Tuple{Symbol,Int}};
    time::Symbol=:default,
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
