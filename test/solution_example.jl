function solution_example(; fun=false)

    # create a pre-model
    pre_ocp = CTModels.PreModel()

    # set times
    CTModels.time!(pre_ocp; t0=0.0, tf=1.0)

    # set state
    CTModels.state!(pre_ocp, 2)

    # set control
    CTModels.control!(pre_ocp, 1)

    pre_ocp_returned = deepcopy(pre_ocp)

    # set control
    CTModels.variable!(pre_ocp, 2)

    # set dynamics
    dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
    CTModels.dynamics!(pre_ocp, dynamics!) # does not correspond to the solution

    # set objective
    mayer(x0, xf, v) = x0[1] + xf[1]
    lagrange(t, x, u, v) = 0.5 * u[1]^2
    CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange) # does not correspond to the solution

    # set some constraints
    f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
    f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
    f_variable(r, t, v) = r .= v .+ t
    CTModels.constraint!(pre_ocp, :path; f=f_path, lb=[0, 1], ub=[1, 2], label=:path)
    CTModels.constraint!(
        pre_ocp, :boundary; f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary
    )
    CTModels.constraint!(pre_ocp, :state; rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
    CTModels.constraint!(pre_ocp, :control; rg=1:1, lb=[0], ub=[1], label=:control_rg)
    CTModels.constraint!(
        pre_ocp, :variable; rg=1:2, lb=[0, 1], ub=[1, 2], label=:variable_rg
    )

    # set definition
    definition = quote
        t ∈ [0, 1], time
        x ∈ R², state
        u ∈ R, control
        x(0) == [-1, 0]
        x(1) == [0, 0]
        ẋ(t) == [x₂(t), u(t)]
        ∫(0.5u(t)^2) → min
    end
    CTModels.definition!(pre_ocp, definition) # does not correspond to the solution

    # build model
    ocp = CTModels.build_model(pre_ocp)

    # create a solution

    # times: T Vector{Float64}
    t0 = 0.0
    tf = 1.0
    N = 201
    T = range(t0, tf; length=N)
    # convert T to a vector of Float64
    T = Vector{Float64}(T)

    # state: X Matrix{Float64}
    x0 = [-1.0, 0.0]
    xf = [0.0, 0.0]
    a = x0[1]
    b = x0[2]
    C = [
        -(tf - t0)^3/6.0 (tf - t0)^2/2.0
        -(tf - t0)^2/2.0 (tf-t0)
    ]
    D = [-a - b * (tf - t0), -b] + xf
    p0 = C \ D
    α = p0[1]
    β = p0[2]
    function x(t)
        return [
            a + b * (t - t0) + β * (t - t0)^2 / 2.0 - α * (t - t0)^3 / 6.0,
            b + β * (t - t0) - α * (t - t0)^2 / 2.0,
        ]
    end
    X = fun ? x : vcat([x(t)' for t in T]...)

    # costate: P Matrix{Float64}
    P = zeros(N, 2)
    function p(t)
        return [α, -α * (t - t0) + β]
    end
    P = fun ? p : vcat([p(t)' for t in T[1:(end - 1)]]...)

    # control: U Matrix{Float64}
    U = zeros(N, 1)
    function u(t)
        return [p(t)[2]]
    end
    U = fun ? u : vcat([u(t)' for t in T]...)

    # variable: v Vector{Float64}
    v = Float64[]

    # objective: Float64
    objective = 0.5 * (α^2 * (tf - t0)^3 / 3 + β^2 * (tf - t0) - α * β * (tf - t0)^2)

    # Iterations: Int
    iterations = 0

    # Constraints violation: Float64
    constraints_violation = 0.0

    # Message: String
    message = "Solve_Succeeded"

    # Stopping: Symbol
    stopping = :Solve_Succeeded

    # Success: Bool
    success = true

    # Path constraints: Matrix{Float64}
    path_constraints = nothing

    # Path constraints dual: Matrix{Float64}
    path_constraints_dual = nothing

    # Boundary constraints: Vector{Float64}
    boundary_constraints = nothing

    # Boundary constraints dual: Vector{Float64}
    boundary_constraints_dual = nothing

    # State constraints lower bound dual: Matrix{Float64}
    state_constraints_lb_dual = nothing

    # State constraints upper bound dual: Matrix{Float64}
    state_constraints_ub_dual = nothing

    # Control constraints lower bound dual: Matrix{Float64}
    control_constraints_lb_dual = nothing

    # Control constraints upper bound dual: Matrix{Float64}
    control_constraints_ub_dual = nothing

    # Variable constraints lower bound dual: Vector{Float64}
    variable_constraints_lb_dual = nothing

    # Variable constraints upper bound dual: Vector{Float64}
    variable_constraints_ub_dual = nothing

    # solution
    sol = CTModels.build_solution(
        ocp,
        T,
        X,
        U,
        v,
        P;
        objective=objective,
        iterations=iterations,
        constraints_violation=constraints_violation,
        message=message,
        stopping=stopping,
        success=success,
        path_constraints=path_constraints,
        path_constraints_dual=path_constraints_dual,
        boundary_constraints=boundary_constraints,
        boundary_constraints_dual=boundary_constraints_dual,
        state_constraints_lb_dual=state_constraints_lb_dual,
        state_constraints_ub_dual=state_constraints_ub_dual,
        control_constraints_lb_dual=control_constraints_lb_dual,
        control_constraints_ub_dual=control_constraints_ub_dual,
        variable_constraints_lb_dual=variable_constraints_lb_dual,
        variable_constraints_ub_dual=variable_constraints_ub_dual,
    )

    # return
    return ocp, sol, pre_ocp_returned
end
