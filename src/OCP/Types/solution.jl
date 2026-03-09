# ------------------------------------------------------------------------------ #
# Continuous-time OCP solution-related types
# (time grids, solver infos, dual variables, Solution)
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for time grid models used in optimal control solutions.

Subtypes store the discretised time points at which the solution is evaluated.

See also: `TimeGridModel`, `EmptyTimeGridModel`.
"""
abstract type AbstractTimeGridModel end

"""
$(TYPEDEF)

Unified time grid model storing a single discretised time grid for all solution components.

Used when all variables (state, control, costate, duals) share the same time grid.

# Fields

- `value::T`: Vector or range of time points (e.g., `LinRange(0, 1, 100)`).

# Example

```julia-repl
julia> using CTModels

julia> tg = CTModels.UnifiedTimeGridModel(LinRange(0, 1, 101))
julia> length(tg.value)
101
```
"""
struct UnifiedTimeGridModel{T<:TimesDisc} <: AbstractTimeGridModel
    value::T
end

"""
$(TYPEDEF)

Multiple time grid model storing different time grids for each solution component.

Used when variables have different discretisations (e.g., different grid densities for state vs control).

# Fields

- `grids::NamedTuple`: Named tuple with time grids for each component:
  - `state::TimesDisc`: State trajectory time grid
  - `control::TimesDisc`: Control trajectory time grid  
  - `costate::TimesDisc`: Costate trajectory time grid
  - `path::TimesDisc`: Path constraints and duals time grid
  - `dual::TimesDisc`: Alias for path constraints grid (same physical grid)

# Example

```julia-repl
julia> using CTModels

julia> T_state = LinRange(0, 1, 101)
julia> T_control = LinRange(0, 1, 51)
julia> tg = CTModels.MultipleTimeGridModel(
    state=T_state, control=T_control, costate=T_state, path=T_state, dual=T_state
)
julia> length(tg.grids.state)
101
```
"""
struct MultipleTimeGridModel <: AbstractTimeGridModel
    grids::NamedTuple{
        (:state, :control, :costate, :path, :dual),
        Tuple{TimesDisc,TimesDisc,TimesDisc,TimesDisc,TimesDisc},
    }
end

"""
$(TYPEDSIGNATURES)

Construct a `MultipleTimeGridModel` with keyword arguments for each component time grid.

# Arguments
- `state`: Time grid for state variables
- `control`: Time grid for control variables  
- `costate`: Time grid for costate variables
- `path`: Time grid for path constraints
- `dual`: Time grid for dual variables

# Returns
- `MultipleTimeGridModel`: A model containing all component time grids

# Example
```julia-repl
julia> T_state = LinRange(0, 1, 101)
julia> T_control = LinRange(0, 1, 51)
julia> mtgm = MultipleTimeGridModel(
    state=T_state, 
    control=T_control, 
    costate=T_state, 
    path=T_state, 
    dual=T_state
)
```
"""
function MultipleTimeGridModel(;
    state::TimesDisc,
    control::TimesDisc,
    costate::TimesDisc,
    path::TimesDisc,
    dual::TimesDisc,
)
    return MultipleTimeGridModel((
        state=state, control=control, costate=costate, path=path, dual=dual
    ))
end

# Legacy alias for backward compatibility
const TimeGridModel = UnifiedTimeGridModel

"""
$(TYPEDSIGNATURES)

Clean and standardize component symbols for time grid access.

# Behavior
- Converts plural forms (`:states`, `:costates`, etc.) to their singular equivalents.
- Maps ambiguous terms (`:constraint`, `:constraints`, `:cons`) to `:path`.
- Removes duplicate symbols.

# Arguments
- `description`: A tuple of symbols passed by the user, typically from time grid access.

# Returns
- A cleaned `Tuple{Symbol...}` of unique, standardized symbols.

