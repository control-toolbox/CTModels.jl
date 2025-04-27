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

Used to set the default value of the plot size.
"""
function __size_plot(
    sol::CTModels.Solution,
    model::Union{CTModels.Model, Nothing},
    control::Symbol,
    layout::Symbol
)
    if layout === :group
        if control === :all
            return (600, 560)
        else
            return (600, 280)
        end
    else
        n = CTModels.state_dimension(sol)
        l = @match control begin
            :components => CTModels.control_dimension(sol)
            :norm => 1
            :all => CTModels.control_dimension(sol) + 1
            _ => throw(
                CTBase.IncorrectArgument(
                    "No such choice for control. Use :components, :norm or :all"
                ),
            )
        end
        nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
        return (600, 140 * (n + l + nc))
    end
end

"""
$(TYPEDSIGNATURES)

Default style for the plot. Must be an empty tuple.
"""
__plot_style() = ()

"""
$(TYPEDSIGNATURES)

Default suffix label for the plot. Must be an empty string.
"""
__plot_label_suffix() = ""
