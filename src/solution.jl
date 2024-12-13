function build_solution(
    ocp::Model,
    T::Vector{Float64},
    X::Matrix{Float64},
    U::Matrix{Float64},
    v::Vector{Float64},
    P::Matrix{Float64};
    cost::Float64,
    iterations::Int,
    constraints_violation::Float64,
    message::String,
    stopping::Symbol,
    success::Bool,
    state_constraints_lb_dual::Matrix{Float64},
    state_constraints_ub_dual::Matrix{Float64},
    control_constraints_lb_dual::Matrix{Float64},
    control_constraints_ub_dual::Matrix{Float64},
    variable_constraints_lb_dual::Vector{Float64},
    variable_constraints_ub_dual::Vector{Float64},
    boundary_constraints::Vector{Float64},
    boundary_constraints_dual::Vector{Float64},
    path_constraints::Matrix{Float64},
    path_constraints_dual::Matrix{Float64},
    variable_constraints::Vector{Float64},
    variable_constraints_dual::Vector{Float64}
)

    # get dimensions
    dim_x = state_dimension(ocp)
    dim_u = control_dimension(ocp)
    dim_v = variable_dimension(ocp)

    # check that time grid is strictly increasing
    # if not proceed with list of indexes as time grid
    if !issorted(T, lt = <=)
        println(
            "WARNING: time grid at solution is not strictly increasing, replacing with list of indices...",
        )
        println(T)
        dim_NLP_steps = length(T) - 1
        T = LinRange(0, dim_NLP_steps, dim_NLP_steps + 1)
    end

    # variables: remove additional state for lagrange cost
    x = CTBase.ctinterpolate(T,              CTBase.matrix2vec(X[:, 1:dim_x], 1))
    p = CTBase.ctinterpolate(T[1:(end - 1)], CTBase.matrix2vec(P[:, 1:dim_x], 1))
    u = CTBase.ctinterpolate(T,              CTBase.matrix2vec(U[:, 1:dim_u], 1))

    # force scalar output when dimension is 1
    fx = (dim_x == 1) ? deepcopy(t -> x(t)[1]) : deepcopy(t -> x(t))
    fu = (dim_u == 1) ? deepcopy(t -> u(t)[1]) : deepcopy(t -> u(t))
    fp = (dim_x == 1) ? deepcopy(t -> p(t)[1]) : deepcopy(t -> p(t))
    var = (dim_v == 1) ? v[1] : v

    # misc infos
    infos = Dict{Symbol, Any}()

    # nonlinear constraints and dual variables
    path_constraints_fun = t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(path_constraints, 1))(t)
    path_constraints_dual_fun = t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(path_constraints_dual, 1))(t)

    # box constraints multipliers
    state_constraints_lb_dual_fun = t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(state_constraints_lb_dual[:, 1:dim_x], 1))(t)
    state_constraints_ub_dual_fun = t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(state_constraints_ub_dual[:, 1:dim_x], 1))(t)
    control_constraints_lb_dual_fun = t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(control_constraints_lb_dual[:, 1:dim_u], 1))(t)
    control_constraints_ub_dual_fun = t -> CTBase.ctinterpolate(T, CTBase.matrix2vec(control_constraints_ub_dual[:, 1:dim_u], 1))(t)

    # build Models
    time_grid = TimeGridModel(T)
    state = StateModelSolution(state_name(ocp), state_components(ocp), fx)
    control = ControlModelSolution(control_name(ocp), control_components(ocp), fu)
    variable = VariableModelSolution(variable_name(ocp),  variable_cpùomponents(ocp), var)
    dual = DualModel(
        state_constraints_lb_dual_fun,
        state_constraints_ub_dual_fun,
        control_constraints_lb_dual_fun,
        control_constraints_ub_dual_fun,
        variable_constraints_lb_dual,
        variable_constraints_ub_dual,
        boundary_constraints,
        boundary_constraints_dual,
        path_constraints_fun,
        path_constraints_dual_fun,
        variable_constraints,
        variable_constraints_dual,
    )
    solver_infos = SolverInfos(
        iterations,
        stopping,
        message,
        success,
        constraints_violation,
        infos,
    )

    return Solution(
        time_grid,
        times(ocp),
        state,
        control,
        variable,
        fp,
        cost,
        dual,
        solver_infos
    )

end