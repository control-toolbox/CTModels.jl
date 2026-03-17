"""
$(TYPEDSIGNATURES)

Build a solution from an optimal control problem with independent time grids for each component.

This function constructs a `Solution` object by assembling trajectory data (state, control, costate, 
path constraint duals) defined on potentially different time discretizations. The solution automatically 
creates interpolated functions to evaluate trajectories at arbitrary time points, and optimizes storage 
when all grids are identical.

# Time Grid Semantics

The solution supports **four independent time grids**, each associated with a specific trajectory component:

- **`T_state`**: Time grid for the state trajectory `X` and state box constraint duals
  - Defines discretization points where state values are known
  - State box constraint duals (`state_constraints_lb_dual`, `state_constraints_ub_dual`) share this grid
  
- **`T_control`**: Time grid for the control trajectory `U` and control box constraint duals
  - Defines discretization points where control values are known
  - Control box constraint duals (`control_constraints_lb_dual`, `control_constraints_ub_dual`) share this grid
  - May differ from `T_state` (e.g., coarser discretization for piecewise constant controls)
  
- **`T_costate`**: Time grid for the costate (adjoint) trajectory `P`
  - Defines discretization points where costate values are known
  - Independent from state grid to accommodate different numerical schemes
  - Example: symplectic integrators may use different grids for state and costate
  
- **`T_path`**: Time grid for path constraint duals (can be `nothing`)
  - Defines discretization points for path constraint dual variables
  - Set to `nothing` if no path constraints exist
  - When `nothing`, internally defaults to `T_state` for consistency

**Grid Optimization**: If all non-nothing grids are identical, the solution uses `UnifiedTimeGridModel` 
for memory efficiency. Otherwise, it uses `MultipleTimeGridModel` to store each grid separately.

# Trajectory Data Formats

Trajectory data (`X`, `U`, `P`, `path_constraints_dual`) can be provided in two formats:

1. **Matrix format**: `Matrix{Float64}` with dimensions `(n_points, n_dim)`
   - Each row corresponds to a time point in the associated grid
   - Each column corresponds to a component dimension
   - Example: `X` is `(length(T_state), state_dimension(ocp))`

2. **Function format**: `Function` that takes time `t::Float64` and returns a vector
   - Allows analytical or pre-interpolated trajectories
   - Function signature: `t -> Vector{Float64}` of appropriate dimension
   - Useful for exact solutions or when data is already interpolated

# Arguments

## Required Positional Arguments

- `ocp::Model`: The optimal control problem model defining dimensions and structure
- `T_state::Vector{Float64}`: Time grid for state trajectory (must be strictly increasing)
- `T_control::Vector{Float64}`: Time grid for control trajectory (must be strictly increasing)
- `T_costate::Vector{Float64}`: Time grid for costate trajectory (must be strictly increasing)
- `T_path::Union{Vector{Float64},Nothing}`: Time grid for path constraint duals (or `nothing`)
- `X::Union{Matrix{Float64},Function}`: State trajectory data
- `U::Union{Matrix{Float64},Function}`: Control trajectory data
- `v::Vector{Float64}`: Variable values (static optimization variables, not time-dependent)
- `P::Union{Matrix{Float64},Function}`: Costate (adjoint) trajectory data

## Required Keyword Arguments

- `objective::Float64`: Optimal objective function value
- `iterations::Int`: Number of solver iterations performed
- `constraints_violation::Float64`: Maximum constraint violation (feasibility measure)
- `message::String`: Solver status message (e.g., "Solve_Succeeded", "Iteration_Limit")
- `status::Symbol`: Solver termination status (e.g., `:Solve_Succeeded`, `:Iteration_Limit`)
- `successful::Bool`: Whether the solve was successful (true/false)

## Optional Keyword Arguments (Dual Variables)

All dual variable arguments default to `nothing` if not provided:

- `path_constraints_dual::Union{Matrix{Float64},Function,Nothing}`: Path constraint duals on `T_path` grid
- `boundary_constraints_dual::Union{Vector{Float64},Nothing}`: Boundary constraint duals (time-independent)
- `state_constraints_lb_dual::Union{Matrix{Float64},Nothing}`: State lower bound duals on `T_state` grid
- `state_constraints_ub_dual::Union{Matrix{Float64},Nothing}`: State upper bound duals on `T_state` grid
- `control_constraints_lb_dual::Union{Matrix{Float64},Nothing}`: Control lower bound duals on `T_control` grid
- `control_constraints_ub_dual::Union{Matrix{Float64},Nothing}`: Control upper bound duals on `T_control` grid
- `variable_constraints_lb_dual::Union{Vector{Float64},Nothing}`: Variable lower bound duals (time-independent)
- `variable_constraints_ub_dual::Union{Vector{Float64},Nothing}`: Variable upper bound duals (time-independent)
- `infos::Dict{Symbol,Any}`: Additional solver-specific information (default: empty dict)

# Returns

- `sol::Solution`: Complete solution object with interpolated trajectory functions and metadata

# Example

```julia
using CTModels

# Build OCP
ocp = Model(...)
state!(ocp, 2)
control!(ocp, 1)
# ... define dynamics, objective, etc.

# Define independent time grids
T_state = collect(LinRange(0.0, 1.0, 101))    # Fine state grid (101 points)
T_control = collect(LinRange(0.0, 1.0, 51))   # Coarser control grid (51 points)
T_costate = collect(LinRange(0.0, 1.0, 76))   # Custom costate grid (76 points)
T_path = collect(LinRange(0.0, 1.0, 61))      # Path constraint grid (61 points)

# Trajectory data (matrix format)
X = rand(101, 2)  # State on T_state grid
U = rand(51, 1)   # Control on T_control grid
P = rand(76, 2)   # Costate on T_costate grid
v = [0.5, 1.2]    # Static variables

# Build solution
sol = build_solution(
    ocp,
    T_state, T_control, T_costate, T_path,
    X, U, v, P;
    objective=1.23,
    iterations=50,
    constraints_violation=1e-8,
    message="Optimal",
    status=:first_order,
    successful=true
)

# Access trajectories (automatically interpolated)
x_at_t = state(sol)(0.5)      # Interpolated from T_state grid
u_at_t = control(sol)(0.5)    # Interpolated from T_control grid
p_at_t = costate(sol)(0.5)    # Interpolated from T_costate grid

# Query time grids
time_grid(sol, :state)    # Returns T_state
time_grid(sol, :control)  # Returns T_control
time_grid(sol, :costate)  # Returns T_costate
```

# Notes

## Box Constraint Dual Dimensions

The dimensions of box constraint dual variables correspond to the **component dimension**, not the 
number of constraint declarations:

- `state_constraints_*_dual`: Dimension `(length(T_state), state_dimension(ocp))`
- `control_constraints_*_dual`: Dimension `(length(T_control), control_dimension(ocp))`
- `variable_constraints_*_dual`: Dimension `variable_dimension(ocp)`

If multiple constraints are declared on the same component (e.g., `x₂(t) ≤ 1.2` and `x₂(t) ≤ 2.0`), 
only the last bound value is retained, and a warning is emitted during model construction.

## Grid Validation

All time grids must be:
- Strictly increasing: `T[i] < T[i+1]` for all `i`
- Non-empty: At least one time point
- Finite: No `Inf` or `NaN` values

The function automatically validates and fixes grids (e.g., converts ranges to vectors).

## Memory Optimization

When all grids are identical, the solution uses `UnifiedTimeGridModel` to store a single grid, 
reducing memory overhead. This is detected automatically.

## Backward Compatibility

A legacy signature `build_solution(ocp, T, X, U, v, P; ...)` exists for single-grid solutions. 
It internally calls this multi-grid version with `T_state = T_control = T_costate = T_path = T`.

See also: `Solution`, `UnifiedTimeGridModel`, `MultipleTimeGridModel`, 
`time_grid`, `state`, `control`, `costate`
"""
function build_solution(
    ocp::Model,
    T_state::Vector{Float64},
    T_control::Vector{Float64},
    T_costate::Vector{Float64},
    T_path::Union{Vector{Float64},Nothing},
    X::TX,
    U::TU,
    v::Vector{Float64},
    P::TP;
    objective::Float64,
    iterations::Int,
    constraints_violation::Float64,
    message::String,
    status::Symbol,
    successful::Bool,
    path_constraints_dual::TPCD=__constraints(),
    boundary_constraints_dual::Union{Vector{Float64},Nothing}=__constraints(),
    state_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    state_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    variable_constraints_lb_dual::Union{Vector{Float64},Nothing}=__constraints(),
    variable_constraints_ub_dual::Union{Vector{Float64},Nothing}=__constraints(),
    infos::Dict{Symbol,Any}=Dict{Symbol,Any}(),
    control_interpolation::Symbol=__control_interpolation(),
) where {
    TX<:Union{Matrix{Float64},Function},
    TU<:Union{Matrix{Float64},Function},
    TP<:Union{Matrix{Float64},Function},
    TPCD<:Union{Matrix{Float64},Function,Nothing},
}

    # Validate control_interpolation
    if control_interpolation ∉ (:constant, :linear)
        throw(
            Exceptions.IncorrectArgument(
                "Invalid control_interpolation";
                got="control_interpolation=$control_interpolation",
                expected=":constant or :linear",
                suggestion="Use :constant for piecewise constant (direct methods) or :linear for piecewise linear (indirect methods)",
                context="build_solution parameter",
            ),
        )
    end

    # get dimensions
    dim_x = state_dimension(ocp)
    dim_u = control_dimension(ocp)
    dim_v = variable_dimension(ocp)

    # Validate and fix time grids
    T_state = _validate_and_fix_time_grid(T_state, "state")
    T_control = _validate_and_fix_time_grid(T_control, "control")
    T_costate = _validate_and_fix_time_grid(T_costate, "costate")
    T_path = isnothing(T_path) ? nothing : _validate_and_fix_time_grid(T_path, "path")

    # Detect if all non-nothing grids are identical
    non_nothing_grids = filter(g -> !isnothing(g), [T_state, T_control, T_costate, T_path])
    all_identical =
        length(non_nothing_grids) <= 1 ||
        all(g -> g == first(non_nothing_grids), non_nothing_grids)

    # Create appropriate time grid model
    time_grid = if all_identical
        UnifiedTimeGridModel(first(non_nothing_grids))
    else
        # For path grid, use T_state if T_path is nothing (path constraints share state grid)
        T_path_safe = isnothing(T_path) ? T_state : T_path
        MultipleTimeGridModel(;
            state=T_state, control=T_control, costate=T_costate, path=T_path_safe
        )
    end

    # Build interpolated functions for state, control, and costate
    # Using unified API with validation and deepcopy+scalar wrapping
    # Note: costate uses its own grid (T_costate)
    # Note: control uses configurable interpolation (constant for direct methods, linear for indirect methods)
    fx = build_interpolated_function(X, T_state, dim_x, TX; expected_dim=dim_x)
    fu = build_interpolated_function(U, T_control, dim_u, TU; expected_dim=dim_u, interpolation=control_interpolation)
    fp = build_interpolated_function(
        P, T_costate, dim_x, TP; constant_if_two_points=true, expected_dim=dim_x
    )
    var = (dim_v == 1) ? v[1] : v

    # nonlinear constraints and dual variables (optional, can be nothing)
    # Note: dim is set to dim_path_constraints_nl for proper scalar wrapping
    # Path constraints duals share the path grid (T_path)
    fpcd = build_interpolated_function(
        path_constraints_dual,
        T_path,
        dim_path_constraints_nl(ocp),
        TPCD;
        allow_nothing=true,
    )

    # box constraints multipliers (optional, can be nothing)
    # Note: No expected_dim validation for box constraints because they use
    # dim_*_constraints_box which may differ from state/control dimensions
    # State box constraint duals share the state grid (T_state)
    fscbd = build_interpolated_function(
        state_constraints_lb_dual,
        T_state,
        dim_state_constraints_box(ocp),
        Union{Matrix{Float64},Nothing};
        allow_nothing=true,
    )
    fscud = build_interpolated_function(
        state_constraints_ub_dual,
        T_state,
        dim_state_constraints_box(ocp),
        Union{Matrix{Float64},Nothing};
        allow_nothing=true,
    )
    # Control box constraint duals share the control grid (T_control)
    # Note: use same interpolation as control
    fccbd = build_interpolated_function(
        control_constraints_lb_dual,
        T_control,
        dim_control_constraints_box(ocp),
        Union{Matrix{Float64},Nothing};
        allow_nothing=true,
        interpolation=control_interpolation,
    )
    fccud = build_interpolated_function(
        control_constraints_ub_dual,
        T_control,
        dim_control_constraints_box(ocp),
        Union{Matrix{Float64},Nothing};
        allow_nothing=true,
        interpolation=control_interpolation,
    )

    # build Models
    state = StateModelSolution(state_name(ocp), state_components(ocp), fx)
    control = ControlModelSolution(control_name(ocp), control_components(ocp), fu, control_interpolation)
    variable = VariableModelSolution(variable_name(ocp), variable_components(ocp), var)
    dual = DualModel(
        fpcd,
        boundary_constraints_dual,
        fscbd,
        fscud,
        fccbd,
        fccud,
        variable_constraints_lb_dual,
        variable_constraints_ub_dual,
    )

    solver_infos = SolverInfos(
        iterations, status, message, successful, constraints_violation, infos
    )

    return Solution(
        time_grid,
        times(ocp),
        state,
        control,
        variable,
        ocp,
        fp,
        objective,
        dual,
        solver_infos,
    )
