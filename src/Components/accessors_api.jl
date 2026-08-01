# Shared high-level component accessor generics, declared and owned by Components.
# Models / Solutions / Init attach their own methods to these generics.

"""
Return the state model (on a [`CTModels.Models.Model`](@extref)) or the state trajectory
function (on a [`CTModels.Solutions.Solution`](@extref)).

See also: [`CTModels.Models.state_dimension`](@extref), [`CTModels.Models.state_components`](@extref).
"""
function state end

"""
Return the control model (on a [`CTModels.Models.Model`](@extref)) or the control trajectory
function (on a [`CTModels.Solutions.Solution`](@extref)).

See also: [`CTModels.Models.control_dimension`](@extref), [`CTModels.Models.control_components`](@extref).
"""
function control end

"""
Return the variable model (on a [`CTModels.Models.Model`](@extref)) or the variable value
(on a [`CTModels.Solutions.Solution`](@extref)).

See also: [`CTModels.Models.variable_dimension`](@extref), [`CTModels.Models.variable_components`](@extref).
"""
function variable end

"""
Return the objective model (on a [`CTModels.Models.Model`](@extref)) or the objective value
(on a [`CTModels.Solutions.Solution`](@extref)).
"""
function objective end

"""
Return the costate trajectory function from a [`CTModels.Solutions.Solution`](@extref).

See also: [`CTModels.Components.state`](@extref), [`CTModels.Solutions.dual`](@extref).
"""
function costate end

"""
Return the [`CTModels.Components.AbstractTimesModel`](@extref) from a [`CTModels.Models.Model`](@extref).

See also: [`CTModels.Components.initial_time`](@extref), [`CTModels.Components.final_time`](@extref).
"""
function times end

"""
Return the time grid for a component from a [`CTModels.Solutions.Solution`](@extref).

See also: [`CTModels.Solutions.build_solution`](@extref).
"""
function time_grid end
