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
function __size_plot(sol::CTModels.Solution, control::Symbol)
    n = CTModels.state_dimension(sol)
    m = @match control begin
        :components => CTModels.control_dimension(sol)
        :norm => 1
        :all => CTModels.control_dimension(sol) + 1
        _ => throw(
            CTBase.IncorrectArgument("No such choice for control. Use :components, :norm or :all"),
        )
    end
    return (600, 140 * (n + m))
end
