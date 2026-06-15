# ------------------------------------------------------------------------------ #
# AbstractModel, struct Model, and all Model accessor methods
# ------------------------------------------------------------------------------ #

"""
$(TYPEDEF)

Abstract base type for optimal control problem models.

Subtypes represent either a fully built immutable model ([`Model`](@ref)) or a
mutable model under construction (`PreModel`).
"""
abstract type AbstractModel end

"""
$(TYPEDEF)

Immutable optimal control problem model containing all problem components.

A `Model` is created from a `PreModel` once all required fields have been
set. It is parameterised by the time dependence type (`Autonomous` or `NonAutonomous`)
and the types of all its components.

# Fields

- `times::TimesModelType`: Initial and final time specification.
- `state::StateModelType`: State variable structure (name, components).
- `control::ControlModelType`: Control variable structure (name, components).
- `variable::VariableModelType`: Optimisation variable structure (may be empty).
- `dynamics::DynamicsModelType`: System dynamics function `(t, x, u, v) -> ẋ`.
- `objective::ObjectiveModelType`: Cost functional (Mayer, Lagrange, or Bolza).
- `constraints::ConstraintsModelType`: All problem constraints.
- `definition::DefinitionType`: Original symbolic definition of the problem.
- `build_examodel::BuildExaModelType`: Optional ExaModels builder function.
"""
struct Model{
    TD<:TimeDependence,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    DynamicsModelType<:Function,
    ObjectiveModelType<:AbstractObjectiveModel,
    ConstraintsModelType<:AbstractConstraintsModel,
    DefinitionType<:AbstractDefinition,
    BuildExaModelType<:Union{Function,Nothing},
} <: AbstractModel
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    dynamics::DynamicsModelType
    objective::ObjectiveModelType
    constraints::ConstraintsModelType
    definition::DefinitionType
    build_examodel::BuildExaModelType

    function Model{TD}(  # TD must be specified explicitly
        times::AbstractTimesModel,
        state::AbstractStateModel,
        control::AbstractControlModel,
        variable::AbstractVariableModel,
        dynamics::Function,
        objective::AbstractObjectiveModel,
        constraints::AbstractConstraintsModel,
        definition::AbstractDefinition,
        build_examodel::Union{Function,Nothing},
    ) where {TD<:TimeDependence}
        return new{
            TD,
            typeof(times),
            typeof(state),
            typeof(control),
            typeof(variable),
            typeof(dynamics),
            typeof(objective),
            typeof(constraints),
            typeof(definition),
            typeof(build_examodel),
        }(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )
    end
end

# ------------------------------------------------------------------------------ #
# Getters — time dependence
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return `true` for an autonomous model.

# Arguments
- `::Model{Autonomous,...}`: An autonomous model.

# Returns
- `Bool`: `true`.

See also: [`CTModels.Models.is_nonautonomous`](@ref).
"""
function is_autonomous(
    ::Model{
        Autonomous,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)
    return true
end

"""
$(TYPEDSIGNATURES)

Return `false` for a non-autonomous model.

# Arguments
- `::Model{NonAutonomous,...}`: A non-autonomous model.

# Returns
- `Bool`: `false`.

See also: [`CTModels.Models.is_autonomous`](@ref).
"""
function is_autonomous(
    ::Model{
        NonAutonomous,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)
    return false
end

"""
$(TYPEDSIGNATURES)

Check whether the problem has optimisation variables.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem has optimisation variables, `false` otherwise.

See also: [`CTModels.Models.is_nonvariable`](@ref), [`CTModels.Models.variable_dimension`](@ref).
"""
function is_variable(ocp::Model)::Bool
    return variable_dimension(ocp) > 0
end

"""
$(TYPEDSIGNATURES)

Check whether the problem is control-free (no control input).

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem has no control input, `false` otherwise.

See also: [`CTModels.Models.has_control`](@ref), [`CTModels.Models.control_dimension`](@ref).
"""
function is_control_free(ocp::Model)::Bool
    return control_dimension(ocp) == 0
end

"""
$(TYPEDSIGNATURES)

