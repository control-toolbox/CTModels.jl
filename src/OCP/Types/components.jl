# ------------------------------------------------------------------------------ #
# Continuous-time OCP component types
# (time dependence, state/control/variable models, time models, objectives, constraints)
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type representing time dependence of an optimal control problem.

Used as a type parameter to distinguish between autonomous and non-autonomous
systems at the type level, enabling dispatch and compile-time optimisations.

See also: `Autonomous`, `NonAutonomous`.
"""
abstract type TimeDependence end

"""
$(TYPEDEF)

Type tag indicating that the dynamics and other functions of an optimal control
problem do not explicitly depend on time.

For autonomous systems, the dynamics have the form `ẋ = f(x, u)` rather than
`ẋ = f(t, x, u)`.

See also: `TimeDependence`, `NonAutonomous`.
"""
abstract type Autonomous<:TimeDependence end

"""
$(TYPEDEF)

Type tag indicating that the dynamics and other functions of an optimal control
problem explicitly depend on time.

For non-autonomous systems, the dynamics have the form `ẋ = f(t, x, u)`.

See also: `TimeDependence`, `Autonomous`.
"""
abstract type NonAutonomous<:TimeDependence end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for state variable models in optimal control problems.

Subtypes describe the state space structure including dimension, naming, and
optionally the state trajectory itself.

See also: `StateModel`, `StateModelSolution`.
"""
abstract type AbstractStateModel end

"""
$(TYPEDEF)

State model describing the structure of the state variable in an optimal control
problem definition.

# Fields

- `name::String`: Display name for the state variable (e.g., `"x"`).
- `components::Vector{String}`: Names of individual state components (e.g., `["x₁", "x₂"]`).

# Example

```julia-repl
julia> using CTModels

julia> sm = CTModels.StateModel("x", ["position", "velocity"])
```
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

# Example

```julia-repl
julia> using CTModels

julia> x_traj = t -> [cos(t), sin(t)]
julia> sms = CTModels.StateModelSolution("x", ["x₁", "x₂"], x_traj)
julia> sms.value(0.0)
2-element Vector{Float64}:
 1.0
 0.0
```
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

Subtypes describe the control space structure including dimension, naming, and
optionally the control trajectory itself.

See also: `ControlModel`, `ControlModelSolution`.
"""
abstract type AbstractControlModel end

"""
$(TYPEDEF)

Control model describing the structure of the control variable in an optimal
control problem definition.

# Fields

- `name::String`: Display name for the control variable (e.g., `"u"`).
- `components::Vector{String}`: Names of individual control components (e.g., `["u₁", "u₂"]`).

# Example

```julia-repl
julia> using CTModels

julia> cm = CTModels.ControlModel("u", ["thrust", "steering"])
```
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
- `components::Vector{String}`: Names of individual control components (e.g., `["u₁", "u₂"]`).
- `value::TS`: A function `t -> u(t)` returning the control vector at time `t`.
- `interpolation::Symbol`: Interpolation type (`:constant` for piecewise constant, `:linear` for piecewise linear).

# Example

```julia-repl
julia> using CTModels

julia> u_traj = t -> [sin(t)]
julia> cms = CTModels.ControlModelSolution("u", ["u₁"], u_traj, :constant)
julia> cms.value(π/2)
1-element Vector{Float64}:
 1.0
```
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

Used when the problem has no control variable (control dimension 0). An `EmptyControlModel`
is the default value of the `control` field in [`PreModel`](@ref): it is automatically
substituted when the user does not call `control!` before [`build`](@ref).

The methods `name`, `components`, and `dimension` are defined for this type and return
`""`, `String[]`, and `0` respectively.

# Example

```julia-repl
julia> using CTModels

julia> pre = CTModels.PreModel()
julia> CTModels.OCP.__is_control_empty(pre.control)  # true — still EmptyControlModel
true

julia> CTModels.OCP.control_dimension(pre)  # 0
0
```

See also: [`ControlModel`](@ref), [`PreModel`](@ref), [`build`](@ref).
"""
struct EmptyControlModel <: AbstractControlModel end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for optimisation variable models in optimal control problems.

