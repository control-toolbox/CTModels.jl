# Shared high-level component accessor generics, declared and owned by Components.
# Models / Solutions / Init attach their own methods to these generics.

"""
Return the state model (on a [`CTModels.Models.Model`](@ref)) or the state trajectory
function (on a [`CTModels.Solutions.Solution`](@ref)).

See also: [`CTModels.Models.state_dimension`](@ref), [`CTModels.Models.state_components`](@ref).
"""
function state end

"""
Return the control model (on a [`CTModels.Models.Model`](@ref)) or the control trajectory
function (on a [`CTModels.Solutions.Solution`](@ref)).

See also: [`CTModels.Models.control_dimension`](@ref), [`CTModels.Models.control_components`](@ref).
"""
function control end

"""
Return the variable model (on a [`CTModels.Models.Model`](@ref)) or the variable value
(on a [`CTModels.Solutions.Solution`](@ref)).

See also: [`CTModels.Models.variable_dimension`](@ref), [`CTModels.Models.variable_components`](@ref).
"""
function variable end

"""
Return the objective model (on a [`CTModels.Models.Model`](@ref)) or the objective value
(on a [`CTModels.Solutions.Solution`](@ref)).
"""
function objective end

"""
Return the costate trajectory function from a [`CTModels.Solutions.Solution`](@ref).

See also: [`CTModels.Components.state`](@ref), [`CTModels.Solutions.dual`](@ref).
"""
function costate end

"""
Return the [`CTModels.Components.AbstractTimesModel`](@ref) from a [`CTModels.Models.Model`](@ref).

See also: [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
function times end

"""
Return the time grid for a component from a [`CTModels.Solutions.Solution`](@ref).

See also: [`CTModels.Solutions.build_solution`](@ref).
"""
function time_grid end
