"""
$(TYPEDSIGNATURES)

Default layout for the full plot.

Returns `:split`, which arranges each component (e.g. state, control) in separate subplots.

Possible values:
- `:split`: One subplot per component (default).
- `:group`: Combine components into shared subplots.

Used as the default for `layout` in `plot(sol; layout=...)`.
"""
__plot_layout() = :split

"""
$(TYPEDSIGNATURES)

Default layout for control input visualization.

Returns `:components`, which plots each control component individually.

Possible values:
- `:components`: One plot per control component (default).
- `:norm`: Single plot showing the control norm ‖u(t)‖.
- `:all`: Show both components and norm.

Used as the default for `control` in `plot(sol; control=...)`.
"""
__control_layout() = :components

"""
$(TYPEDSIGNATURES)

Default time axis normalization.

Returns `:default`, which plots against real time.

Possible values:
- `:default`: Plot time in original units (default).
- `:normalize`: Normalize time to [0, 1].
- `:normalise`: Same as `:normalize`, British spelling.

Used as the default for `time` in `plot(sol; time=...)`.
"""
__time_normalization() = :default

"""
$(TYPEDSIGNATURES)

Return the default list of description symbols to be plotted if the user does not specify any.

Includes aliases for backward compatibility.

Returns a tuple of symbols, such as:
- `:state`, `:costate`, `:control`, `:path`, `:dual`, ...
"""
function __description()
    (
        :state,
        :states,
        :costate,
        :costates,
        :control,
        :controls,
        :constraint,
        :constraints,
        :cons,
        :path,
        :dual,
        :duals,
    )
end

"""
$(TYPEDSIGNATURES)

Compute a default size `(width, height)` for the plot figure.

This depends on the number of subplots, which is inferred from:
- The layout (`:group` or `:split`)
- The presence of state, control, costate, path constraint, or dual variable plots
- The number of state and control variables
- The control layout choice (`:components`, `:norm`, `:all`)

Used internally in the `plot` function to automatically size the output plot.

# Example
```julia-repl
julia> size = __size_plot(sol, model, :components, :split; ...)
```
"""
function __size_plot(
    sol::CTModels.Solution,
    model::Union{CTModels.Model,Nothing},
    control::Symbol,
    layout::Symbol,
    description::Symbol...;
    state_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
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

    #
    if layout == :group
        nb_plots = 0
        nb_plots += do_plot_state ? 1 : 0
        nb_plots += do_plot_costate ? 1 : 0
        if do_plot_control
            if control == :components || control == :norm
                nb_plots += 1
            elseif control === :all
                nb_plots += 2
            end
        end
        if control == :all && nb_plots == 4
            return (600, 420)
        else
            return (600, 280)
        end
    else
        n = CTModels.state_dimension(sol)
        m = CTModels.control_dimension(sol)
        l = @match control begin
            :components => m
            :norm => 1
            :all => m + 1
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end
        nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
        nb_lines = 0
        nb_lines += (do_plot_state || do_plot_costate) ? n : 0
        nb_lines += do_plot_control ? l : 0
        nb_lines += (do_plot_path || do_plot_dual) ? nc : 0
        if nb_lines==1
            return (600, 280)
        elseif nb_lines==2
            return (600, 420)
        else
            return (600, 140 * nb_lines)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Default plot style.

Returns an empty `NamedTuple()`, which means no style override is applied.

Used when no user-defined style is passed for plotting states, controls, etc.
"""
__plot_style() = NamedTuple()

"""
$(TYPEDSIGNATURES)

Default suffix used for the solution label in plots.

Returns an empty string `""`.

This label can be used to distinguish multiple solutions in comparative plots.
"""
__plot_label_suffix() = ""