Optimisation variables are decision variables that do not depend on time, such as
free final time or unknown parameters.

See also: `VariableModel`, `EmptyVariableModel`, `VariableModelSolution`.
"""
abstract type AbstractVariableModel end

"""
$(TYPEDEF)

Variable model describing the structure of the optimisation variable in an optimal
control problem definition.

# Fields

- `name::String`: Display name for the variable (e.g., `"v"`).
- `components::Vector{String}`: Names of individual variable components (e.g., `["tf", "λ"]`).

# Example

```julia-repl
julia> using CTModels

julia> vm = CTModels.VariableModel("v", ["final_time", "parameter"])
```
"""
struct VariableModel <: AbstractVariableModel
    name::String
    components::Vector{String}
end

"""
$(TYPEDEF)

Sentinel type representing the absence of optimisation variables in an optimal
control problem.

Used when the problem has no free parameters or free final time.

# Example

```julia-repl
julia> using CTModels

julia> evm = CTModels.EmptyVariableModel()
```
"""
struct EmptyVariableModel <: AbstractVariableModel end

"""
$(TYPEDEF)

Variable model for a solved optimal control problem, including the variable value.

# Fields

- `name::String`: Display name for the variable.
- `components::Vector{String}`: Names of individual variable components.
- `value::TS`: The optimisation variable value (scalar or vector).

# Example

```julia-repl
julia> using CTModels

julia> vms = CTModels.VariableModelSolution("v", ["tf"], 2.5)
julia> vms.value
2.5
```
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

Subtypes represent either fixed or free time boundaries in an optimal control
problem.

See also: `FixedTimeModel`, `FreeTimeModel`.
"""
abstract type AbstractTimeModel end

"""
$(TYPEDEF)

Time model representing a fixed (known) time boundary.

# Fields

- `time::T`: The fixed time value.
- `name::String`: Display name for this time (e.g., `"t₀"` or `"tf"`).

# Example

```julia-repl
julia> using CTModels

julia> t0 = CTModels.FixedTimeModel(0.0, "t₀")
julia> t0.time
0.0
```
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

# Example

```julia-repl
julia> using CTModels

julia> tf = CTModels.FreeTimeModel(1, "tf")
julia> tf.index
1
```
"""
struct FreeTimeModel <: AbstractTimeModel
    index::Int
    name::String
end

"""
$(TYPEDEF)

Abstract base type for combined initial and final time models.

See also: `TimesModel`.
"""
abstract type AbstractTimesModel end

"""
$(TYPEDEF)

Combined model for initial and final times in an optimal control problem.

# Fields

- `initial::TI`: The initial time model (fixed or free).
- `final::TF`: The final time model (fixed or free).
- `time_name::String`: Display name for the time variable (e.g., `"t"`).

# Example

```julia-repl
julia> using CTModels

julia> t0 = CTModels.FixedTimeModel(0.0, "t₀")
julia> tf = CTModels.FixedTimeModel(1.0, "tf")
julia> times = CTModels.TimesModel(t0, tf, "t")
```
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

Subtypes represent different forms of the cost functional: Mayer (terminal cost),
Lagrange (integral cost), or Bolza (both).

See also: `MayerObjectiveModel`, `LagrangeObjectiveModel`, `BolzaObjectiveModel`.
"""
abstract type AbstractObjectiveModel end

"""
$(TYPEDEF)

Objective model with only a Mayer (terminal) cost: `g(x(t₀), x(tf), v)`.

# Fields

- `mayer::TM`: The Mayer cost function `(x0, xf, v) -> g(x0, xf, v)`.
- `criterion::Symbol`: Optimisation direction, either `:min` or `:max`.

# Example

