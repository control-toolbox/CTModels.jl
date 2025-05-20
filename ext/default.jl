"""
$(TYPEDSIGNATURES)

Used to set the default value of the layout of the plots.
Either :split or :group.
"""
__plot_layout() = :split

"""
$(TYPEDSIGNATURES)

Used to set the default value of the layout of the control plots.
Either :components or :norm or :all.
"""
__control_layout() = :components

"""
$(TYPEDSIGNATURES)

Used to set the default value of the time grid normalization.
Either :default or :normalize or :normalise.
"""
__time_normalization() = :default

"""
$(TYPEDSIGNATURES)

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

Used to set the default value of the plot size.
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

Default style for the plot. Must be an empty tuple.
"""
__plot_style() = NamedTuple()

"""
$(TYPEDSIGNATURES)

Default suffix label for the plot. Must be an empty string.
"""
__plot_label_suffix() = ""
