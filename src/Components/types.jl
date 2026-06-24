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

See also: [`CTModels.Components.StateModel`](@ref), [`CTModels.Components.StateModelSolution`](@ref),
[`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref).
"""
abstract type AbstractStateModel end

"""
$(TYPEDEF)

State model describing the structure of the state variable in an optimal control
problem definition.

# Fields

- `name::String`: Display name for the state variable (e.g., `"x"`).
- `components::Vector{String}`: Names of individual state components (e.g., `["x₁", "x₂"]`).

See also: [`CTModels.Components.AbstractStateModel`](@ref), [`CTModels.Components.StateModelSolution`](@ref),
[`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref).
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

See also: [`CTModels.Components.AbstractStateModel`](@ref), [`CTModels.Components.StateModel`](@ref),
[`CTModels.Components.value`](@ref).
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

See also: [`CTModels.Components.ControlModel`](@ref), [`CTModels.Components.ControlModelSolution`](@ref),
[`CTModels.Components.EmptyControlModel`](@ref), [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref).
"""
abstract type AbstractControlModel end

"""
$(TYPEDEF)

Control model describing the structure of the control variable in an optimal
control problem definition.

# Fields

- `name::String`: Display name for the control variable (e.g., `"u"`).
- `components::Vector{String}`: Names of individual control components (e.g., `["u₁", "u₂"]`).