end

"""
$(TYPEDSIGNATURES)

Validate and fix a time grid by ensuring it is strictly increasing.

# Arguments
- `T::Vector{Float64}`: Time grid to validate
- `component_name::String`: Name of the component for error messages

# Returns
- `Vector{Float64}`: Validated and potentially reordered time grid

# Notes
If the grid is not strictly increasing, it is reordered and a warning is emitted.
"""
function _validate_and_fix_time_grid(T::Vector{Float64}, component_name::String)
    if !issorted(T; lt=<)
        # Build appropriate message based on component name
        components_with_issues = [component_name]  # TODO: Collect all components when called multiple times

        if length(components_with_issues) == 1
            msg = "The time grid for $(components_with_issues[1]) is not increasing. It is reordered."
        else
            msg = "The time grids for $(join(components_with_issues, ", ")) are not increasing. They are reordered."
        end

        @warn msg
        return sort(T)
    end
    return T
end

"""
$(TYPEDSIGNATURES)

Build a solution from the optimal control problem, the time grid, the state, control, variable, and dual variables.

# Arguments

- `ocp::Model`: the optimal control problem.
- `T::Vector{Float64}`: the time grid.
- `X::Matrix{Float64}`: the state trajectory.
- `U::Matrix{Float64}`: the control trajectory.
- `v::Vector{Float64}`: the variable trajectory.
- `P::Matrix{Float64}`: the costate trajectory.
- `objective::Float64`: the objective value.
- `iterations::Int`: the number of iterations.
- `constraints_violation::Float64`: the constraints violation.
- `message::String`: the message associated to the status criterion.
- `status::Symbol`: the status criterion.
- `successful::Bool`: the successful status.
- `path_constraints_dual::Matrix{Float64}`: the dual of the path constraints.
- `boundary_constraints_dual::Vector{Float64}`: the dual of the boundary constraints.
- `state_constraints_lb_dual::Matrix{Float64}`: the lower bound dual of the state constraints.
- `state_constraints_ub_dual::Matrix{Float64}`: the upper bound dual of the state constraints.
- `control_constraints_lb_dual::Matrix{Float64}`: the lower bound dual of the control constraints.
- `control_constraints_ub_dual::Matrix{Float64}`: the upper bound dual of the control constraints.
- `variable_constraints_lb_dual::Vector{Float64}`: the lower bound dual of the variable constraints.
- `variable_constraints_ub_dual::Vector{Float64}`: the upper bound dual of the variable constraints.
- `infos::Dict{Symbol,Any}`: additional solver information dictionary.

# Returns

- `sol::Solution`: the optimal control solution.

# Notes

The dimensions of box constraint dual variables (`state_constraints_*_dual`, `control_constraints_*_dual`, 
`variable_constraints_*_dual`) correspond to the **state/control/variable dimension**, not the number of 
constraint declarations. If multiple constraints are declared on the same component (e.g., `x₂(t) ≤ 1.2` 
and `x₂(t) ≤ 2.0`), only the last bound value is retained, and a warning is emitted during model construction.

"""
function build_solution(
    ocp::Model,
    T::Vector{Float64},
    X::TX,
    U::TU,
    v::Vector{Float64},
    P::TP;
    objective::Float64,
    iterations::Int,
    constraints_violation::Float64,
    message::String,
    status::Symbol,
    successful::Bool,
    path_constraints_dual::TPCD=__constraints(),
    boundary_constraints_dual::Union{Vector{Float64},Nothing}=__constraints(),
    state_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    state_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    variable_constraints_lb_dual::Union{Vector{Float64},Nothing}=__constraints(),
    variable_constraints_ub_dual::Union{Vector{Float64},Nothing}=__constraints(),
    infos::Dict{Symbol,Any}=Dict{Symbol,Any}(),
    control_interpolation::Symbol=__control_interpolation(),
) where {
    TX<:Union{Matrix{Float64},Function},
    TU<:Union{Matrix{Float64},Function},
    TP<:Union{Matrix{Float64},Function},
    TPCD<:Union{Matrix{Float64},Function,Nothing},
}
    # Legacy compatibility: call new multi-grid method with same grid for all components
    return build_solution(
        ocp,
        T,
        T,
        T,
        T,
        X,
        U,
        v,
        P;
        objective=objective,
        iterations=iterations,
        constraints_violation=constraints_violation,
        message=message,
        status=status,
        successful=successful,
        path_constraints_dual=path_constraints_dual,
        boundary_constraints_dual=boundary_constraints_dual,
        state_constraints_lb_dual=state_constraints_lb_dual,
        state_constraints_ub_dual=state_constraints_ub_dual,
        control_constraints_lb_dual=control_constraints_lb_dual,
        control_constraints_ub_dual=control_constraints_ub_dual,
        variable_constraints_lb_dual=variable_constraints_lb_dual,
        variable_constraints_ub_dual=variable_constraints_ub_dual,
        infos=infos,
        control_interpolation=control_interpolation,
    )
