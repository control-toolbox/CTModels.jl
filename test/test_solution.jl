function test_solution()

    # create an ocp
    pre_ocp = CTModels.PreModel()
    CTModels.time!(pre_ocp; t0=0.0, tf=1.0, time_name=:s)
    CTModels.state!(pre_ocp, 2, "y", ["u", "v"])
    CTModels.control!(pre_ocp, 1, "w")
    CTModels.variable!(pre_ocp, 2, "z", ["a", "b"])
    dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
    CTModels.dynamics!(pre_ocp, dynamics!) # does not correspond to the solution
    mayer(x0, xf, v) = x0[1] + xf[1]
    lagrange(t, x, u, v) = 0.5 * u[1]^2
    CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange) # does not correspond to the solution
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
    CTModels.definition!(pre_ocp, quote end)
    ocp = CTModels.build_model(pre_ocp)

    # create a solution
    T = [0.0, 0.5, 1.0]
    X = [0.0 0.0; 0.5 0.5; 1.0 1.0]
    U = zeros(3, 1)
    U[:, 1] = [1.0, 2.0, 3.0]
    v = [10.0, 11.0]
    P = [10.0 10.0; 11.0 11.0] #; 12.0 12.0]
    objective = 0.5
    iterations = 10
    constraints_violation = 12.0
    message = "message"
    stopping = :stopping
    success = true
    path_constraints_dual = nothing
    boundary_constraints_dual = nothing
    state_constraints_lb_dual = nothing
    state_constraints_ub_dual = nothing
    control_constraints_lb_dual = nothing
    control_constraints_ub_dual = nothing
    variable_constraints_lb_dual = nothing
    variable_constraints_ub_dual = nothing
    kwargs = Dict(
        :objective => objective,
        :iterations => iterations,
        :constraints_violation => constraints_violation,
        :message => message,
        :stopping => stopping,
        :success => success,
        :path_constraints_dual => path_constraints_dual,
        :boundary_constraints_dual => boundary_constraints_dual,
        :state_constraints_lb_dual => state_constraints_lb_dual,
        :state_constraints_ub_dual => state_constraints_ub_dual,
        :control_constraints_lb_dual => control_constraints_lb_dual,
        :control_constraints_ub_dual => control_constraints_ub_dual,
        :variable_constraints_lb_dual => variable_constraints_lb_dual,
        :variable_constraints_ub_dual => variable_constraints_ub_dual,
    )
    sol = CTModels.build_solution(ocp, T, X, U, v, P; kwargs...)

    # call getters and check the values
    @test CTModels.model(sol) isa CTModels.Model
    @testset "state" begin
        @test CTModels.state_dimension(sol) == 2
        @test CTModels.state_name(sol) == "y"
        @test CTModels.state_components(sol) == ["u", "v"]
        @test CTModels.state(sol)(1) == [1.0, 1.0]
        @test CTModels.state(sol)(0.4) == [0.4, 0.4] # linear interpolation
        X_ = t -> [t, t]
        sol_ = CTModels.build_solution(ocp, T, X_, U, v, P; kwargs...)
        @test CTModels.state(sol_)(1) == [1.0, 1.0]
    end
    @testset "control" begin
        @test CTModels.control_dimension(sol) == 1
        @test CTModels.control_name(sol) == "w"
        @test CTModels.control_components(sol) == ["w"]
        @test CTModels.control(sol)(1) == 3.0 # it is a scalar since the control dimension is 1
        U_ = t -> [3t]
        sol_ = CTModels.build_solution(ocp, T, X, U_, v, P; kwargs...)
        @test CTModels.control(sol_)(1) == 3.0
    end
    @testset "variable" begin
        @test CTModels.variable_dimension(sol) == 2
        @test CTModels.variable_name(sol) == "z"
        @test CTModels.variable_components(sol) == ["a", "b"]
        @test CTModels.variable(sol) == [10.0, 11.0]
    end
    @testset "costate" begin
        @test CTModels.costate(sol)(1) == [12.0, 12.0] # linear interpolation
        P_ = [10.0 10.0; 11.0 11.0; 12.0 12.0] # test with 3 points
        sol_ = CTModels.build_solution(ocp, T, X, U, v, P_; kwargs...)
        @test CTModels.costate(sol_)(1) == [12.0, 12.0]
        P_ = t -> 10.0 .+ 2*[t, t]
        sol_ = CTModels.build_solution(ocp, T, X, U, v, P_; kwargs...)
        @test CTModels.costate(sol_)(1) == [12.0, 12.0]
    end
    @testset "time" begin
        @test CTModels.time_name(sol) == "s"
        @test CTModels.initial_time_name(sol) == "0.0"
        @test CTModels.final_time_name(sol) == "1.0"
        @test CTModels.time_grid(sol) == [0.0, 0.5, 1.0]
    end
    @testset "infos" begin
        @test CTModels.objective(sol) == 0.5
        @test CTModels.iterations(sol) == 10
        @test CTModels.constraints_violation(sol) == 12.0
        @test CTModels.message(sol) == "message"
        @test CTModels.stopping(sol) == :stopping
        @test CTModels.success(sol) == true
        @test CTModels.infos(sol) == Dict()
    end
    @testset "dual to constraints" begin
        @test CTModels.path_constraints_dual(sol) === nothing
        @test CTModels.boundary_constraints_dual(sol) === nothing
        @test CTModels.state_constraints_lb_dual(sol) === nothing
        @test CTModels.state_constraints_ub_dual(sol) === nothing
        @test CTModels.control_constraints_lb_dual(sol) === nothing
        @test CTModels.control_constraints_ub_dual(sol) === nothing
        @test CTModels.variable_constraints_lb_dual(sol) === nothing
        @test CTModels.variable_constraints_ub_dual(sol) === nothing
        # path constraints dual: matrix and function
        path_constraints_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        path_constraints_dual_func = t -> [1.0+4.0*t, 2.0+4.0*t]
        sol_ = CTModels.build_solution(
            ocp, T, X, U, v, P; kwargs..., path_constraints_dual=path_constraints_dual
        )
        @test CTModels.path_constraints_dual(sol_)(1) == [5.0, 6.0]
        sol_ = CTModels.build_solution(
            ocp, T, X, U, v, P; kwargs..., path_constraints_dual=path_constraints_dual_func
        )
        @test CTModels.path_constraints_dual(sol_)(1) == [5.0, 6.0]
        # boundary constraints dual: vector
        boundary_constraints_dual = [3.0, 2.0]
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            boundary_constraints_dual=boundary_constraints_dual,
        )
        @test CTModels.boundary_constraints_dual(sol_) == [3.0, 2.0]
        # state constraints lower bounds dual: matrix
        state_constraints_lb_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            state_constraints_lb_dual=state_constraints_lb_dual,
        )
        @test CTModels.state_constraints_lb_dual(sol_)(1) == [5.0, 6.0]
        # state constraints upper bounds dual: matrix
        state_constraints_ub_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            state_constraints_ub_dual=state_constraints_ub_dual,
        )
        @test CTModels.state_constraints_ub_dual(sol_)(1) == [5.0, 6.0]
        # control constraints lower bounds dual: matrix
        ccld = zeros(3, 1)
        ccld[:, 1] = [1.0, 2.0, 3.0]
        control_constraints_lb_dual = ccld
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            control_constraints_lb_dual=control_constraints_lb_dual,
        )
        @test CTModels.control_constraints_lb_dual(sol_)(1) == 3.0
        # control constraints upper bounds dual: matrix
        control_constraints_ub_dual = ccld
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            control_constraints_ub_dual=control_constraints_ub_dual,
        )
        @test CTModels.control_constraints_ub_dual(sol_)(1) == 3.0
        # variable constraints lower bounds dual: vector
        variable_constraints_lb_dual = [1.0, 2.0]
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            variable_constraints_lb_dual=variable_constraints_lb_dual,
        )
        @test CTModels.variable_constraints_lb_dual(sol_) == [1.0, 2.0]
        # variable constraints upper bounds dual: vector
        variable_constraints_ub_dual = [1.0, 2.0]
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            variable_constraints_ub_dual=variable_constraints_ub_dual,
        )
        @test CTModels.variable_constraints_ub_dual(sol_) == [1.0, 2.0]
    end
    @testset "dual from label" begin
        path_constraints_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        boundary_constraints_dual = [3.0, 2.0]
        state_constraints_lb_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        state_constraints_ub_dual = -[1.0 2.0; 3.0 4.0; 5.0 6.0]
        control_constraints_lb_dual = zeros(3, 1)
        control_constraints_lb_dual[:, 1] = [1.0, 2.0, 3.0]
        control_constraints_ub_dual = zeros(3, 1)
        control_constraints_ub_dual[:, 1] = -[1.0, 2.0, 3.0]
        variable_constraints_lb_dual = [1.0, 2.0]
        variable_constraints_ub_dual = -[1.0, 2.0]
        sol_ = CTModels.build_solution(
            ocp,
            T,
            X,
            U,
            v,
            P;
            kwargs...,
            path_constraints_dual=path_constraints_dual,
            boundary_constraints_dual=boundary_constraints_dual,
            state_constraints_lb_dual=state_constraints_lb_dual,
            state_constraints_ub_dual=state_constraints_ub_dual,
            control_constraints_lb_dual=control_constraints_lb_dual,
            control_constraints_ub_dual=control_constraints_ub_dual,
            variable_constraints_lb_dual=variable_constraints_lb_dual,
            variable_constraints_ub_dual=variable_constraints_ub_dual,
        )
        @test CTModels.dual(sol_, ocp, :path)(1) == [5.0, 6.0]
        @test CTModels.dual(sol_, ocp, :boundary) == [3.0, 2.0]
        @test CTModels.dual(sol_, ocp, :state_rg)(1) == [5.0, 6.0] - (-[5.0, 6.0])
        @test CTModels.dual(sol_, ocp, :control_rg)(1) == 3.0 - (-3.0)
        @test CTModels.dual(sol_, ocp, :variable_rg) == [1.0, 2.0] - (-[1.0, 2.0])
    end
end