Check whether the problem has optimisation variables.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem has optimisation variables, `false` otherwise.

See also: [`CTModels.Models.is_variable`](@ref).
"""
has_variable(ocp::Model)::Bool = is_variable(ocp)

"""
$(TYPEDSIGNATURES)

Check whether the problem has control input.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem has control input, `false` otherwise.

See also: [`CTModels.Models.is_control_free`](@ref).
"""
has_control(ocp::Model)::Bool = !is_control_free(ocp)

"""
$(TYPEDSIGNATURES)

Check whether the problem has an abstract definition.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem has an abstract definition, `false` otherwise.

See also: [`CTModels.Models.is_abstractly_defined`](@ref), [`CTModels.Models.definition`](@ref).
"""
has_abstract_definition(ocp::Model)::Bool = !(definition(ocp) isa EmptyDefinition)

"""
$(TYPEDSIGNATURES)

Check whether the problem is abstractly defined.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem is abstractly defined, `false` otherwise.

See also: [`CTModels.Models.has_abstract_definition`](@ref).
"""
is_abstractly_defined(ocp::Model)::Bool = has_abstract_definition(ocp)

"""
$(TYPEDSIGNATURES)

Check whether the problem is non-autonomous (time-dependent).

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem is non-autonomous, `false` otherwise.

See also: [`CTModels.Models.is_autonomous`](@ref).
"""
is_nonautonomous(ocp::Model)::Bool = !is_autonomous(ocp)

"""
$(TYPEDSIGNATURES)

Check whether the problem has no optimisation variables.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the problem has no optimisation variables, `false` otherwise.

See also: [`CTModels.Models.is_variable`](@ref).
"""
is_nonvariable(ocp::Model)::Bool = !is_variable(ocp)

# ------------------------------------------------------------------------------ #
# Getters — State
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the state struct.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `T`: The state model.

See also: [`CTModels.Models.state_name`](@ref), [`CTModels.Models.state_components`](@ref), [`CTModels.Models.state_dimension`](@ref).
"""
function state(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        T,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractStateModel}
    return ocp.state
end