```julia-repl
julia> using CTModels

julia> g = (x0, xf, v) -> xf[1]^2
julia> obj = CTModels.MayerObjectiveModel(g, :min)
```
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

# Example

```julia-repl
julia> using CTModels

julia> f0 = (t, x, u, v) -> u[1]^2
julia> obj = CTModels.LagrangeObjectiveModel(f0, :min)
```
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

- `mayer::TM`: The Mayer cost function `(x0, xf, v) -> g(x0, xf, v)`.
- `lagrange::TL`: The Lagrange integrand `(t, x, u, v) -> f⁰(t, x, u, v)`.
- `criterion::Symbol`: Optimisation direction, either `:min` or `:max`.

# Example

```julia-repl
julia> using CTModels

julia> g = (x0, xf, v) -> xf[1]^2
julia> f0 = (t, x, u, v) -> u[1]^2
julia> obj = CTModels.BolzaObjectiveModel(g, f0, :min)
```
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

Subtypes store all constraint information including path constraints, boundary
constraints, and box constraints on state, control, and variables.

See also: `ConstraintsModel`.
"""
abstract type AbstractConstraintsModel end

"""
$(TYPEDEF)

Container for all constraints in an optimal control problem.

# Fields

- `path_nl::TP`: Tuple of nonlinear path constraints `(lb, f!, ub, labels)`.
- `boundary_nl::TB`: Tuple of nonlinear boundary constraints `(lb, f!, ub, labels)`.
- `state_box::TS`: Tuple of box constraints on state variables, with structure
  `(lb, ind, ub, labels, aliases)` where `labels[k]` is the first label that
  declared component `ind[k]`, and `aliases[k]` is the list of **all** labels
  that declared `ind[k]` (in declaration order). This 5-element form allows
  `constraint(model, :label)` / `dual(sol, model, :label)` to resolve labels
  merged by the per-component uniqueness invariant.
- `control_box::TC`: Tuple of box constraints on control variables (same
  `(lb, ind, ub, labels, aliases)` structure as `state_box`).
- `variable_box::TV`: Tuple of box constraints on optimisation variables (same
  `(lb, ind, ub, labels, aliases)` structure as `state_box`).

# Example

```julia-repl
julia> using CTModels

julia> # Typically constructed internally by the model builder
julia> cm = CTModels.ConstraintsModel((), (), (), (), ())
```
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

Abstract base type for the symbolic (abstract) definition attached to an
optimal control problem.

Subtypes represent either a concrete symbolic definition ([`Definition`](@ref))
or the absence of such a definition ([`EmptyDefinition`](@ref)). The
`definition` field of [`Model`](@ref CTModels.OCP.Model) and `PreModel` stores
a value of a subtype of `AbstractDefinition`.

See also: [`Definition`](@ref), [`EmptyDefinition`](@ref).
"""
abstract type AbstractDefinition end

"""
$(TYPEDEF)

Sentinel type representing the absence of a symbolic definition attached to
an optimal control problem.

Used as the default value of the `definition` field in `PreModel` and in a
built [`Model`](@ref CTModels.OCP.Model) when the user did not call
[`definition!`](@ref). When encountered, display and serialization routines
treat the definition as empty and skip the "Abstract definition" section.

# Example

```julia-repl
julia> using CTModels

julia> ed = CTModels.EmptyDefinition()
```

See also: [`AbstractDefinition`](@ref), [`Definition`](@ref).
"""
struct EmptyDefinition <: AbstractDefinition end

"""
$(TYPEDEF)

Wrapper around a Julia `Expr` holding the original symbolic definition of an
optimal control problem (typically produced by the `@def` DSL).

# Fields

- `expr::Expr`: The symbolic expression defining the problem.

# Example

```julia-repl
julia> using CTModels

julia> d = CTModels.Definition(:(x = 1))
julia> d.expr
:(x = 1)
```

See also: [`AbstractDefinition`](@ref), [`EmptyDefinition`](@ref).
"""
struct Definition <: AbstractDefinition
    expr::Expr
end
