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
- `message::String`: the message associated to the stopping criterion.
- `stopping::Symbol`: the stopping criterion.
- `success::Bool`: the success status.
- `path_constraints::Matrix{Float64}`: the path constraints.
- `path_constraints_dual::Matrix{Float64}`: the dual of the path constraints.
- `boundary_constraints::Vector{Float64}`: the boundary constraints.
- `boundary_constraints_dual::Vector{Float64}`: the dual of the boundary constraints.
- `state_constraints_lb_dual::Matrix{Float64}`: the lower bound dual of the state constraints.
- `state_constraints_ub_dual::Matrix{Float64}`: the upper bound dual of the state constraints.
- `control_constraints_lb_dual::Matrix{Float64}`: the lower bound dual of the control constraints.
- `control_constraints_ub_dual::Matrix{Float64}`: the upper bound dual of the control constraints.
- `variable_constraints_lb_dual::Vector{Float64}`: the lower bound dual of the variable constraints.
- `variable_constraints_ub_dual::Vector{Float64}`: the upper bound dual of the variable constraints.

# Returns

- `sol::Solution`: the optimal control solution.

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
    stopping::Symbol,
    success::Bool,
    path_constraints::Union{Matrix{Float64},Nothing}=__constraints(),
    path_constraints_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    boundary_constraints::Union{Vector{Float64},Nothing}=__constraints(),
    boundary_constraints_dual::Union{Vector{Float64},Nothing}=__constraints(),
    state_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    state_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    variable_constraints_lb_dual::Union{Vector{Float64},Nothing}=__constraints(),
    variable_constraints_ub_dual::Union{Vector{Float64},Nothing}=__constraints(),
) where {
    TX<:Union{Matrix{Float64},Function},
    TU<:Union{Matrix{Float64},Function},
    TP<:Union{Matrix{Float64},Function},
}

    # get dimensions
    dim_x = state_dimension(ocp)
    dim_u = control_dimension(ocp)
    dim_v = variable_dimension(ocp)

    # check that time grid is strictly increasing
    # if not proceed with list of indexes as time grid
    if !issorted(T; lt=<=)
        println(
            "WARNING: time grid at solution is not strictly increasing, replacing with list of indices...",
        )
        println(T)
        dim_NLP_steps = length(T) - 1
        T = LinRange(0, dim_NLP_steps, dim_NLP_steps + 1)
    end

    # variables: remove additional state for lagrange objective
    x = if TX <: Function
        X
    else
        V = matrix2vec(X[:, 1:dim_x], 1)
        ctinterpolate(T, V)
    end
    p = if TP <: Function
        P
    elseif length(T) == 2
        t -> P[1, 1:dim_x]
    else
        V = matrix2vec(P[:, 1:dim_x], 1)
        ctinterpolate(T[1:(end - 1)], V)
    end
    u = if TU <: Function
        U
    else
        V = matrix2vec(U[:, 1:dim_u], 1)
        ctinterpolate(T, V)
    end

    # force scalar output when dimension is 1
    fx = (dim_x == 1) ? deepcopy(t -> x(t)[1]) : deepcopy(t -> x(t))
    fu = (dim_u == 1) ? deepcopy(t -> u(t)[1]) : deepcopy(t -> u(t))
    fp = (dim_x == 1) ? deepcopy(t -> p(t)[1]) : deepcopy(t -> p(t))
    var = (dim_v == 1) ? v[1] : v

    # misc infos
    infos = Dict{Symbol,Any}()

    # nonlinear constraints and dual variables
    path_constraints_fun = if isnothing(path_constraints)
        nothing
    else
        V = matrix2vec(path_constraints, 1)
        t -> ctinterpolate(T, V)(t)
    end

    path_constraints_dual_fun = if isnothing(path_constraints_dual)
        nothing
    else
        V = matrix2vec(path_constraints_dual, 1)
        t -> ctinterpolate(T, V)(t)
    end

    # box constraints multipliers
    state_constraints_lb_dual_fun = if isnothing(state_constraints_lb_dual)
        nothing
    else
        V = matrix2vec(state_constraints_lb_dual[:, 1:dim_x], 1)
        t -> ctinterpolate(T, V)(t)
    end

    state_constraints_ub_dual_fun = if isnothing(state_constraints_ub_dual)
        nothing
    else
        V = matrix2vec(state_constraints_ub_dual[:, 1:dim_x], 1)
        t -> ctinterpolate(T, V)(t)
    end

    control_constraints_lb_dual_fun = if isnothing(control_constraints_lb_dual)
        nothing
    else
        V = matrix2vec(control_constraints_lb_dual[:, 1:dim_u], 1)
        t -> ctinterpolate(T, V)(t)
    end

    control_constraints_ub_dual_fun = if isnothing(control_constraints_ub_dual)
        nothing
    else
        V = matrix2vec(control_constraints_ub_dual[:, 1:dim_u], 1)
        t -> ctinterpolate(T, V)(t)
    end

    # build Models
    time_grid = TimeGridModel(T)
    state = StateModelSolution(state_name(ocp), state_components(ocp), fx)
    control = ControlModelSolution(control_name(ocp), control_components(ocp), fu)
    variable = VariableModelSolution(variable_name(ocp), variable_components(ocp), var)
    dual = DualModel(
        path_constraints_fun,
        path_constraints_dual_fun,
        boundary_constraints,
        boundary_constraints_dual,
        state_constraints_lb_dual_fun,
        state_constraints_ub_dual_fun,
        control_constraints_lb_dual_fun,
        control_constraints_ub_dual_fun,
        variable_constraints_lb_dual,
        variable_constraints_ub_dual,
    )
    solver_infos = SolverInfos(
        iterations, stopping, message, success, constraints_violation, infos
    )

    return Solution(
        time_grid, times(ocp), state, control, variable, fp, objective, dual, solver_infos
    )