"""
$(TYPEDSIGNATURES)

Return the name of the state.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `String`: The state name.

See also: [`CTModels.Models.state`](@ref), [`CTModels.Models.state_components`](@ref), [`CTModels.Models.state_dimension`](@ref).
"""
function state_name(ocp::Model)::String
    return name(state(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the state.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Vector{String}`: The state component names.

See also: [`CTModels.Models.state`](@ref), [`CTModels.Models.state_name`](@ref), [`CTModels.Models.state_dimension`](@ref).
"""
function state_components(ocp::Model)::Vector{String}
    return components(state(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the state dimension.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The state dimension.

See also: [`CTModels.Models.state`](@ref), [`CTModels.Models.state_name`](@ref), [`CTModels.Models.state_components`](@ref).
"""
function state_dimension(ocp::Model)::Dimension
    return dimension(state(ocp))
end

# ------------------------------------------------------------------------------ #
# Getters — Control
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the control struct.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `T`: The control model.

See also: [`CTModels.Models.control_name`](@ref), [`CTModels.Models.control_components`](@ref), [`CTModels.Models.control_dimension`](@ref).
"""
function control(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        T,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractControlModel}
    return ocp.control
end

"""
$(TYPEDSIGNATURES)

Return the name of the control.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `String`: The control name.

See also: [`CTModels.Models.control`](@ref), [`CTModels.Models.control_components`](@ref), [`CTModels.Models.control_dimension`](@ref).
"""
function control_name(ocp::Model)::String
    return name(control(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the control.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Vector{String}`: The control component names.

See also: [`CTModels.Models.control`](@ref), [`CTModels.Models.control_name`](@ref), [`CTModels.Models.control_dimension`](@ref).
"""
function control_components(ocp::Model)::Vector{String}
    return components(control(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the control dimension.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The control dimension.

See also: [`CTModels.Models.control`](@ref), [`CTModels.Models.control_name`](@ref), [`CTModels.Models.control_components`](@ref).
"""
function control_dimension(ocp::Model)::Dimension
    return dimension(control(ocp))
end

# ------------------------------------------------------------------------------ #
# Getters — Variable
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the variable struct.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `T`: The variable model.

See also: [`CTModels.Models.variable_name`](@ref), [`CTModels.Models.variable_components`](@ref), [`CTModels.Models.variable_dimension`](@ref).
"""
function variable(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        T,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractVariableModel}
    return ocp.variable
end

"""
$(TYPEDSIGNATURES)

Return the name of the variable.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `String`: The variable name.

See also: [`CTModels.Models.variable`](@ref), [`CTModels.Models.variable_components`](@ref), [`CTModels.Models.variable_dimension`](@ref).
"""
function variable_name(ocp::Model)::String
    return name(variable(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Vector{String}`: The variable component names.

See also: [`CTModels.Models.variable`](@ref), [`CTModels.Models.variable_name`](@ref), [`CTModels.Models.variable_dimension`](@ref).
"""
function variable_components(ocp::Model)::Vector{String}
    return components(variable(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the variable dimension.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The variable dimension.

See also: [`CTModels.Models.variable`](@ref), [`CTModels.Models.variable_name`](@ref), [`CTModels.Models.variable_components`](@ref).
"""
function variable_dimension(ocp::Model)::Dimension
    return dimension(variable(ocp))
end

# ------------------------------------------------------------------------------ #
# Getters — Times
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the times struct.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `T`: The times model.

See also: [`CTModels.Components.time_name`](@ref), [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
function times(
    ocp::Model{
        <:TimeDependence,
        T,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:TimesModel}
    return ocp.times
end

"""
$(TYPEDSIGNATURES)

Return the name of the time.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `String`: The time name.

See also: [`CTModels.Models.times`](@ref), [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
Components.time_name(ocp::Model)::String = Components.time_name(times(ocp))

"""
$(TYPEDSIGNATURES)

Return the name of the initial time.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `String`: The initial time name.

See also: [`CTModels.Models.times`](@ref), [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
Components.initial_time_name(ocp::Model)::String = Components.initial_time_name(times(ocp))

"""
$(TYPEDSIGNATURES)

Return the name of the final time.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `String`: The final time name.

See also: [`CTModels.Models.times`](@ref), [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
Components.final_time_name(ocp::Model)::String = Components.final_time_name(times(ocp))

"""
$(TYPEDSIGNATURES)

Throw an error for unsupported initial time access.
"""
function Components.initial_time(::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot get initial time with this function";
            reason="This model type does not support direct initial time access",
            suggestion="Use initial_time(ocp) on a Model with FixedTimeModel or use initial_time(ocp, variable) for variable initial time",
            context="initial_time on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Throw an error for unsupported initial time access with variable.
"""
function Components.initial_time(::AbstractModel, ::AbstractVector)
    throw(
        Exceptions.PreconditionError(
            "Cannot get initial time with this function";
            reason="This model type does not support initial time access with variable",
            suggestion="Ensure the model has variable initial time configured, or use initial_time(ocp) for fixed initial time",
            context="initial_time with variable on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the initial time, for a fixed initial time.

# Arguments
- `ocp::Model`: The optimal control problem with fixed initial time.

# Returns
- `T`: The initial time value.

See also: [`CTModels.Components.final_time`](@ref), [`CTModels.Components.has_fixed_initial_time`](@ref).
"""
function Components.initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FixedTimeModel{T},<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:Time}
    return Components.initial_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the initial time, for a free initial time.

# Arguments
- `ocp::Model`: The optimal control problem with free initial time.
- `variable::AbstractVector{T}`: The variable vector.

# Returns
- `T`: The initial time value.

See also: [`CTModels.Components.final_time`](@ref), [`CTModels.Components.has_free_initial_time`](@ref).
"""
function Components.initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return Components.initial_time(times(ocp), variable)
end

"""
$(TYPEDSIGNATURES)

Return the initial time, for a free initial time (scalar variable).

# Arguments
- `ocp::Model`: The optimal control problem with free initial time.
- `variable::T`: The variable scalar.

# Returns
- `T`: The initial time value.

See also: [`CTModels.Components.final_time`](@ref), [`CTModels.Components.has_free_initial_time`](@ref).
"""
function Components.initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::T,
)::T where {T<:ctNumber}
    return Components.initial_time(times(ocp), [variable])
end

"""
$(TYPEDSIGNATURES)

Throw an error for unsupported final time access.
"""
function Components.final_time(::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot get final time with this function";
            reason="This model type does not support direct final time access",
            suggestion="Use final_time(ocp) on a Model with FixedTimeModel or use final_time(ocp, variable) for variable final time",
            context="final_time on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Throw an error for unsupported final time access with variable.
"""
function Components.final_time(::AbstractModel, ::AbstractVector)
    throw(
        Exceptions.PreconditionError(
            "Cannot get final time with this function";
            reason="This model type does not support final time access with variable",
            suggestion="Ensure the model has variable final time configured, or use final_time(ocp) for fixed final time",
            context="final_time with variable on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the final time, for a fixed final time.

# Arguments
- `ocp::Model`: The optimal control problem with fixed final time.

# Returns
- `T`: The final time value.

See also: [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.has_fixed_final_time`](@ref).
"""
function Components.final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FixedTimeModel{T}},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:Time}
    return Components.final_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the final time, for a free final time.

# Arguments
- `ocp::Model`: The optimal control problem with free final time.
- `variable::AbstractVector{T}`: The variable vector.

# Returns
- `T`: The final time value.

See also: [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.has_free_final_time`](@ref).
"""
function Components.final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return Components.final_time(times(ocp), variable)
end

"""
$(TYPEDSIGNATURES)

Return the final time, for a free final time (scalar variable).

# Arguments
- `ocp::Model`: The optimal control problem with free final time.
- `variable::T`: The variable scalar.

# Returns
- `T`: The final time value.

See also: [`CTModels.Components.initial_time`](@ref), [`CTModels.Components.has_free_final_time`](@ref).
"""
function Components.final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::T,
)::T where {T<:ctNumber}
    return Components.final_time(times(ocp), [variable])
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the initial time is fixed, `false` otherwise.

See also: [`CTModels.Components.has_free_initial_time`](@ref), [`CTModels.Components.initial_time`](@ref).
"""
Components.has_fixed_initial_time(ocp::Model)::Bool =
    Components.has_fixed_initial_time(times(ocp))

"""
$(TYPEDSIGNATURES)

Check if the initial time is free.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the initial time is free, `false` otherwise.

See also: [`CTModels.Components.has_fixed_initial_time`](@ref), [`CTModels.Components.initial_time`](@ref).
"""
Components.has_free_initial_time(ocp::Model)::Bool =
    Components.has_free_initial_time(times(ocp))

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the final time is fixed, `false` otherwise.

See also: [`CTModels.Components.has_free_final_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
Components.has_fixed_final_time(ocp::Model)::Bool =
    Components.has_fixed_final_time(times(ocp))

"""
$(TYPEDSIGNATURES)

Check if the final time is free.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the final time is free, `false` otherwise.

See also: [`CTModels.Components.has_fixed_final_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
Components.has_free_final_time(ocp::Model)::Bool =
    Components.has_free_final_time(times(ocp))

# ------------------------------------------------------------------------------ #
# Getters — Objective
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the objective struct.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `O`: The objective model.

See also: [`CTModels.Components.criterion`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.lagrange`](@ref).
"""
function objective(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        O,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::O where {O<:AbstractObjectiveModel}
    return ocp.objective
end

"""
$(TYPEDSIGNATURES)

Return the type of criterion (:min or :max).

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Symbol`: The criterion type (`:min` or `:max`).

See also: [`CTModels.Models.objective`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.lagrange`](@ref).
"""
Components.criterion(ocp::Model)::Symbol = Components.criterion(objective(ocp))

"""
$(TYPEDSIGNATURES)

Throw an error when accessing Mayer cost on a model without one.
"""
function Components.mayer(::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot access Mayer cost";
            reason="This OCP has no Mayer objective defined",
            suggestion="Define a Mayer objective using objective!(ocp, :min/:max, mayer=...) before accessing it",
            context="mayer accessor",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the Mayer cost.

# Arguments
- `ocp::Model`: The optimal control problem with Mayer objective.

# Returns
- `M`: The Mayer cost function.

See also: [`CTModels.Models.objective`](@ref), [`CTModels.Components.lagrange`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
function Components.mayer(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:MayerObjectiveModel{M},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::M where {M<:Function}
    return Components.mayer(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the Mayer cost.

# Arguments
- `ocp::Model`: The optimal control problem with Bolza objective (Mayer + Lagrange).

# Returns
- `M`: The Mayer cost function.

See also: [`CTModels.Models.objective`](@ref), [`CTModels.Components.lagrange`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
function Components.mayer(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{M,<:Function},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::M where {M<:Function}
    return Components.mayer(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the model has a Mayer cost.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the model has a Mayer cost, `false` otherwise.

See also: [`CTModels.Components.mayer`](@ref), [`CTModels.Components.has_lagrange_cost`](@ref).
"""
Components.has_mayer_cost(ocp::Model)::Bool = Components.has_mayer_cost(objective(ocp))

"""
$(TYPEDSIGNATURES)

Throw an error when accessing Lagrange cost on a model without one.
"""
function Components.lagrange(::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot access Lagrange cost";
            reason="This OCP has no Lagrange objective defined",
            suggestion="Define a Lagrange objective using objective!(ocp, :min/:max, lagrange=...) before accessing it",
            context="lagrange accessor",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange cost.

# Arguments
- `ocp::Model`: The optimal control problem with Lagrange objective.

# Returns
- `L`: The Lagrange cost function.

See also: [`CTModels.Models.objective`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.has_lagrange_cost`](@ref).
"""
function Components.lagrange(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        LagrangeObjectiveModel{L},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::L where {L<:Function}
    return Components.lagrange(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange cost.

# Arguments
- `ocp::Model`: The optimal control problem with Bolza objective (Mayer + Lagrange).

# Returns
- `L`: The Lagrange cost function.

See also: [`CTModels.Models.objective`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.has_lagrange_cost`](@ref).
"""
function Components.lagrange(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{<:Function,L},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::L where {L<:Function}
    return Components.lagrange(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the model has a Lagrange cost.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the model has a Lagrange cost, `false` otherwise.

See also: [`CTModels.Components.lagrange`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
Components.has_lagrange_cost(ocp::Model)::Bool =
    Components.has_lagrange_cost(objective(ocp))

# ------------------------------------------------------------------------------ #
# Getters — Dynamics
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the dynamics.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `D`: The dynamics function.

See also: [`CTModels.Models.state`](@ref), [`CTModels.Models.control`](@ref).
"""
function dynamics(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        D,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::D where {D<:Function}
    return ocp.dynamics
end

# ------------------------------------------------------------------------------ #
# Getters — ExaModels builder
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the build_examodel.

# Arguments
- `ocp::Model`: The optimal control problem with ExaModels builder.

# Returns
- `BE`: The ExaModels builder function.

See also: [`CTModels.Models.dynamics`](@ref).
"""
function get_build_examodel(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        BE,
    },
)::BE where {BE<:Function}
    return ocp.build_examodel
end

"""
$(TYPEDSIGNATURES)

Fallback: throw when no Exa builder is present.
"""
function get_build_examodel(
    ::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Nothing,
    },
)
    throw(
        Exceptions.PreconditionError(
            "The :exa modeler is not available for this model";
            reason="this Model was built with the functional (macro-free) API (PreModel + time!/state!/control!/variable!/dynamics!/objective!/constraint! + build), which does not generate the Exa builder required by the Exa (:exa) modeler",
            suggestion="either choose another modeler, e.g. ADNLP (:adnlp), or define the optimal control problem with the @def macro so that the Exa builder is generated",
            context="get_build_examodel called on a Model built without an Exa builder",
        ),
    )
end

# ------------------------------------------------------------------------------ #
# Getters — Constraints
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the constraints struct.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `C`: The constraints model.

See also: [`CTModels.Models.isempty_constraints`](@ref), [`CTModels.Models.constraint`](@ref).
"""
function constraints(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        C,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::C where {C<:AbstractConstraintsModel}
    return ocp.constraints
end

"""
$(TYPEDSIGNATURES)

Return true if the model has no constraints.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Bool`: `true` if the model has no constraints, `false` otherwise.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Models.constraint`](@ref).
"""
function isempty_constraints(ocp::Model)::Bool
    return Base.isempty(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the nonlinear path constraints.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Function`: The nonlinear path constraints function.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Components.boundary_constraints_nl`](@ref).
"""
function Components.path_constraints_nl(ocp::Model)
    return Components.path_constraints_nl(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the nonlinear boundary constraints.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Function`: The nonlinear boundary constraints function.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Components.path_constraints_nl`](@ref).
"""
function Components.boundary_constraints_nl(ocp::Model)
    return Components.boundary_constraints_nl(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the box constraints on state.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `BoxConstraints`: The box constraints on state.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Components.control_constraints_box`](@ref).
"""
function Components.state_constraints_box(ocp::Model)
    return Components.state_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the box constraints on control.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `BoxConstraints`: The box constraints on control.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Components.state_constraints_box`](@ref).
"""
function Components.control_constraints_box(ocp::Model)
    return Components.control_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the box constraints on variable.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `BoxConstraints`: The box constraints on variable.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Components.state_constraints_box`](@ref).
"""
function Components.variable_constraints_box(ocp::Model)
    return Components.variable_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The dimension of nonlinear path constraints.

See also: [`CTModels.Components.path_constraints_nl`](@ref), [`CTModels.Components.dim_boundary_constraints_nl`](@ref).
"""
Components.dim_path_constraints_nl(ocp::Model)::Dimension =
    Components.dim_path_constraints_nl(constraints(ocp))

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The dimension of boundary constraints.

See also: [`CTModels.Components.boundary_constraints_nl`](@ref), [`CTModels.Components.dim_path_constraints_nl`](@ref).
"""
Components.dim_boundary_constraints_nl(ocp::Model)::Dimension =
    Components.dim_boundary_constraints_nl(constraints(ocp))

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The dimension of box constraints on state.

See also: [`CTModels.Components.state_constraints_box`](@ref), [`CTModels.Components.dim_control_constraints_box`](@ref).
"""
Components.dim_state_constraints_box(ocp::Model)::Dimension =
    Components.dim_state_constraints_box(constraints(ocp))

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The dimension of box constraints on control.

See also: [`CTModels.Components.control_constraints_box`](@ref), [`CTModels.Components.dim_state_constraints_box`](@ref).
"""
Components.dim_control_constraints_box(ocp::Model)::Dimension =
    Components.dim_control_constraints_box(constraints(ocp))

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on variable.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Dimension`: The dimension of box constraints on variable.

See also: [`CTModels.Components.variable_constraints_box`](@ref), [`CTModels.Components.dim_state_constraints_box`](@ref).
"""
Components.dim_variable_constraints_box(ocp::Model)::Dimension =
    Components.dim_variable_constraints_box(constraints(ocp))

# ------------------------------------------------------------------------------ #
# Getters — Definition
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the model definition.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `D`: The model definition.

See also: [`CTModels.Components.expression`](@ref).
"""
function definition(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        D,
        <:Union{Function,Nothing},
    },
)::D where {D<:AbstractDefinition}
    return ocp.definition
end

"""
$(TYPEDSIGNATURES)

Return the symbolic expression of the model definition.

# Arguments
- `ocp::Model`: The optimal control problem.

# Returns
- `Expr`: The symbolic expression of the model definition.

See also: [`CTModels.Models.definition`](@ref).
"""
Components.expression(ocp::Model)::Expr = Components.expression(definition(ocp))

# ------------------------------------------------------------------------------ #
# constraint(::Model, label) — retrieve a labelled constraint by name
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Get a labelled constraint from the model. Returns a tuple of the form
`(type, f, lb, ub)` where `type` is the type of the constraint, `f` is the function,
`lb` is the lower bound and `ub` is the upper bound.

The function returns an exception if the label is not found in the model.

# Arguments
- `model::Model`: The optimal control problem.
- `label::Symbol`: The constraint label.

# Returns
- `Tuple`: A tuple of the form `(type, f, lb, ub)`.

See also: [`CTModels.Models.constraints`](@ref), [`CTModels.Components.path_constraints_nl`](@ref).
"""
function constraint(model::Model, label::Symbol)::Tuple # not type stable: Tuple element types depend on the runtime label value

    # check if the label is in the path constraints
    cp = Components.path_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        indices = findall(x -> x == label, labels)
        fc! = SubPathConstraint(cp, length(cp[1]), indices)
        return (
            :path,
            Core.to_out_of_place(fc!, length(indices)),
            length(indices) == 1 ? cp[1][indices[1]] : cp[1][indices],
            length(indices) == 1 ? cp[3][indices[1]] : cp[3][indices],
        )
    end

    # check if the label is in the boundary constraints
    cp = Components.boundary_constraints_nl(model)
    labels = cp[4]
    if label in labels
        indices = findall(x -> x == label, labels)
        fc! = SubBoundaryConstraint(cp, length(cp[1]), indices)
        return (
            :boundary,
            Core.to_out_of_place(fc!, length(indices)),
            length(indices) == 1 ? cp[1][indices[1]] : cp[1][indices],
            length(indices) == 1 ? cp[3][indices[1]] : cp[3][indices],
        )
    end

    # Box constraints: each box tuple has the form (lb, ind, ub, labels, aliases)
    function _lookup_box(cp, lbl)
        aliases = cp[5]
        idxs = Int[]
        for k in eachindex(aliases)
            if lbl in aliases[k]
                push!(idxs, k)
            end
        end
        return idxs
    end

    # state box
    cp = Components.state_constraints_box(model)
    idxs = _lookup_box(cp, label)
    if !isempty(idxs)
        cidx = length(idxs) == 1 ? cp[2][idxs[1]] : cp[2][idxs]
        return (
            :state,
            BoxProjection{:state}(cidx),
            length(idxs) == 1 ? cp[1][idxs[1]] : cp[1][idxs],
            length(idxs) == 1 ? cp[3][idxs[1]] : cp[3][idxs],
        )
    end

    # control box
    cp = Components.control_constraints_box(model)
    idxs = _lookup_box(cp, label)
    if !isempty(idxs)
        cidx = length(idxs) == 1 ? cp[2][idxs[1]] : cp[2][idxs]
        return (
            :control,
            BoxProjection{:control}(cidx),
            length(idxs) == 1 ? cp[1][idxs[1]] : cp[1][idxs],
            length(idxs) == 1 ? cp[3][idxs[1]] : cp[3][idxs],
        )
    end

    # variable box
    cp = Components.variable_constraints_box(model)
    idxs = _lookup_box(cp, label)
    if !isempty(idxs)
        cidx = length(idxs) == 1 ? cp[2][idxs[1]] : cp[2][idxs]
        return (
            :variable,
            BoxProjection{:variable}(cidx),
            length(idxs) == 1 ? cp[1][idxs[1]] : cp[1][idxs],
            length(idxs) == 1 ? cp[3][idxs[1]] : cp[3][idxs],
        )
    end

    throw(
        Exceptions.IncorrectArgument(
            "Constraint label not found";
            got="label :$label",
            expected="existing constraint label in the model",
            suggestion="Check available constraint labels or add a constraint with this label first",
            context="constraint lookup by label",
        ),
    )
end
