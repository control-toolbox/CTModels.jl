"""
$(TYPEDEF)

Abstract node for plot.
"""
abstract type AbstractPlotTreeElement end

"""
$(TYPEDEF)

A leaf of a plot tree.
"""
struct PlotLeaf <: AbstractPlotTreeElement
    value::Tuple{Symbol,Int}
    PlotLeaf(value::Tuple{Symbol,Int}) = new(value)
end

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
# internal plots
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
        p, sol, :time, (s, i), time; ylims=:auto, xlabel=t_label, label=label, kwargs...
    ) # use simple plot

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
    s::Symbol,
    i::Int,
    time::Symbol;
    t_label::String,
    label::String,
    kwargs...,
)
    return __plot_time!(
        Plots.plot(), sol, s, i, time; t_label=t_label, label=label, kwargs...
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
    d::CTModels.Dimension,
    s::Symbol,
    time::Symbol;
    t_label::String,
    labels::Vector{String},
    title::String,
    kwargs...,
)

    #
    Plots.plot!(p; xlabel="time", title=title, kwargs...)

    #
    for i in range(1, d)
        __plot_time!(p, sol, s, i, time; t_label=t_label, label=labels[i], kwargs...)
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
        d,
        s,
        time;
        t_label=t_label,
        labels=labels,
        title=title,
        kwargs...,
    )
end

"""
$(TYPEDSIGNATURES)

Generate a{r*h} where `r` is a real number and `h` is the height of the plot.
"""
function __width(r::Real)::Expr
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

"""
$(TYPEDSIGNATURES)

Initial plot.
"""
function __initial_plot(
    sol::CTModels.Solution;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
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

        for i in 1:n
            push!(state_plots, PlotLeaf((:state, i)))
            push!(costate_plots, PlotLeaf((:costate, i)))
        end
        l = m
        @match control begin
            :components => begin
                for i in 1:m
                    push!(control_plots, PlotLeaf((:control, i)))
                end
            end
            :norm => begin
                push!(control_plots, PlotLeaf((:control_norm, -1)))
                l = 1
            end
            :all => begin
                for i in 1:m
                    push!(control_plots, PlotLeaf((:control, i)))
                end
                push!(control_plots, PlotLeaf((:control_norm, -1)))
                l = m + 1
            end
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end

        #
        node_x = PlotNode(:column, state_plots)
        node_p = PlotNode(:column, costate_plots)
        node_u = PlotNode(:column, control_plots)
        node_xp = PlotNode(:row, [node_x, node_p])

        #
        r = round(n / (n + l); digits=2)
        a = __width(r)
        @eval lay = @layout [
            $a
            b
        ]
        root = PlotNode(lay, [node_xp, node_u])

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
    solution_label::String="",
    state_style=(),
    control_style=(),
    costate_style=(),
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
        for i in 1:n
            __plot_time!(
                p[i],
                sol,
                :state,
                i,
                time;
                t_label=t_label,
                label=x_labels[i] * solution_label,
                series_attr...,
                state_style...,
            )
            __plot_time!(
                p[i + n],
                sol,
                :costate,
                i,
                time;
                t_label=t_label,
                label="p" * x_labels[i] * solution_label,
                series_attr...,
                costate_style...,
            )
        end
        @match control begin
            :components => begin
                for i in 1:m
                    __plot_time!(
                        p[i + 2 * n],
                        sol,
                        :control,
                        i,
                        time;
                        t_label=t_label,
                        label=u_labels[i] * solution_label,
                        series_attr...,
                        control_style...,
                    )
                end
            end
            :norm => begin
                __plot_time!(
                    p[2 * n + 1],
                    sol,
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
                for i in 1:m
                    __plot_time!(
                        p[i + 2 * n],
                        sol,
                        :control,
                        i,
                        time;
                        t_label=t_label,
                        label=u_labels[i] * solution_label,
                        series_attr...,
                        control_style...,
                    )
                end
                __plot_time!(
                    p[2 * n + m + 1],
                    sol,
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

    else
        throw(CTBase.IncorrectArgument("No such choice for layout. Use :group or :split"))
    end

    return p
end

"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol` using the layout `layout`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function Plots.plot(
    sol::CTModels.Solution;
    layout::Symbol=__plot_layout(),
    control::Symbol=__control_layout(),
    time::Symbol=__time_normalization(),
    size=__size_plot(sol, control),
    solution_label::String="",
    state_style=(),
    control_style=(),
    costate_style=(),
    kwargs...,
)
    #
    p = __initial_plot(sol; layout=layout, control=control, size=size, kwargs...)
    #
    return Plots.plot!(
        p,
        sol;
        layout=layout,
        control=control,
        time=time,
        solution_label=solution_label,
        state_style=state_style,
        control_style=control_style,
        costate_style=costate_style,
        kwargs...,
    )
end

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
    xx::Union{Symbol,Tuple{Symbol,Int}},
    yy::Union{Symbol,Tuple{Symbol,Int}},
    time::Symbol=:default,
)

    #
    x = __get_data_plot(sol, xx; time=time)
    y = __get_data_plot(sol, yy; time=time)

    #
    label = recipe_label(sol, xx, yy)

    return x, y
end

"""
$(TYPEDSIGNATURES)

Return the label for the plot of the optimal control solution `sol`
corresponding to the argument `xx` and the argument `yy`.

**Notes.**

- The argument `xx` can be `:time`, `:state`, `:control` or `:costate`.
- The argument `yy` can be `:state`, `:control` or `:costate`.
"""
function recipe_label(
    sol::CTModels.Solution,
    xx::Union{Symbol,Tuple{Symbol,Int}},
    yy::Union{Symbol,Tuple{Symbol,Int}},
)

    #
    label = false
    #
    if xx isa Symbol && xx == :time
        s, i = @match yy begin
            ::Symbol => (yy, 1)
            _ => yy
        end

        label = @match s begin
            :state => CTModels.state_components(sol)[i]
            :control => CTModels.control_components(sol)[i]
            :costate => "p" * CTModels.state_components(sol)[i]
            :control_norm => "‖" * CTModels.control_name(sol) * "‖"
            _ => error("Internal error, no such choice for label")
        end
    end
    #
    return label
end

"""
$(TYPEDSIGNATURES)

Get the data for plotting.
"""
function __get_data_plot(
    sol::CTModels.Solution, xx::Union{Symbol,Tuple{Symbol,Int}}; time::Symbol=:default
)

    # if the time grid is empty then throw an error
    if CTModels.is_empty_time_grid(sol) == true
        throw(CTBase.IncorrectArgument("The time grid is empty"))
    end

    T = CTModels.time_grid(sol)
    X = CTModels.state(sol).(T)
    U = CTModels.control(sol).(T)
    P = CTModels.costate(sol).(T)

    vv, ii = @match xx begin
        ::Symbol => (xx, 1)
        _ => xx
    end

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
        :state => [X[i][ii] for i in 1:m]
        :control => [U[i][ii] for i in 1:m]
        :costate => [P[i][ii] for i in 1:m]
        :control_norm => [norm(U[i]) for i in 1:m]
        _ => error("Internal error, no such choice for xx")
    end
end