end

# ------------------------------------------------------------------------------ #
# Getters
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the dimension of the state of the optimal control solution.

"""
function state_dimension(sol::Solution)::Dimension
    return dimension(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the state of the optimal control solution.

"""
function state_components(sol::Solution)::Vector{String}
    return components(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the name of the state of the optimal control solution.

"""
function state_name(sol::Solution)::String
    return name(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the state (function of time) of the optimal control solution.

```@example
julia> t0 = time_grid(sol)[1]
julia> x  = state(sol)
julia> x0 = x(t0)
```
"""
function state(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:StateModelSolution{TS},
        <:AbstractControlModel,
        <:AbstractVariableModel,
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

Return the state values at times `time_grid(sol)` of the optimal control solution or `nothing`.

```@example
julia> x  = state_discretized(sol)
julia> x0 = x[1] # state at initial time
```
"""
state_discretized(sol::Solution) = state(sol).(time_grid(sol))

"""
$(TYPEDSIGNATURES)

Return the dimension of the control of the optimal control solution.

"""
function control_dimension(sol::Solution)::Dimension
    return dimension(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the control of the optimal control solution.

"""
function control_components(sol::Solution)::Vector{String}
    return components(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the name of the control of the optimal control solution.

"""
function control_name(sol::Solution)::String
    return name(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the control (function of time) of the optimal control solution.

```@example
julia> t0 = time_grid(sol)[1]
julia> u  = control(sol)
julia> u0 = u(t0) # control at initial time
```
"""
function control(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:ControlModelSolution{TS},
        <:AbstractVariableModel,
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

Return the control values at times `time_grid(sol)` of the optimal control solution or `nothing`.

```@example
julia> u  = control_discretized(sol)
julia> u0 = u[1] # control at initial time
```
"""
control_discretized(sol::Solution) = control(sol).(time_grid(sol))

"""
$(TYPEDSIGNATURES)

Return the dimension of the variable of the optimal control solution.

"""
function variable_dimension(sol::Solution)::Dimension
    return dimension(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable of the optimal control solution.

"""
function variable_components(sol::Solution)::Vector{String}
    return components(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the name of the variable of the optimal control solution.

"""
function variable_name(sol::Solution)::String
    return name(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the variable of the optimal control solution or `nothing`.

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

Return the costate of the optimal control solution.

```@example
julia> t0 = time_grid(sol)[1]
julia> p  = costate(sol)
julia> p0 = p(t0)
```
"""
function costate(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
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

Return the costate values at times `time_grid(sol)` of the optimal control solution or `nothing`.

```@example
julia> p  = costate_discretized(sol)
julia> p0 = p[1] # costate at initial time
```
"""
costate_discretized(sol::Solution) = costate(sol).(time_grid(sol))

"""
$(TYPEDSIGNATURES)

Return the name of the initial time of the optimal control solution.

"""
function initial_time_name(sol::Solution)::String
    return name(initial(sol.times))
end

"""
$(TYPEDSIGNATURES)

Return the name of the final time of the optimal control solution.

"""
function final_time_name(sol::Solution)::String
    return name(final(sol.times))
end

"""
$(TYPEDSIGNATURES)

Return the name of the time component of the optimal control solution.

"""
function time_name(sol::Solution)::String
    return time_name(sol.times)
end

"""
$(TYPEDSIGNATURES)

Return the time grid of the optimal control solution.

"""
function time_grid(
    sol::Solution{
        <:TimeGridModel{T},
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
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

Return the objective value of the optimal control solution.

"""
function objective(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
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

Return the number of iterations (if solved by an iterative method) of the optimal control solution.

"""
function iterations(sol::Solution)::Int
    return sol.solver_infos.iterations
end

"""
$(TYPEDSIGNATURES)

Return the stopping criterion (a Symbol) of the optimal control solution.

"""
function stopping(sol::Solution)::Symbol
    return sol.solver_infos.stopping
end

"""
$(TYPEDSIGNATURES)

Return the message associated to the stopping criterion of the optimal control solution.

"""
function message(sol::Solution)::String
    return sol.solver_infos.message
end

"""
$(TYPEDSIGNATURES)

Return the success status of the optimal control solution.

"""
function success(sol::Solution)::Bool
    return sol.solver_infos.success
end

"""
$(TYPEDSIGNATURES)

Return the constraints violation of the optimal control solution.

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

# constraints and multipliers:
# path_constraints::PC
# path_constraints_dual::PC_Dual
# boundary_constraints::BC
# boundary_constraints_dual::BC_Dual
# state_constraints_lb_dual::SC_LB_Dual
# state_constraints_ub_dual::SC_UB_Dual
# control_constraints_lb_dual::CC_LB_Dual
# control_constraints_ub_dual::CC_UB_Dual
# variable_constraints_lb_dual::VC_LB_Dual
# variable_constraints_ub_dual::VC_UB_Dual

"""
$(TYPEDSIGNATURES)

"""
function dual_model(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
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

Return the path constraints of the optimal control solution.

"""
function path_constraints(sol::Solution)
    return path_constraints(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the dual of the path constraints of the optimal control solution.

"""
function path_constraints_dual(sol::Solution)
    return path_constraints_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the boundary constraints of the optimal control solution.

"""
function boundary_constraints(sol::Solution)
    return boundary_constraints(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the dual of the boundary constraints of the optimal control solution.

"""
function boundary_constraints_dual(sol::Solution)
    return boundary_constraints_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the state constraints of the optimal control solution.

"""
function state_constraints_lb_dual(sol::Solution)
    return state_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the state constraints of the optimal control solution.

"""
function state_constraints_ub_dual(sol::Solution)
    return state_constraints_ub_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the control constraints of the optimal control solution.

"""
function control_constraints_lb_dual(sol::Solution)
    return control_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the control constraints of the optimal control solution.

"""
function control_constraints_ub_dual(sol::Solution)
    return control_constraints_ub_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the variable constraints of the optimal control solution.

"""
function variable_constraints_lb_dual(sol::Solution)
    return variable_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the variable constraints of the optimal control solution.

"""
function variable_constraints_ub_dual(sol::Solution)
    return variable_constraints_ub_dual(dual_model(sol))
end

# --------------------------------------------------------------------------------------------------
# print a solution
"""
$(TYPEDSIGNATURES)

Prints the solution.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    return print(io, typeof(sol))
end

"""
$(TYPEDSIGNATURES)

"""
function Base.show_default(io::IO, sol::Solution)
    return print(io, typeof(sol))
    #show(io, MIME("text/plain"), sol)
end