# Example
```julia-repl
julia> clean_component_symbols((:states, :controls, :costate, :constraint, :duals))
# → (:state, :control, :costate, :path, :dual)
```
"""
function clean_component_symbols(description)
    # remove the nouns in plural form
    description = replace(
        description,
        :states => :state,
        :costates => :costate,
        :controls => :control,
        :constraints => :path,
        :constraint => :path,
        :cons => :path,
        :duals => :dual,
    )
    # remove the duplicates while preserving order
    seen = Set{Symbol}()
    result = Symbol[]
    for comp in description
        if comp ∉ seen
            push!(seen, comp)
            push!(result, comp)
        end
    end
    return tuple(result...)
end

"""
$(TYPEDEF)

Sentinel type representing an empty or uninitialised time grid.

Used when a solution does not yet have an associated time discretisation.

# Example

```julia-repl
julia> using CTModels

julia> etg = CTModels.EmptyTimeGridModel()
```
"""
struct EmptyTimeGridModel <: AbstractTimeGridModel end

"""
$(TYPEDSIGNATURES)

Return `true` if the time grid model is empty.

# Arguments
- `model::EmptyTimeGridModel`: An empty time grid model

# Returns
- `Bool`: Always `true` for empty time grid models

# Example
```julia-repl
julia> etg = CTModels.EmptyTimeGridModel()
julia> CTModels.is_empty(etg)
true
```
"""
is_empty(model::EmptyTimeGridModel)::Bool = true

"""
$(TYPEDSIGNATURES)

Return `false` for non-empty time grid models.

# Arguments
- `model::AbstractTimeGridModel`: Any non-empty time grid model

# Returns
- `Bool`: Always `false` for non-empty time grid models

# Example
```julia-repl
julia> T = LinRange(0, 1, 101)
julia> utg = CTModels.UnifiedTimeGridModel(T)
julia> CTModels.is_empty(utg)
false
```
"""
is_empty(model::AbstractTimeGridModel)::Bool = false

# ------------------------------------------------------------------------------ #
# Solver infos
"""
$(TYPEDEF)

Abstract base type for solver information associated with an optimal control solution.

Subtypes store metadata about the numerical solution process.

See also: `SolverInfos`.
"""
abstract type AbstractSolverInfos end

"""
$(TYPEDEF)

Solver information and statistics from the numerical solution process.

# Fields

- `iterations::Int`: Number of iterations performed by the solver.
- `status::Symbol`: Termination status (e.g., `:first_order`, `:max_iter`).
- `message::String`: Human-readable message describing the termination status.
- `successful::Bool`: Whether the solver converged successfully.
- `constraints_violation::Float64`: Maximum constraint violation at the solution.
- `infos::TI`: Dictionary of additional solver-specific information.

# Example

```julia-repl
julia> using CTModels

julia> si = CTModels.SolverInfos(100, :first_order, "Converged", true, 1e-8, Dict{Symbol,Any}())
julia> si.successful
true
```
"""
struct SolverInfos{V,TI<:Dict{Symbol,V}} <: AbstractSolverInfos
    iterations::Int
    status::Symbol
    message::String
    successful::Bool
    constraints_violation::Float64
    infos::TI
end

# ------------------------------------------------------------------------------ #
# Constraints and dual variables for the solutions
"""
$(TYPEDEF)

Abstract base type for dual variable models in optimal control solutions.

Subtypes store Lagrange multipliers (dual variables) associated with constraints.

See also: `DualModel`.
"""
abstract type AbstractDualModel end

"""
$(TYPEDEF)

Dual variables (Lagrange multipliers) for all constraints in an optimal control solution.

# Fields

- `path_constraints_dual::PC_Dual`: Multipliers for path constraints `t -> μ(t)`, or `nothing`.
- `boundary_constraints_dual::BC_Dual`: Multipliers for boundary constraints (vector), or `nothing`.
- `state_constraints_lb_dual::SC_LB_Dual`: Multipliers for state lower bounds `t -> ν⁻(t)`, or `nothing`.
- `state_constraints_ub_dual::SC_UB_Dual`: Multipliers for state upper bounds `t -> ν⁺(t)`, or `nothing`.
- `control_constraints_lb_dual::CC_LB_Dual`: Multipliers for control lower bounds `t -> ω⁻(t)`, or `nothing`.
- `control_constraints_ub_dual::CC_UB_Dual`: Multipliers for control upper bounds `t -> ω⁺(t)`, or `nothing`.
- `variable_constraints_lb_dual::VC_LB_Dual`: Multipliers for variable lower bounds (vector), or `nothing`.
- `variable_constraints_ub_dual::VC_UB_Dual`: Multipliers for variable upper bounds (vector), or `nothing`.

