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
) where {
    TX<:Union{Matrix{Float64},Function},
    TU<:Union{Matrix{Float64},Function},
    TP<:Union{Matrix{Float64},Function},
    TPCD<:Union{Matrix{Float64},Function,Nothing},
}

    # get dimensions
    dim_x = state_dimension(ocp)
    dim_u = control_dimension(ocp)
    dim_v = variable_dimension(ocp)

    # check that time grid is strictly increasing
    # if not proceed with list of indexes as time grid
    if !issorted(T; lt=<)
        println(
            "WARNING: time grid at solution is not increasing, replacing with list of indices...",
        )
        println(T)
        dim_NLP_steps = length(T) - 1
        T = LinRange(0, dim_NLP_steps, dim_NLP_steps + 1)
    end

    # variables: remove additional state for lagrange objective
    x = if TX <: Function
        X
    else
        N = size(X, 1)
        V = matrix2vec(X[:, 1:dim_x], 1)
        ctinterpolate(T[1:N], V)
    end
    p = if TP <: Function
        P
    elseif length(T) == 2
        t -> P[1, 1:dim_x]
    else
        L = size(P, 1)
        V = matrix2vec(P[:, 1:dim_x], 1)
        ctinterpolate(T[1:L], V)
    end
    u = if TU <: Function
        U
    else
        M = size(U, 1)
        V = matrix2vec(U[:, 1:dim_u], 1)
        ctinterpolate(T[1:M], V)
    end

    # force scalar output when dimension is 1
    fx = (dim_x == 1) ? deepcopy(t -> x(t)[1]) : deepcopy(t -> x(t))
    fu = (dim_u == 1) ? deepcopy(t -> u(t)[1]) : deepcopy(t -> u(t))
    fp = (dim_x == 1) ? deepcopy(t -> p(t)[1]) : deepcopy(t -> p(t))
    var = (dim_v == 1) ? v[1] : v

    # misc infos
    infos = Dict{Symbol,Any}()

    # nonlinear constraints and dual variables
    path_constraints_dual_fun = if isnothing(path_constraints_dual)
        nothing
    elseif TPCD <: Function
        path_constraints_dual
    else
        V = matrix2vec(path_constraints_dual, 1)
        t -> ctinterpolate(T, V)(t)
    end
    # force scalar output when dimension is 1
    fpcd = if isnothing(path_constraints_dual)
        nothing
    else
        if (dim_path_constraints_nl(ocp) == 1)
            deepcopy(t -> path_constraints_dual_fun(t)[1])
        else
            deepcopy(t -> path_constraints_dual_fun(t))
        end
    end

    # box constraints multipliers
    state_constraints_lb_dual_fun = if isnothing(state_constraints_lb_dual)
        nothing
    else
        V = matrix2vec(state_constraints_lb_dual[:, 1:dim_x], 1)
        t -> ctinterpolate(T, V)(t)
    end
    # force scalar output when dimension is 1
    fscbd = if isnothing(state_constraints_lb_dual)
        nothing
    else
        if (dim_x == 1)
            deepcopy(t -> state_constraints_lb_dual_fun(t)[1])
        else
            deepcopy(t -> state_constraints_lb_dual_fun(t))
        end
    end

    state_constraints_ub_dual_fun = if isnothing(state_constraints_ub_dual)
        nothing
    else
        V = matrix2vec(state_constraints_ub_dual[:, 1:dim_x], 1)
        t -> ctinterpolate(T, V)(t)
    end
    # force scalar output when dimension is 1
    fscud = if isnothing(state_constraints_ub_dual)
        nothing
    else
        if (dim_x == 1)
            deepcopy(t -> state_constraints_ub_dual_fun(t)[1])
        else
            deepcopy(t -> state_constraints_ub_dual_fun(t))
        end
    end

    control_constraints_lb_dual_fun = if isnothing(control_constraints_lb_dual)
        nothing
    else
        V = matrix2vec(control_constraints_lb_dual[:, 1:dim_u], 1)
        t -> ctinterpolate(T, V)(t)
    end
    # force scalar output when dimension is 1
    fccbd = if isnothing(control_constraints_lb_dual)
        nothing
    else
        if (dim_u == 1)
            deepcopy(t -> control_constraints_lb_dual_fun(t)[1])
        else
            deepcopy(t -> control_constraints_lb_dual_fun(t))
        end
    end

    control_constraints_ub_dual_fun = if isnothing(control_constraints_ub_dual)
        nothing
    else
        V = matrix2vec(control_constraints_ub_dual[:, 1:dim_u], 1)
        t -> ctinterpolate(T, V)(t)
    end
    # force scalar output when dimension is 1
    fccud = if isnothing(control_constraints_ub_dual)
        nothing
    else
        if (dim_u == 1)
            deepcopy(t -> control_constraints_ub_dual_fun(t)[1])
        else
            deepcopy(t -> control_constraints_ub_dual_fun(t))
        end
    end

    # build Models
    time_grid = TimeGridModel(T)
    state = StateModelSolution(state_name(ocp), state_components(ocp), fx)
    control = ControlModelSolution(control_name(ocp), control_components(ocp), fu)
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
        fp,
        objective,
        dual,
        solver_infos,
        ocp,
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
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
        <:AbstractModel,
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
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
        <:AbstractModel,
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
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
        <:AbstractModel,
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
        Co,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
        <:AbstractModel,
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