end

# ------------------------------------------------------------------------------ #
# Getters
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Return the dimension of the state.

"""
function state_dimension(sol::Solution)::Dimension
    return dimension(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the state.

"""
function state_components(sol::Solution)::Vector{String}
    return components(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the name of the state.

"""
function state_name(sol::Solution)::String
    return name(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the state as a function of time.

```@example
julia> x  = state(sol)
julia> t0 = time_grid(sol)[1]
julia> x0 = x(t0) # state at the initial time
```
"""
function state(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:StateModelSolution{TS},
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TS where {TS<:Function}
    return value(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the control.

"""
function control_dimension(sol::Solution)::Dimension
    return dimension(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the control.

"""
function control_components(sol::Solution)::Vector{String}
    return components(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the name of the control.

"""
function control_name(sol::Solution)::String
    return name(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the interpolation type of the control.

# Returns
- `Symbol`: The interpolation type (`:constant` or `:linear`).
"""
function control_interpolation(sol::Solution)::Symbol
    return interpolation(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the control as a function of time.

```@example
julia> u  = control(sol)
julia> t0 = time_grid(sol)[1]
julia> u0 = u(t0) # control at the initial time
```
"""
function control(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:ControlModelSolution{TS},
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TS where {TS<:Function}
    return value(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the variable.

"""
function variable_dimension(sol::Solution)::Dimension
    return dimension(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.

"""
function variable_components(sol::Solution)::Vector{String}
    return components(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the name of the variable.

"""
function variable_name(sol::Solution)::String
    return name(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.

"""
function dim_boundary_constraints_nl(sol::Solution)::Dimension
    bc_dual = boundary_constraints_dual(sol)
    return bc_dual === nothing ? 0 : length(bc_dual)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the path constraints.

"""
function dim_path_constraints_nl(sol::Solution)::Dimension
    pc_dual = path_constraints_dual(sol)
    if pc_dual === nothing
        return 0
    else
        t0 = initial_time(sol)
        return length(pc_dual(t0))
    end
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the variable box constraints.

"""
function dim_variable_constraints_box(sol::Solution)::Dimension
    vc_lb_dual = variable_constraints_lb_dual(sol)
    return vc_lb_dual === nothing ? 0 : length(vc_lb_dual)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.

"""
function dim_state_constraints_box(sol::Solution)::Dimension
    sc_lb_dual = state_constraints_lb_dual(sol)
    return sc_lb_dual === nothing ? 0 : state_dimension(sol)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.

"""
function dim_control_constraints_box(sol::Solution)::Dimension
    cc_lb_dual = control_constraints_lb_dual(sol)
    return cc_lb_dual === nothing ? 0 : control_dimension(sol)
end

"""
$(TYPEDSIGNATURES)

Return the variable or `nothing`.

```@example
julia> v  = variable(sol)
```
"""
function variable(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:VariableModelSolution{TS},
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TS where {TS<:Union{ctNumber,ctVector}}
    return value(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the costate as a function of time.

```@example
julia> p  = costate(sol)
julia> t0 = time_grid(sol)[1]
julia> p0 = p(t0) # costate at the initial time
```
"""
function costate(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        Co,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::Co where {Co<:Function}
    return sol.costate
end

"""
$(TYPEDSIGNATURES)

Return the name of the initial time.

"""
function initial_time_name(sol::Solution)::String
    return name(initial(sol.times))
end

"""
$(TYPEDSIGNATURES)

Return the name of the final time.

"""
function final_time_name(sol::Solution)::String
    return name(final(sol.times))
end

"""
$(TYPEDSIGNATURES)

Return the name of the time component.

"""
function time_name(sol::Solution)::String
    return time_name(sol.times)
end

# Initial time
"""
$(TYPEDSIGNATURES)

Return the initial time of the solution.
"""
function initial_time(sol::Solution)::Real
    return initial_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Return the final time of the solution.
"""
function final_time(sol::Solution)::Real
    return final_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed.
"""
function has_fixed_initial_time(sol::Solution)::Bool
    return has_fixed_initial_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free.
"""
function has_free_initial_time(sol::Solution)::Bool
    return has_free_initial_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed.
"""
function has_fixed_final_time(sol::Solution)::Bool
    return has_fixed_final_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_final_time(sol::Solution)::Bool
    return has_free_final_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Return the times model.

"""
function times(
    sol::Solution{
        <:AbstractTimeGridModel,
        TM,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TM where {TM<:AbstractTimesModel}
    return sol.times
end

"""
$(TYPEDSIGNATURES)

Return the time grid for solutions with unified time grid.

"""
function time_grid(
    sol::Solution{
        <:UnifiedTimeGridModel{T},
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::T where {T<:TimesDisc}
    return sol.time_grid.value
end

"""
$(TYPEDSIGNATURES)

Return the time grid for a specific component.

# Arguments
- `sol::Solution`: The solution (unified or multiple time grids)
- `component::Symbol`: The component (:state, :control, :path)
  Also accepted: :costate/:costates (→ :state), :dual/:duals (→ :path),
  :state_box_constraint(s) (→ :state), :control_box_constraint(s) (→ :control),
  plural forms (:states, :controls)

# Returns
- `TimesDisc`: The time grid for the specified component

# Behavior
- For `UnifiedTimeGridModel`: Returns the unique time grid for any component
- For `MultipleTimeGridModel`: Returns the specific time grid for the component

# Throws
- `IncorrectArgument`: If component is not one of the valid symbols

# Examples
```julia-repl
julia> time_grid(sol, :state)   # Works for both unified and multiple grids
julia> time_grid(sol, :control) # Works for both unified and multiple grids
julia> time_grid(sol, :costate) # Maps to :state grid
julia> time_grid(sol, :dual)    # Maps to :path grid
```
"""
function time_grid(
    sol::Solution{
        <:UnifiedTimeGridModel{T},
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
    component::Symbol,
)::T where {T<:TimesDisc}
    # Clean and validate component symbol
    component_clean = clean_component_symbols((component,))[1]

    # Validate component
    if component_clean ∉ (:state, :control, :costate, :path)
        # ⚠️ Applying Exception Rule: Invalid component symbol
        throw(
            CTBase.Exceptions.IncorrectArgument(
                "Invalid component for time grid access";
                got=string(component),
                expected="one of :state, :control, :costate, :path (or aliases like :dual, plural forms)",
                suggestion="Use time_grid(sol, :state) or another valid component",
                context="time_grid for UnifiedTimeGridModel",
            ),
        )
    end

    # For unified time grid, return the unique grid regardless of component
    return sol.time_grid.value
end

"""
$(TYPEDSIGNATURES)

Return the time grid for a specific component in solutions with multiple time grids.

# Arguments
- `sol::Solution`: The solution with multiple time grids
- `component::Symbol`: The component (:state, :control, :path)
  Also accepted: :costate/:costates (→ :state), :dual/:duals (→ :path),
  :state_box_constraint(s) (→ :state), :control_box_constraint(s) (→ :control),
  plural forms (:states, :controls)

# Returns
- `TimesDisc`: The time grid for the specified component

# Throws
- `IncorrectArgument`: If component is not one of the valid symbols

# Examples
```julia-repl
julia> time_grid(sol, :state)   # Get state time grid
julia> time_grid(sol, :control) # Get control time grid
julia> time_grid(sol, :costate) # Maps to state time grid
julia> time_grid(sol, :dual)    # Maps to path time grid
```
"""
function time_grid(
    sol::Solution{
        <:MultipleTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
    component::Symbol,
)::TimesDisc
    # Clean and validate component symbol
    component_clean = clean_component_symbols((component,))[1]

    # Validate component
    if component_clean ∉ (:state, :control, :costate, :path)
        # ⚠️ Applying Exception Rule: Invalid component symbol
        throw(
            CTBase.Exceptions.IncorrectArgument(
                "Invalid component for time grid access";
                got=string(component),
                expected="one of :state, :control, :costate, :path (or aliases like :dual, plural forms)",
                suggestion="Use time_grid(sol, :state) or another valid component",
                context="time_grid for MultipleTimeGridModel",
            ),
        )
    end

    # Return the appropriate grid
    return getfield(sol.time_grid.grids, component_clean)
end

"""
$(TYPEDSIGNATURES)

Return the time grid for solutions with multiple time grids (component must be specified).

# Throws
- `IncorrectArgument`: Always thrown for MultipleTimeGridModel without component specification

# Notes
This method enforces explicit component specification for solutions with multiple time grids
to avoid ambiguity about which grid is being accessed.

# Examples
```julia-repl
julia> time_grid(sol)  # ❌ Error for MultipleTimeGridModel
julia> time_grid(sol, :state)  # ✅ Correct usage
```
"""
function time_grid(
    sol::Solution{
        <:MultipleTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)
    # ⚠️ Applying Exception Rule: Missing component specification
    throw(
        CTBase.Exceptions.IncorrectArgument(
            "Component must be specified for solutions with multiple time grids";
            got="no component specified",
            expected="time_grid(sol, :component) where component ∈ {:state, :control, :path}",
            suggestion="Specify which time grid to access, e.g., time_grid(sol, :state)",
            context="time_grid for MultipleTimeGridModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the objective value.

"""
function objective(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        O,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::O where {O<:ctNumber}
    return sol.objective
end

"""
$(TYPEDSIGNATURES)

Return the number of iterations (if solved by an iterative method).

"""
function iterations(sol::Solution)::Int
    return sol.solver_infos.iterations
end

"""
$(TYPEDSIGNATURES)

Return the status criterion (a Symbol).

"""
function status(sol::Solution)::Symbol
    return sol.solver_infos.status
end

"""
$(TYPEDSIGNATURES)

Return the message associated to the status criterion.

"""
function message(sol::Solution)::String
    return sol.solver_infos.message
end

"""
$(TYPEDSIGNATURES)

Return the successful status.

"""
function successful(sol::Solution)::Bool
    return sol.solver_infos.successful
end

"""
$(TYPEDSIGNATURES)

Return the constraints violation.

"""
function constraints_violation(sol::Solution)::Float64
    return sol.solver_infos.constraints_violation
end

"""
$(TYPEDSIGNATURES)

Return a dictionary of additional infos depending on the solver or `nothing`.

"""
function infos(sol::Solution)::Dict{Symbol,Any}
    return sol.solver_infos.infos
end

"""
$(TYPEDSIGNATURES)

Return the model of the optimal control problem.
"""
function model(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        M,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::M where {M<:AbstractModel}
    return sol.model
end

"""
$(TYPEDSIGNATURES)

Return the dual model containing all constraint multipliers.
"""
function dual_model(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        DM,
        <:AbstractSolverInfos,
    },
)::DM where {DM<:AbstractDualModel}
    return sol.dual
end

"""
$(TYPEDSIGNATURES)

Return the dual of the path constraints.

"""
function path_constraints_dual(sol::Solution)
    return path_constraints_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the dual of the boundary constraints.

"""
function boundary_constraints_dual(sol::Solution)
    return boundary_constraints_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the state constraints.

"""
function state_constraints_lb_dual(sol::Solution)
    return state_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the state constraints.

"""
function state_constraints_ub_dual(sol::Solution)
    return state_constraints_ub_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the control constraints.

"""
function control_constraints_lb_dual(sol::Solution)
    return control_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the control constraints.

"""
function control_constraints_ub_dual(sol::Solution)
    return control_constraints_ub_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the variable constraints.

"""
function variable_constraints_lb_dual(sol::Solution)
    return variable_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the variable constraints.

"""
function variable_constraints_ub_dual(sol::Solution)
    return variable_constraints_ub_dual(dual_model(sol))
end

# --------------------------------------------------------------------------------------------------
# print a solution
"""
$(TYPEDSIGNATURES)

Print the solution.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    # Résumé solveur
    println(io, "• Solver:")
    println(io, "  ✓ Successful  : ", successful(sol))
    println(io, "  │  Status     : ", status(sol))
    println(io, "  │  Message    : ", message(sol))
    println(io, "  │  Iterations : ", iterations(sol))
    println(io, "  │  Objective  : ", objective(sol))
    println(io, "  └─ Constraints violation : ", constraints_violation(sol))

    # Variable (si définie)
    if variable_dimension(sol) > 0
        println(
            io,
            "\n• Variable: ",
            variable_name(sol),
            " = (",
            join(variable_components(sol), ", "),
            ") = ",
            variable(sol),
        )
        if dim_variable_constraints_box(sol) > 0
            println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
            println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
        end
    end

    # Boundary constraints duals
    if dim_boundary_constraints_nl(sol) > 0
        println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
    end
end

# ============================================================================== #
# Serialization utilities
# ============================================================================== #

"""
$(TYPEDSIGNATURES)

Serialize a solution into discrete data for export to persistent storage (JLD2, JSON, etc.).

This function converts a `Solution` object (which may contain interpolated functions) into a 
fully discrete, serializable representation. All trajectory functions are evaluated on their 
respective time grids and stored as matrices. The serialization format automatically adapts 
based on whether the solution uses unified or multiple time grids.

# Serialization Formats

The function produces two different formats depending on the solution's time grid model:

## Unified Time Grid Format (Legacy)

When all grids are identical (`UnifiedTimeGridModel`), produces:
```julia
Dict(
    "time_grid" => T,                    # Single grid for all components
    "state" => Matrix,                   # Discretized on T
    "control" => Matrix,                 # Discretized on T
    "costate" => Matrix,                 # Discretized on T
    "path_constraints_dual" => Matrix,   # Discretized on T
    # ... other fields
)
```

## Multiple Time Grids Format

When grids differ (`MultipleTimeGridModel`), produces:
```julia
Dict(
    "time_grid_state" => T_state,        # State-specific grid
    "time_grid_control" => T_control,    # Control-specific grid
    "time_grid_costate" => T_costate,    # Costate-specific grid
    "time_grid_path" => T_path,          # Path constraints grid
    "state" => Matrix,                   # Discretized on T_state
    "control" => Matrix,                 # Discretized on T_control
    "costate" => Matrix,                 # Discretized on T_costate
    "path_constraints_dual" => Matrix,   # Discretized on T_path
    # ... other fields
)
```

# Arguments

- `sol::Solution`: Solution object to serialize (may contain functions or matrices)

# Returns

- `Dict{String, Any}`: Complete serializable dictionary containing:
  - **Time grids**: Either single `"time_grid"` or four separate grids
  - **Trajectories**: `"state"`, `"control"`, `"costate"` as `Matrix{Float64}`
  - **Variable**: `"variable"` as `Vector{Float64}` (time-independent)
  - **Objective**: `"objective"` as `Float64`
  - **Dual variables**: All constraint duals (can be `nothing` if not present)
    - `"path_constraints_dual"`: Path constraint duals on path grid
    - `"state_constraints_lb_dual"`, `"state_constraints_ub_dual"`: State box duals on state grid
    - `"control_constraints_lb_dual"`, `"control_constraints_ub_dual"`: Control box duals on control grid
    - `"boundary_constraints_dual"`: Boundary duals (time-independent vector)
    - `"variable_constraints_lb_dual"`, `"variable_constraints_ub_dual"`: Variable duals (vectors)
  - **Solver info**: `"iterations"`, `"message"`, `"status"`, `"successful"`, `"constraints_violation"`, `"infos"`

# Discretization Behavior

- **Function trajectories**: Evaluated at each point of their associated time grid
- **Matrix trajectories**: Copied as-is (already discrete)
- **Nothing duals**: Preserved as `nothing` in the dictionary
- **Grid association**: Each component is discretized on its correct grid:
  - State and state box duals → `T_state`
  - Control and control box duals → `T_control`
  - Costate → `T_costate`
  - Path constraint duals → `T_path`

# Example

```julia
using CTModels

# Solve OCP with multiple grids
sol = solve(ocp, strategy=MyStrategy())

# Serialize to dictionary
data = _serialize_solution(sol)

# Check format
if haskey(data, "time_grid_state")
    # Multiple grids format
    println("State grid: ", length(data["time_grid_state"]), " points")
    println("Control grid: ", length(data["time_grid_control"]), " points")
    println("Costate grid: ", length(data["time_grid_costate"]), " points")
else
    # Unified grid format
    println("Unified grid: ", length(data["time_grid"]), " points")
end

# Export to file (handled by extensions)
export_ocp_solution(sol; filename="solution", format=:JLD)

# Reconstruct from data
sol_reconstructed = _reconstruct_solution_from_data(ocp, data)
```

# Notes

## Backward Compatibility

The serialization format is designed for backward compatibility:
- Old files with single `"time_grid"` can be read (costate defaults to state grid)
- New files with four grids are forward-compatible with updated readers
- The `_reconstruct_solution_from_data` function handles both formats automatically

## Memory Efficiency

When all grids are identical, the unified format avoids storing redundant grid data, 
reducing file size and memory usage.

## Round-Trip Guarantee

The serialized data is fully compatible with `build_solution` for exact reconstruction:
```julia
data = _serialize_solution(sol)
sol_new = build_solution(ocp, data["time_grid_state"], ...; objective=data["objective"], ...)
```

See also: [`build_solution`](@ref), [`_reconstruct_solution_from_data`](@ref), 
[`export_ocp_solution`](@ref), [`import_ocp_solution`](@ref)
"""
function _serialize_solution(sol::Solution)::Dict{String,Any}
    # Use public getters
    dim_x = state_dimension(sol)
    dim_u = control_dimension(sol)

    # Dispatch based on time grid model type
    return _serialize_solution(time_grid_model(sol), sol, dim_x, dim_u)
end

"""
$(TYPEDSIGNATURES)

Discretize all solution components on their respective time grids for serialization.

This internal helper function extracts the common discretization logic shared by both 
`UnifiedTimeGridModel` and `MultipleTimeGridModel` serialization. It evaluates all 
trajectory functions on their associated time grids and assembles them into a dictionary.

# Grid-Component Association

Each component is discretized on its semantically correct time grid:

- **State trajectory** → `T_state` grid
- **Control trajectory** → `T_control` grid  
- **Costate trajectory** → `T_costate` grid
- **Path constraint duals** → `T_path` grid
- **State box constraint duals** (lb/ub) → `T_state` grid
- **Control box constraint duals** (lb/ub) → `T_control` grid
- **Boundary/variable duals** → Time-independent (vectors, not discretized)

# Arguments

- `sol::Solution`: Solution object containing trajectory functions
- `T_state::Vector{Float64}`: Time grid for state discretization
- `T_control::Vector{Float64}`: Time grid for control discretization
- `T_costate::Vector{Float64}`: Time grid for costate discretization
- `T_path::Vector{Float64}`: Time grid for path constraint dual discretization
- `dim_x::Int`: State dimension (for validation)
- `dim_u::Int`: Control dimension (for validation)

# Returns

- `Dict{String, Any}`: Dictionary with all discretized components (grids not included)

# Notes

This function does NOT include time grid data in the returned dictionary. The calling 
function (`_serialize_solution` for `UnifiedTimeGridModel` or `MultipleTimeGridModel`) 
is responsible for adding the appropriate grid keys.

See also: [`_serialize_solution`](@ref), [`_discretize_function`](@ref), [`_discretize_dual`](@ref)
"""
function _discretize_all_components(
    sol::Solution,
    T_state::Vector{Float64},
    T_control::Vector{Float64},
    T_costate::Vector{Float64},
    T_path::Vector{Float64},
    dim_x::Int,
    dim_u::Int,
)::Dict{String,Any}
    return Dict{String,Any}(
        "state" => _discretize_function(state(sol), T_state, dim_x),
        "control" => _discretize_function(control(sol), T_control, dim_u),
        "control_interpolation" => string(control_interpolation(sol)),
        "costate" => _discretize_function(costate(sol), T_costate, dim_x),
        "variable" => variable(sol),
        "objective" => objective(sol),
        "path_constraints_dual" => _discretize_dual(
            path_constraints_dual(sol), T_path, dim_path_constraints_nl(sol)
        ),
        "state_constraints_lb_dual" => _discretize_dual(
            state_constraints_lb_dual(sol), T_state, dim_state_constraints_box(sol)
        ),
        "state_constraints_ub_dual" => _discretize_dual(
            state_constraints_ub_dual(sol), T_state, dim_state_constraints_box(sol)
        ),
        "control_constraints_lb_dual" => _discretize_dual(
            control_constraints_lb_dual(sol),
            T_control,
            dim_control_constraints_box(sol),
        ),
        "control_constraints_ub_dual" => _discretize_dual(
            control_constraints_ub_dual(sol),
            T_control,
            dim_control_constraints_box(sol),
        ),
        "boundary_constraints_dual" => boundary_constraints_dual(sol),
        "variable_constraints_lb_dual" => variable_constraints_lb_dual(sol),
        "variable_constraints_ub_dual" => variable_constraints_ub_dual(sol),
        "iterations" => iterations(sol),
        "message" => message(sol),
        "status" => status(sol),
        "successful" => successful(sol),
        "constraints_violation" => constraints_violation(sol),
        "infos" => infos(sol),
    )
end

"""
$(TYPEDSIGNATURES)

Serialize solution with unified time grid (legacy single-grid format).

This method handles solutions where all components share the same time grid. It produces 
the legacy format with a single `"time_grid"` key, which is backward-compatible with 
older versions of the package.

# Format Produced

```julia
Dict(
    "time_grid" => T,                    # Single unified grid
    "state" => Matrix,                   # All components discretized on T
    "control" => Matrix,
    "costate" => Matrix,
    # ... all other fields
)
```

# Arguments

- `::UnifiedTimeGridModel`: Time grid model type (dispatch parameter)
- `sol::Solution`: Solution to serialize
- `dim_x::Int`: State dimension
- `dim_u::Int`: Control dimension

# Returns

- `Dict{String, Any}`: Serialized data with single time grid

# Notes

This format is used when `build_solution` is called with identical grids for all components, 
or when using the legacy single-grid signature. It ensures backward compatibility with files 
created before the multi-grid feature was introduced.

See also: [`_serialize_solution(::MultipleTimeGridModel, ...)`](@ref)
"""
function _serialize_solution(::UnifiedTimeGridModel, sol::Solution, dim_x::Int, dim_u::Int)
    # Legacy format: single time grid
    T = time_grid(sol)

    # Discretize all components
    data = _discretize_all_components(sol, T, T, T, T, dim_x, dim_u)

    # Add time grid
    data["time_grid"] = T

    return data
end

"""
$(TYPEDSIGNATURES)

Serialize solution with multiple independent time grids (modern format).

This method handles solutions where different components use different time grids. It produces 
the modern format with four separate grid keys (`time_grid_state`, `time_grid_control`, 
`time_grid_costate`, `time_grid_path`), preserving the independent discretizations.

# Format Produced

```julia
Dict(
    "time_grid_state" => T_state,        # State-specific grid
    "time_grid_control" => T_control,    # Control-specific grid
    "time_grid_costate" => T_costate,    # Costate-specific grid
    "time_grid_path" => T_path,          # Path constraints grid
    "state" => Matrix,                   # Discretized on T_state
    "control" => Matrix,                 # Discretized on T_control
    "costate" => Matrix,                 # Discretized on T_costate
    "path_constraints_dual" => Matrix,   # Discretized on T_path
    # ... all other fields
)
```

# Arguments

- `::MultipleTimeGridModel`: Time grid model type (dispatch parameter)
- `sol::Solution`: Solution to serialize
- `dim_x::Int`: State dimension
- `dim_u::Int`: Control dimension

# Returns

- `Dict{String, Any}`: Serialized data with four independent time grids

# Notes

This format is used when `build_solution` is called with different grids for different 
components. It allows numerical schemes to use optimal discretizations for each component 
(e.g., finer grid for state, coarser for control, custom for costate).

The reconstruction function `_reconstruct_solution_from_data` detects this format by checking 
for the presence of `"time_grid_state"` key and handles it appropriately.

See also: [`_serialize_solution(::UnifiedTimeGridModel, ...)`](@ref), [`build_solution`](@ref)
"""
function _serialize_solution(::MultipleTimeGridModel, sol::Solution, dim_x::Int, dim_u::Int)
    # Multiple time grids format
    T_state = time_grid(sol, :state)
    T_control = time_grid(sol, :control)
    T_costate = time_grid(sol, :costate)
    T_path = time_grid(sol, :path)

    # Discretize all components
    data = _discretize_all_components(
        sol, T_state, T_control, T_costate, T_path, dim_x, dim_u
    )

    # Add multiple time grids
    data["time_grid_state"] = T_state
    data["time_grid_control"] = T_control
    data["time_grid_costate"] = T_costate
    data["time_grid_path"] = T_path

    return data
end
