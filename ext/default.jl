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
__description() = (:state, :states,
    :costate, :costates, 
    :control, :controls, 
    :constraint, :constraints, :cons,
    :dual, :duals)

"""
$(TYPEDSIGNATURES)

"""
function clean(description)
    # remove the nouns in plural form
    description = replace(description, 
        :states => :state, 
        :costates => :costate, 
        :controls => :control, 
        :constraints => :cons,
        :constraint => :cons, 
        :duals => :dual)
    # remove the duplicates
    return tuple(Set(description)...)
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
    description::Symbol...
)

    # set the default description if not given and then clean it
    description = description == () ? __description() : description
    description = clean(description)

    #
    if layout == :group
        nb_plots = 0
        nb_plots += :state ∈ description ? 1 : 0
        nb_plots += :costate ∈ description ? 1 : 0
        if :control in description
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
        nb_lines += (:state ∈ description || :costate ∈ description) ? n : 0
        nb_lines += :control ∈ description ? l : 0
        nb_lines += (:cons ∈ description || :dual ∈ description) ? nc : 0
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
