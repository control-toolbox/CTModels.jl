# ------------------------------------------------------------------------------ #
# Continuous-time OCP component types
# (time dependence, state/control/variable models, time models, objectives,
#  constraints, definitions)
# ------------------------------------------------------------------------------ #

# TimeDependence / Autonomous / NonAutonomous are now defined in `CTBase.Traits`
# and imported into this module (see Components.jl). They remain exported from
# `CTModels.Components` for backward compatibility.

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for state variable models in optimal control problems.

Subtypes describe the state space structure including dimension, naming, and
optionally the state trajectory itself.

See also: [`CTModels.Components.StateModel`](@extref), [`CTModels.Components.StateModelSolution`](@extref),
[`CTModels.Components.name`](@extref), [`CTModels.Components.dimension`](@extref).
"""
abstract type AbstractStateModel end

"""
$(TYPEDEF)

State model describing the structure of the state variable in an optimal control
problem definition.

# Fields

- `name::String`: Display name for the state variable (e.g., `"x"`).
- `components::Vector{String}`: Names of individual state components (e.g., `["x₁", "x₂"]`).

See also: [`CTModels.Components.AbstractStateModel`](@extref), [`CTModels.Components.StateModelSolution`](@extref),
[`CTModels.Components.name`](@extref), [`CTModels.Components.components`](@extref), [`CTModels.Components.dimension`](@extref).
"""
struct StateModel <: AbstractStateModel
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

State model for a solved optimal control problem, including the state trajectory.

# Fields

- `name::String`: Display name for the state variable.
- `components::Vector{String}`: Names of individual state components.
- `value::TS`: A function `t -> x(t)` returning the state vector at time `t`.

See also: [`CTModels.Components.AbstractStateModel`](@extref), [`CTModels.Components.StateModel`](@extref),
[`CTModels.Components.value`](@extref).
"""
struct StateModelSolution{TS<:Function} <: AbstractStateModel
    name::String
    components::Vector{String}
    value::TS
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for control variable models in optimal control problems.

See also: [`CTModels.Components.ControlModel`](@extref), [`CTModels.Components.ControlModelSolution`](@extref),
[`CTModels.Components.EmptyControlModel`](@extref), [`CTModels.Components.name`](@extref), [`CTModels.Components.dimension`](@extref).
"""
abstract type AbstractControlModel end

"""
$(TYPEDEF)

Control model describing the structure of the control variable in an optimal
control problem definition.

# Fields

- `name::String`: Display name for the control variable (e.g., `"u"`).
- `components::Vector{String}`: Names of individual control components (e.g., `["u₁", "u₂"]`).

See also: [`CTModels.Components.AbstractControlModel`](@extref), [`CTModels.Components.ControlModelSolution`](@extref),
[`CTModels.Components.name`](@extref), [`CTModels.Components.components`](@extref), [`CTModels.Components.dimension`](@extref).
"""
struct ControlModel <: AbstractControlModel
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

Represents the control trajectory in a solution.

# Fields
- `name::String`: Name of the control variable (e.g., `"u"`).
- `components::Vector{String}`: Names of individual control components.
- `value::TS`: A function `t -> u(t)` returning the control vector at time `t`.
- `interpolation::Symbol`: Interpolation type (`:constant` or `:linear`).

See also: [`CTModels.Components.AbstractControlModel`](@extref), [`CTModels.Components.ControlModel`](@extref),
[`CTModels.Components.value`](@extref), [`CTModels.Components.interpolation`](@extref).
"""
struct ControlModelSolution{TS<:Function} <: AbstractControlModel
    name::String
    components::Vector{String}
    value::TS
    interpolation::Symbol
end

"""
$(TYPEDEF)

Sentinel type representing the absence of a control input in an optimal control problem.

See also: [`CTModels.Components.ControlModel`](@extref), [`CTModels.Components.AbstractControlModel`](@extref).
"""
struct EmptyControlModel <: AbstractControlModel end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for optimisation variable models in optimal control problems.

See also: [`CTModels.Components.VariableModel`](@extref), [`CTModels.Components.EmptyVariableModel`](@extref),
[`CTModels.Components.VariableModelSolution`](@extref), [`CTModels.Components.name`](@extref), [`CTModels.Components.dimension`](@extref).
"""
abstract type AbstractVariableModel end

"""
$(TYPEDEF)

Variable model describing the structure of the optimisation variable.

# Fields

- `name::String`: Display name for the variable (e.g., `"v"`).
- `components::Vector{String}`: Names of individual variable components.