# Example

```julia-repl
julia> using CTModels

julia> # Typically constructed internally by the solver
julia> dm = CTModels.DualModel(nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
```
"""
struct DualModel{
    PC_Dual<:Union{Function,Nothing},
    BC_Dual<:Union{ctVector,Nothing},
    SC_LB_Dual<:Union{Function,Nothing},
    SC_UB_Dual<:Union{Function,Nothing},
    CC_LB_Dual<:Union{Function,Nothing},
    CC_UB_Dual<:Union{Function,Nothing},
    VC_LB_Dual<:Union{ctVector,Nothing},
    VC_UB_Dual<:Union{ctVector,Nothing},
} <: AbstractDualModel
    path_constraints_dual::PC_Dual
    boundary_constraints_dual::BC_Dual
    state_constraints_lb_dual::SC_LB_Dual
    state_constraints_ub_dual::SC_UB_Dual
    control_constraints_lb_dual::CC_LB_Dual
    control_constraints_ub_dual::CC_UB_Dual
    variable_constraints_lb_dual::VC_LB_Dual
    variable_constraints_ub_dual::VC_UB_Dual
end

# ------------------------------------------------------------------------------ #
# Solution
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for optimal control problem solutions.

Subtypes store the complete solution including primal trajectories, dual variables,
and solver information.

See also: `Solution`.
"""
abstract type AbstractSolution end

"""
$(TYPEDEF)

Complete solution of an optimal control problem.

Stores the optimal state, control, and costate trajectories, the optimisation
variable value, objective value, dual variables, and solver information.

# Fields

- `time_grid::TimeGridModelType`: Discretised time points.
- `times::TimesModelType`: Initial and final time specification.
- `state::StateModelType`: State trajectory `t -> x(t)` with metadata.
- `control::ControlModelType`: Control trajectory `t -> u(t)` with metadata.
- `variable::VariableModelType`: Optimisation variable value with metadata.
- `model::ModelType`: Reference to the optimal control problem model.
- `costate::CostateModelType`: Costate (adjoint) trajectory `t -> p(t)`.
- `objective::ObjectiveValueType`: Optimal objective value.
- `dual::DualModelType`: Dual variables for all constraints.
- `solver_infos::SolverInfosType`: Solver statistics and status.

# Example

```julia-repl
julia> using CTModels

julia> # Solutions are typically returned by solvers
julia> sol = solve(ocp, ...)  # Returns a Solution
julia> CTModels.objective(sol)
```
"""
struct Solution{
    TimeGridModelType<:AbstractTimeGridModel,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    ModelType<:AbstractModel,
    CostateModelType<:Function,
    ObjectiveValueType<:ctNumber,
    DualModelType<:AbstractDualModel,
    SolverInfosType<:AbstractSolverInfos,
} <: AbstractSolution
    time_grid::TimeGridModelType
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    model::ModelType
    costate::CostateModelType
    objective::ObjectiveValueType
    dual::DualModelType
    solver_infos::SolverInfosType
end

"""
$(TYPEDSIGNATURES)

Check if the time grid is empty from the solution.
"""
is_empty_time_grid(sol::Solution)::Bool = is_empty(time_grid_model(sol))

"""
$(TYPEDSIGNATURES)

Get the time grid model from a solution.

# Returns
- `AbstractTimeGridModel`: The time grid model (UnifiedTimeGridModel or MultipleTimeGridModel)
"""
time_grid_model(sol::Solution)::AbstractTimeGridModel = sol.time_grid
