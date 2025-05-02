"""
$(TYPEDSIGNATURES)

"""
function clean(description)
    # remove the nouns in plural form
    description = replace(description, 
        :states => :state, 
        :costates => :costate, 
        :controls => :control, 
        :constraints => :path,
        :constraint => :path, 
        :cons => :path,
        :duals => :dual)
    # remove the duplicates
    return tuple(Set(description)...)
end

"""
$(TYPEDSIGNATURES)

What to plot based on the description and the styles given.
The description is a cleaned tuple of symbols that can be:
    :state, :costate, :control, :path, :dual
"""
function do_plot(description::Symbol...; 
    state_style::Union{NamedTuple, Symbol},
    control_style::Union{NamedTuple, Symbol},
    costate_style::Union{NamedTuple, Symbol},
    path_style::Union{NamedTuple, Symbol},
    dual_style::Union{NamedTuple, Symbol})

    do_plot_state = :state ∈ description && state_style != :none
    do_plot_costate = :costate ∈ description && costate_style != :none
    do_plot_control = :control ∈ description && control_style != :none
    do_plot_path = :path ∈ description && path_style != :none
    do_plot_dual = :dual ∈ description && dual_style != :none

    return (
        do_plot_state,
        do_plot_costate,
        do_plot_control,
        do_plot_path,
        do_plot_dual,
    )

end

"""
$(TYPEDSIGNATURES)

"""
function do_decorate(;
    model::Union{CTModels.Model,Nothing},
    time_style::Union{NamedTuple, Symbol},
    state_bounds_style::Union{NamedTuple, Symbol},
    control_bounds_style::Union{NamedTuple, Symbol},
    path_bounds_style::Union{NamedTuple, Symbol},
    )

    do_decorate_time = time_style != :none && model !== nothing
    do_decorate_state_bounds = state_bounds_style != :none && model !== nothing
    do_decorate_control_bounds = control_bounds_style != :none && model !== nothing
    do_decorate_path_bounds = path_bounds_style != :none && model !== nothing
    return (
        do_decorate_time,
        do_decorate_state_bounds,
        do_decorate_control_bounds,
        do_decorate_path_bounds,
    )

end