See also: [`CTModels.Components.AbstractVariableModel`](@extref), [`CTModels.Components.VariableModelSolution`](@extref),
[`CTModels.Components.name`](@extref), [`CTModels.Components.components`](@extref), [`CTModels.Components.dimension`](@extref).
"""
struct VariableModel <: AbstractVariableModel
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

Sentinel type representing the absence of optimisation variables.

See also: [`CTModels.Components.AbstractVariableModel`](@extref), [`CTModels.Components.VariableModel`](@extref).
"""
struct EmptyVariableModel <: AbstractVariableModel end

"""
$(TYPEDEF)

Variable model for a solved optimal control problem, including the variable value.

# Fields

- `name::String`: Display name for the variable.
- `components::Vector{String}`: Names of individual variable components.
- `value::TS`: The optimisation variable value (scalar or vector).

See also: [`CTModels.Components.AbstractVariableModel`](@extref), [`CTModels.Components.VariableModel`](@extref),
[`CTModels.Components.value`](@extref).
"""
struct VariableModelSolution{TS<:Union{ctNumber,ctVector}} <: AbstractVariableModel
    name::String
    components::Vector{String}
    value::TS
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for time boundary models (initial or final time).

See also: [`CTModels.Components.FixedTimeModel`](@extref), [`CTModels.Components.FreeTimeModel`](@extref),
[`CTModels.Components.TimesModel`](@extref), [`CTModels.Components.time_name`](@extref).
"""
abstract type AbstractTimeModel end

"""
$(TYPEDEF)

Time model representing a fixed (known) time boundary.

# Fields

- `time::T`: The fixed time value.
- `name::String`: Display name for this time (e.g., `"t₀"` or `"tf"`).

See also: [`CTModels.Components.AbstractTimeModel`](@extref), [`CTModels.Components.FreeTimeModel`](@extref),
[`CTModels.Components.initial_time`](@extref), [`CTModels.Components.final_time`](@extref).
"""
struct FixedTimeModel{T<:Time} <: AbstractTimeModel
    time::T
    name::String
end

"""
$(TYPEDEF)

Time model representing a free (optimised) time boundary.

The actual time value is stored in the optimisation variable at the given index.

# Fields

- `index::Int`: Index into the optimisation variable where this time is stored.
- `name::String`: Display name for this time (e.g., `"tf"`).

See also: [`CTModels.Components.AbstractTimeModel`](@extref), [`CTModels.Components.FixedTimeModel`](@extref),
[`CTModels.Components.initial_time`](@extref), [`CTModels.Components.final_time`](@extref).
"""
struct FreeTimeModel <: AbstractTimeModel
    index::Int
    name::String
end

"""
$(TYPEDEF)

Abstract base type for combined initial and final time models.

See also: [`CTModels.Components.TimesModel`](@extref), [`CTModels.Components.FixedTimeModel`](@extref),
[`CTModels.Components.FreeTimeModel`](@extref).
"""
abstract type AbstractTimesModel end

"""
$(TYPEDEF)

Combined model for initial and final times in an optimal control problem.

# Fields

- `initial::TI`: The initial time model (fixed or free).
- `final::TF`: The final time model (fixed or free).
- `time_name::String`: Display name for the time variable (e.g., `"t"`).

See also: [`CTModels.Components.AbstractTimesModel`](@extref), [`CTModels.Components.FixedTimeModel`](@extref),
[`CTModels.Components.FreeTimeModel`](@extref), [`CTModels.Components.initial`](@extref), [`CTModels.Components.final`](@extref).
"""
struct TimesModel{TI<:AbstractTimeModel,TF<:AbstractTimeModel} <: AbstractTimesModel
    initial::TI
    final::TF
    time_name::String
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for objective function models in optimal control problems.

See also: [`CTModels.Components.MayerObjectiveModel`](@extref),
[`CTModels.Components.LagrangeObjectiveModel`](@extref), [`CTModels.Components.BolzaObjectiveModel`](@extref),
[`CTModels.Components.criterion`](@extref), [`CTModels.Components.mayer`](@extref), [`CTModels.Components.lagrange`](@extref).
"""
abstract type AbstractObjectiveModel end

"""
$(TYPEDEF)

Objective model with only a Mayer (terminal) cost: `g(x(t₀), x(tf), v)`.

# Fields

- `mayer::TM`: The Mayer cost function `(x0, xf, v) -> g(x0, xf, v)`.
- `criterion::Symbol`: Optimisation direction, either `:min` or `:max`.

See also: [`CTModels.Components.AbstractObjectiveModel`](@extref), [`CTModels.Components.LagrangeObjectiveModel`](@extref),
[`CTModels.Components.BolzaObjectiveModel`](@extref), [`CTModels.Components.mayer`](@extref).
"""
struct MayerObjectiveModel{TM<:Function} <: AbstractObjectiveModel
    mayer::TM
    criterion::Symbol
