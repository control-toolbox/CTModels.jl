function build_solution(
    ocp::Model,
    T::Vector{Float64},
    X::Matrix{Float64},
    U::Matrix{Float64},
    v::Vector{Float64},
    P::Matrix{Float64};
    objective::Float64,
    iterations::Int,
    constraints_violation::Float64,
    message::String,
    stopping::Symbol,
    success::Bool,
    path_constraints::Matrix{Float64},
    path_constraints_dual::Matrix{Float64},
    boundary_constraints::Vector{Float64},
    boundary_constraints_dual::Vector{Float64},
    state_constraints_lb_dual::Matrix{Float64},
    state_constraints_ub_dual::Matrix{Float64},
    control_constraints_lb_dual::Matrix{Float64},
    control_constraints_ub_dual::Matrix{Float64},
    variable_constraints_lb_dual::Vector{Float64},
    variable_constraints_ub_dual::Vector{Float64},
)

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
    x = CTBase.ctinterpolate(T, CTBase.matrix2vec(X[:, 1:dim_x], 1))
    p = CTBase.ctinterpolate(T[1:(end - 1)], CTBase.matrix2vec(P[:, 1:dim_x], 1))
    u = CTBase.ctinterpolate(T, CTBase.matrix2vec(U[:, 1:dim_u], 1))

    # force scalar output when dimension is 1
    fx = (dim_x == 1) ? deepcopy(t -> x(t)[1]) : deepcopy(t -> x(t))
    fu = (dim_u == 1) ? deepcopy(t -> u(t)[1]) : deepcopy(t -> u(t))
    fp = (dim_x == 1) ? deepcopy(t -> p(t)[1]) : deepcopy(t -> p(t))
    var = (dim_v == 1) ? v[1] : v

    # misc infos
    infos = Dict{Symbol,Any}()

    # nonlinear constraints and dual variables
    path_constraints_fun =
        t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(path_constraints, 1))(t)
    path_constraints_dual_fun =
        t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(path_constraints_dual, 1))(t)

    # box constraints multipliers
    state_constraints_lb_dual_fun =
        t -> CTBase.ctinterpolate(
            T, CTBase.matrix2vec(state_constraints_lb_dual[:, 1:dim_x], 1)
        )(
            t
        )
    state_constraints_ub_dual_fun =
        t -> CTBase.ctinterpolate(
            T, CTBase.matrix2vec(state_constraints_ub_dual[:, 1:dim_x], 1)
        )(
            t
        )
    control_constraints_lb_dual_fun =
        t -> CTBase.ctinterpolate(
            T, CTBase.matrix2vec(control_constraints_lb_dual[:, 1:dim_u], 1)
        )(
            t
        )
    control_constraints_ub_dual_fun =
        t -> CTBase.ctinterpolate(
            T, CTBase.matrix2vec(control_constraints_ub_dual[:, 1:dim_u], 1)
        )(
            t
        )

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
(state(sol::Solution{TG,T,StateModelSolution{TS},C,V,Co,O,D,I})::TS) where {
    TG<:AbstractTimeGridModel,
    T<:AbstractTimesModel,
    TS<:Function,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    Co<:Function,
    O<:ctNumber,
    D<:AbstractDualModel,
    I<:AbstractSolverInfos,
} = value(sol.state)

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
(
    control(sol::Solution{TG,T,S,ControlModelSolution{TS},V,Co,O,D,I})::TS
) where {
    TG<:AbstractTimeGridModel,
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    TS<:Function,
    V<:AbstractVariableModel,
    Co<:Function,
    O<:ctNumber,
    D<:AbstractDualModel,
    I<:AbstractSolverInfos,
} = value(sol.control)

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
(variable(sol::Solution{TG,T,S,C,VariableModelSolution{TS},Co,O,D,I})::TS) where {
    TG<:AbstractTimeGridModel,
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    TS<:Union{ctNumber,ctVector},
    Co<:Function,
    O<:ctNumber,
    D<:AbstractDualModel,
    I<:AbstractSolverInfos,
} = value(sol.variable)

"""
$(TYPEDSIGNATURES)

Return the costate of the optimal control solution.

```@example
julia> t0 = time_grid(sol)[1]
julia> p  = costate(sol)
julia> p0 = p(t0)
```
"""
(costate(sol::Solution{TG,T,S,C,V,Co,O,D,I})::Co) where {
    TG<:AbstractTimeGridModel,
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    Co<:Function,
    O<:ctNumber,
    D<:AbstractDualModel,
    I<:AbstractSolverInfos,
} = sol.costate

"""
$(TYPEDSIGNATURES)

Return the name of the initial time of the optimal control solution.

"""
initial_time_name(sol::Solution)::String = name(initial(sol.times))

"""
$(TYPEDSIGNATURES)

Return the name of the final time of the optimal control solution.

"""
final_time_name(sol::Solution)::String = name(final(sol.times))

"""
$(TYPEDSIGNATURES)

Return the name of the time component of the optimal control solution.

"""
function time_name(sol::Solution)::String
    return name(sol.times)
end

"""
$(TYPEDSIGNATURES)

Return the time grid of the optimal control solution.

"""
time_grid(sol::OptimalControlSolution{TimeGridModel}) = sol.time_grid.value