"""
$(TYPEDSIGNATURES)

Return the time grid.

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
        <:AbstractModel,
    },
)::T where {T<:TimesDisc}
    return sol.time_grid.value
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
        <:Function,
        O,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
        <:AbstractModel,
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
        <:AbstractModel,
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

"""
$(TYPEDSIGNATURES)

"""
function model(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
        TM,
    },
)::TM where {TM<:AbstractModel}
    return sol.model
end

# --------------------------------------------------------------------------------------------------
# print a solution
"""
$(TYPEDSIGNATURES)

Prints the solution.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    println(io, "Optimal Control Solution")
    println(io, "────────────────────────")

    # Status
    println(io, "• Successful : ", successful(sol))
    println(io, "• Status     : ", status(sol))
    println(io, "• Message    : ", message(sol))
    println(io, "• Iterations : ", iterations(sol))
    println(io, "• Objective  : ", objective(sol))
    println(io, "• Constraint violation: ", constraints_violation(sol))

    println(io)
    println(io, "Time")
    println(io, "────")
    println(io, "• Name        : ", time_name(sol))
    println(io, "• Grid        : ", time_grid(sol))
    println(io, "• Grid length : ", length(time_grid(sol)))

    println(io)
    println(io, "State")
    println(io, "─────")
    println(io, "• Name        : ", state_name(sol))
    println(io, "• Dimension   : ", state_dimension(sol))
    println(io, "• Components  : ", join(state_components(sol), ", "))

    println(io)
    println(io, "Control")
    println(io, "───────")
    println(io, "• Name        : ", control_name(sol))
    println(io, "• Dimension   : ", control_dimension(sol))
    println(io, "• Components  : ", join(control_components(sol), ", "))

    # Variable block (optional)
    v_dim = variable_dimension(sol)
    if v_dim > 0
        println(io)
        println(io, "Variable")
        println(io, "────────")
        println(io, "• Name       : ", variable_name(sol))
        println(io, "• Dimension  : ", v_dim)
        println(io, "• Components : ", join(variable_components(sol), ", "))
        println(io, "• Value      : ", variable(sol))
    end

    println(io)
    println(io, "Duals")
    println(io, "─────")
    println(io, "• Boundary constraints dual: ", boundary_constraints_dual(sol))
    if v_dim > 0
        println(io, "• Variable constraints dual (lb): ", variable_constraints_lb_dual(sol))
        println(io, "• Variable constraints dual (ub): ", variable_constraints_ub_dual(sol))
    end
end

# """
# $(TYPEDSIGNATURES)

# """
# function Base.show_default(io::IO, sol::Solution)
#     return print(io, "Optimal Control Solution")
#     #show(io, MIME("text/plain"), sol)
# end