end

"""
$(TYPEDEF)

Objective model with only a Lagrange (integral) cost: `∫ f⁰(t, x, u, v) dt`.

# Fields

- `lagrange::TL`: The Lagrange integrand `(t, x, u, v) -> f⁰(t, x, u, v)`.
- `criterion::Symbol`: Optimisation direction, either `:min` or `:max`.

See also: [`CTModels.Components.AbstractObjectiveModel`](@extref), [`CTModels.Components.MayerObjectiveModel`](@extref),
[`CTModels.Components.BolzaObjectiveModel`](@extref), [`CTModels.Components.lagrange`](@extref).
"""
struct LagrangeObjectiveModel{TL<:Function} <: AbstractObjectiveModel
    lagrange::TL
    criterion::Symbol
end

"""
$(TYPEDEF)

Objective model with both Mayer and Lagrange costs (Bolza form):
`g(x(t₀), x(tf), v) + ∫ f⁰(t, x, u, v) dt`.

# Fields

- `mayer::TM`: The Mayer cost function.
- `lagrange::TL`: The Lagrange integrand.
- `criterion::Symbol`: Optimisation direction, either `:min` or `:max`.

See also: [`CTModels.Components.AbstractObjectiveModel`](@extref), [`CTModels.Components.MayerObjectiveModel`](@extref),
[`CTModels.Components.LagrangeObjectiveModel`](@extref), [`CTModels.Components.mayer`](@extref), [`CTModels.Components.lagrange`](@extref).
"""
struct BolzaObjectiveModel{TM<:Function,TL<:Function} <: AbstractObjectiveModel
    mayer::TM
    lagrange::TL
    criterion::Symbol
end

# ------------------------------------------------------------------------------ #
# Constraints
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for constraint models in optimal control problems.

See also: [`CTModels.Components.ConstraintsModel`](@extref), [`CTModels.Components.path_constraints_nl`](@extref),
[`CTModels.Components.state_constraints_box`](@extref).
"""
abstract type AbstractConstraintsModel end

"""
$(TYPEDEF)

Container for all constraints in an optimal control problem.

# Fields

- `path_nl::TP`: Tuple of nonlinear path constraints `(lb, f!, ub, labels)`.
- `boundary_nl::TB`: Tuple of nonlinear boundary constraints `(lb, f!, ub, labels)`.
- `state_box::TS`: Tuple of box constraints on state variables `(lb, ind, ub, labels, aliases)`.
- `control_box::TC`: Tuple of box constraints on control variables (same structure).
- `variable_box::TV`: Tuple of box constraints on optimisation variables (same structure).

See also: [`CTModels.Components.AbstractConstraintsModel`](@extref), [`CTModels.Components.path_constraints_nl`](@extref),
[`CTModels.Components.state_constraints_box`](@extref), [`CTModels.Components.control_constraints_box`](@extref).
"""
struct ConstraintsModel{TP<:Tuple,TB<:Tuple,TS<:Tuple,TC<:Tuple,TV<:Tuple} <:
       AbstractConstraintsModel
    path_nl::TP
    boundary_nl::TB
    state_box::TS
    control_box::TC
    variable_box::TV
end

# ------------------------------------------------------------------------------ #
# Definition (symbolic)
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for the symbolic definition attached to an optimal control problem.

See also: [`CTModels.Components.Definition`](@extref), [`CTModels.Components.EmptyDefinition`](@extref),
[`CTModels.Components.expression`](@extref).
"""
abstract type AbstractDefinition end

"""
$(TYPEDEF)

Sentinel type representing the absence of a symbolic definition.

See also: [`CTModels.Components.AbstractDefinition`](@extref), [`CTModels.Components.Definition`](@extref),
[`CTModels.Components.expression`](@extref).
"""
struct EmptyDefinition <: AbstractDefinition end

"""
$(TYPEDEF)

Wrapper around a Julia `Expr` holding the original symbolic definition of an
optimal control problem (typically produced by the `@def` DSL).

# Fields

- `expr::Expr`: The symbolic expression defining the problem.

See also: [`CTModels.Components.AbstractDefinition`](@extref), [`CTModels.Components.EmptyDefinition`](@extref),
[`CTModels.Components.expression`](@extref).
"""
struct Definition <: AbstractDefinition
    expr::Expr
end