See also: [`CTModels.Components.AbstractControlModel`](@ref), [`CTModels.Components.ControlModelSolution`](@ref),
[`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref).
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

See also: [`CTModels.Components.AbstractControlModel`](@ref), [`CTModels.Components.ControlModel`](@ref),
[`CTModels.Components.value`](@ref), [`CTModels.Components.interpolation`](@ref).
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

See also: [`CTModels.Components.ControlModel`](@ref), [`CTModels.Components.AbstractControlModel`](@ref).
"""
struct EmptyControlModel <: AbstractControlModel end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for optimisation variable models in optimal control problems.

See also: [`CTModels.Components.VariableModel`](@ref), [`CTModels.Components.EmptyVariableModel`](@ref),
[`CTModels.Components.VariableModelSolution`](@ref), [`CTModels.Components.name`](@ref), [`CTModels.Components.dimension`](@ref).
"""
abstract type AbstractVariableModel end

"""
$(TYPEDEF)

Variable model describing the structure of the optimisation variable.

# Fields

- `name::String`: Display name for the variable (e.g., `"v"`).
- `components::Vector{String}`: Names of individual variable components.

See also: [`CTModels.Components.AbstractVariableModel`](@ref), [`CTModels.Components.VariableModelSolution`](@ref),
[`CTModels.Components.name`](@ref), [`CTModels.Components.components`](@ref), [`CTModels.Components.dimension`](@ref).
"""
struct VariableModel <: AbstractVariableModel
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

Sentinel type representing the absence of optimisation variables.

See also: [`CTModels.Components.AbstractVariableModel`](@ref), [`CTModels.Components.VariableModel`](@ref).
"""
struct EmptyVariableModel <: AbstractVariableModel end

"""
$(TYPEDEF)

Variable model for a solved optimal control problem, including the variable value.

# Fields

- `name::String`: Display name for the variable.
- `components::Vector{String}`: Names of individual variable components.
- `value::TS`: The optimisation variable value (scalar or vector).

See also: [`CTModels.Components.AbstractVariableModel`](@ref), [`CTModels.Components.VariableModel`](@ref),
[`CTModels.Components.value`](@ref).
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

See also: [`CTModels.Components.FixedTimeModel`](@ref), [`CTModels.Components.FreeTimeModel`](@ref),
[`CTModels.Components.TimesModel`](@ref), [`CTModels.Components.time_name`](@ref).
"""
abstract type AbstractTimeModel end

"""
$(TYPEDEF)

Time model representing a fixed (known) time boundary.

# Fields

- `time::T`: The fixed time value.
- `name::String`: Display name for this time (e.g., `"t₀"` or `"tf"`).

See also: [`CTModels.Components.AbstractTimeModel`](@ref), [`CTModels.Components.FreeTimeModel`](@ref),
[`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
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

See also: [`CTModels.Components.AbstractTimeModel`](@ref), [`CTModels.Components.FixedTimeModel`](@ref),
[`CTModels.Components.initial_time`](@ref), [`CTModels.Components.final_time`](@ref).
"""
struct FreeTimeModel <: AbstractTimeModel
    index::Int
    name::String
end

"""
$(TYPEDEF)

Abstract base type for combined initial and final time models.

See also: [`CTModels.Components.TimesModel`](@ref), [`CTModels.Components.FixedTimeModel`](@ref),
[`CTModels.Components.FreeTimeModel`](@ref).
"""
abstract type AbstractTimesModel end

"""
$(TYPEDEF)

Combined model for initial and final times in an optimal control problem.

# Fields

- `initial::TI`: The initial time model (fixed or free).
- `final::TF`: The final time model (fixed or free).
- `time_name::String`: Display name for the time variable (e.g., `"t"`).

See also: [`CTModels.Components.AbstractTimesModel`](@ref), [`CTModels.Components.FixedTimeModel`](@ref),
[`CTModels.Components.FreeTimeModel`](@ref), [`CTModels.Components.initial`](@ref), [`CTModels.Components.final`](@ref).
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

See also: [`CTModels.Components.MayerObjectiveModel`](@ref),
[`CTModels.Components.LagrangeObjectiveModel`](@ref), [`CTModels.Components.BolzaObjectiveModel`](@ref),
[`CTModels.Components.criterion`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.lagrange`](@ref).
"""
abstract type AbstractObjectiveModel end

"""
$(TYPEDEF)

Objective model with only a Mayer (terminal) cost: `g(x(t₀), x(tf), v)`.

# Fields

- `mayer::TM`: The Mayer cost function `(x0, xf, v) -> g(x0, xf, v)`.
- `criterion::Symbol`: Optimisation direction, either `:min` or `:max`.

See also: [`CTModels.Components.AbstractObjectiveModel`](@ref), [`CTModels.Components.LagrangeObjectiveModel`](@ref),
[`CTModels.Components.BolzaObjectiveModel`](@ref), [`CTModels.Components.mayer`](@ref).
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

See also: [`CTModels.Components.AbstractObjectiveModel`](@ref), [`CTModels.Components.MayerObjectiveModel`](@ref),
[`CTModels.Components.BolzaObjectiveModel`](@ref), [`CTModels.Components.lagrange`](@ref).
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

See also: [`CTModels.Components.AbstractObjectiveModel`](@ref), [`CTModels.Components.MayerObjectiveModel`](@ref),
[`CTModels.Components.LagrangeObjectiveModel`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.lagrange`](@ref).
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

See also: [`CTModels.Components.ConstraintsModel`](@ref), [`CTModels.Components.path_constraints_nl`](@ref),
[`CTModels.Components.state_constraints_box`](@ref).
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

See also: [`CTModels.Components.AbstractConstraintsModel`](@ref), [`CTModels.Components.path_constraints_nl`](@ref),
[`CTModels.Components.state_constraints_box`](@ref), [`CTModels.Components.control_constraints_box`](@ref).
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

See also: [`CTModels.Components.Definition`](@ref), [`CTModels.Components.EmptyDefinition`](@ref),
[`CTModels.Components.expression`](@ref).
"""
abstract type AbstractDefinition end

"""
$(TYPEDEF)

Sentinel type representing the absence of a symbolic definition.

See also: [`CTModels.Components.AbstractDefinition`](@ref), [`CTModels.Components.Definition`](@ref),
[`CTModels.Components.expression`](@ref).
"""
struct EmptyDefinition <: AbstractDefinition end

"""
$(TYPEDEF)

Wrapper around a Julia `Expr` holding the original symbolic definition of an
optimal control problem (typically produced by the `@def` DSL).

# Fields

- `expr::Expr`: The symbolic expression defining the problem.

See also: [`CTModels.Components.AbstractDefinition`](@ref), [`CTModels.Components.EmptyDefinition`](@ref),
[`CTModels.Components.expression`](@ref).
"""
struct Definition <: AbstractDefinition
    expr::Expr
end
