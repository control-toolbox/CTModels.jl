module TestOCPSolution

using Test
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_solution()
    Test.@testset "Solution" verbose = VERBOSE showtiming = SHOWTIMING begin

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
        CTModels.time_dependence!(pre_ocp; autonomous=false)
        ocp = CTModels.build(pre_ocp)

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
        status = :status
        successful = true
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
            :status => status,
            :successful => successful,
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
        @testset "model" begin
            @test CTModels.model(sol) isa CTModels.Model
            @test CTModels.model(sol) === ocp
        end
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
            P_ = t -> 10.0 .+ 2 * [t, t]
            sol_ = CTModels.build_solution(ocp, T, X, U, v, P_; kwargs...)
            @test CTModels.costate(sol_)(1) == [12.0, 12.0]
        end
        @testset "time" begin
            @test CTModels.time_name(sol) == "s"
            @test CTModels.initial_time_name(sol) == "0.0"
            @test CTModels.final_time_name(sol) == "1.0"
            @test CTModels.time_grid(sol) == [0.0, 0.5, 1.0]
            @test CTModels.times(sol) isa CTModels.TimesModel
            @test CTModels.initial_time(CTModels.times(sol)) == 0
            @test CTModels.final_time(CTModels.times(sol)) == 1
            # Test direct time getters on solution
            @test CTModels.initial_time(sol) == 0
            @test CTModels.final_time(sol) == 1
            @test CTModels.has_fixed_initial_time(sol) == true
            @test CTModels.has_free_initial_time(sol) == false
            @test CTModels.has_fixed_final_time(sol) == true
            @test CTModels.has_free_final_time(sol) == false
        end
        @testset "infos" begin
            @test CTModels.objective(sol) == 0.5
            @test CTModels.iterations(sol) == 10
            @test CTModels.constraints_violation(sol) == 12.0
            @test CTModels.message(sol) == "message"
            @test CTModels.status(sol) == :status
            @test CTModels.successful(sol) == true
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
            path_constraints_dual_func = t -> [1.0 + 4.0 * t, 2.0 + 4.0 * t]
            sol_ = CTModels.build_solution(
                ocp, T, X, U, v, P; kwargs..., path_constraints_dual=path_constraints_dual
            )
            @test CTModels.path_constraints_dual(sol_)(1) == [5.0, 6.0]
            sol_ = CTModels.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                path_constraints_dual=path_constraints_dual_func,
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
        @testset "dimension helpers" begin
            # Test dim_path_constraints_nl
            @test CTModels.dim_path_constraints_nl(sol) == 0  # no path constraints
            path_constraints_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            sol_pc = CTModels.build_solution(
                ocp, T, X, U, v, P; kwargs..., path_constraints_dual=path_constraints_dual
            )
            @test CTModels.dim_path_constraints_nl(sol_pc) == 2  # 2 path constraints

            # Test dim_boundary_constraints_nl
            @test CTModels.dim_boundary_constraints_nl(sol) == 0  # no boundary constraints
            boundary_constraints_dual = [3.0, 2.0, 1.0]
            sol_bc = CTModels.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                boundary_constraints_dual=boundary_constraints_dual,
            )
            @test CTModels.dim_boundary_constraints_nl(sol_bc) == 3  # 3 boundary constraints

            # Test dim_variable_constraints_box
            @test CTModels.dim_variable_constraints_box(sol) == 0  # no variable constraints
            variable_constraints_lb_dual = [1.0, 2.0]
            sol_vc = CTModels.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                variable_constraints_lb_dual=variable_constraints_lb_dual,
            )
            @test CTModels.dim_variable_constraints_box(sol_vc) == 2  # 2 variable constraints

            # Test dim_state_constraints_box
            @test CTModels.dim_state_constraints_box(sol) == 0  # no state constraints
            state_constraints_lb_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            sol_sc = CTModels.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                state_constraints_lb_dual=state_constraints_lb_dual,
            )
            @test CTModels.dim_state_constraints_box(sol_sc) == 2  # 2 state constraints (dim_x = 2)

            # Test dim_control_constraints_box
            @test CTModels.dim_control_constraints_box(sol) == 0  # no control constraints
            control_constraints_lb_dual = zeros(3, 1)
            control_constraints_lb_dual[:, 1] = [1.0, 2.0, 3.0]
            sol_cc = CTModels.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                control_constraints_lb_dual=control_constraints_lb_dual,
            )
            @test CTModels.dim_control_constraints_box(sol_cc) == 1  # 1 control constraint (dim_u = 1)
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

        # ========================================================================
        # Closure independence tests (Phase 3: deepcopy removal validation)
        # ========================================================================
        @testset "Closure independence (deepcopy validation)" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            # Test 1: Multiple solutions from same data should be independent
            T1 = [0.0, 0.5, 1.0]
            X1 = [0.0 0.0; 0.5 0.5; 1.0 1.0]
            U1 = [1.0; 2.0; 3.0;;]
            v1 = [10.0, 11.0]
            P1 = [10.0 10.0; 11.0 11.0]

            sol1 = CTModels.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)
            sol2 = CTModels.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)

            # Both solutions should produce identical results
            @test CTModels.state(sol1)(0.5) == CTModels.state(sol2)(0.5)
            @test CTModels.control(sol1)(0.5) == CTModels.control(sol2)(0.5)
            @test CTModels.costate(sol1)(0.5) == CTModels.costate(sol2)(0.5)

            # Test 2: Solutions should remain independent after creation
            # (modifying source data should not affect already-created solutions)
            X2 = copy(X1)
            sol3 = CTModels.build_solution(ocp, T1, X2, U1, v1, P1; kwargs...)
            X2[2, 1] = 999.0  # Modify source after solution creation

            # Solution should still have original values
            @test CTModels.state(sol3)(0.5) == [0.5, 0.5]  # Not affected by X2 modification

            # Test 3: Scalar extraction for 1D control (critical deepcopy case)
            # The existing ocp has 1D control, which tests the scalar extraction path
            sol3a = CTModels.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)
            sol3b = CTModels.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)

            # Control is 1D, so should return scalar (not vector)
            @test CTModels.control(sol3a)(0.5) isa Real  # Scalar output
            @test CTModels.control(sol3a)(0.5) == CTModels.control(sol3b)(0.5)

            # State is 2D, so should return vector
            @test CTModels.state(sol3a)(0.5) isa AbstractVector
            @test length(CTModels.state(sol3a)(0.5)) == 2

            # Test 4: Function-based inputs with parameter modification
            # This tests that closures properly capture values, not references
            param_x = 1.0
            param_u = 2.0
            param_p = 10.0

            X_func = t -> [param_x * t, param_x * t]
            U_func = t -> [param_u * t]
            P_func = t -> [param_p + t, param_p + t]

            sol_func = CTModels.build_solution(
                ocp, T1, X_func, U_func, v1, P_func; kwargs...
            )

            # Verify initial values
            @test CTModels.state(sol_func)(0.5) == [0.5, 0.5]
            @test CTModels.control(sol_func)(0.5) == 1.0
            @test CTModels.costate(sol_func)(0.5) == [10.5, 10.5]

            # Modify parameters AFTER solution creation
            param_x = 999.0
            param_u = 999.0
            param_p = 999.0

            # Solution should still use original parameter values
            # (closures capture the values at creation time)
            @test CTModels.state(sol_func)(0.5) == [0.5, 0.5]  # NOT [499.5, 499.5]
            @test CTModels.control(sol_func)(0.5) == 1.0  # NOT 499.5
            @test CTModels.costate(sol_func)(0.5) == [10.5, 10.5]  # NOT [999.5, 999.5]

            # Test 5: Multiple evaluations should give consistent results
            state_fun = CTModels.state(sol1)
            results = [state_fun(0.5) for _ in 1:10]
            @test all(r == results[1] for r in results)

            # Test 6: Verify closure independence across different time evaluations
            # This ensures that the closure doesn't have unexpected side effects
            t_values = [0.0, 0.25, 0.5, 0.75, 1.0]
            state_results = [CTModels.state(sol1)(t) for t in t_values]
            control_results = [CTModels.control(sol1)(t) for t in t_values]

            # Re-evaluate at same points - should get identical results
            state_results_2 = [CTModels.state(sol1)(t) for t in t_values]
            control_results_2 = [CTModels.control(sol1)(t) for t in t_values]

            @test all(state_results[i] == state_results_2[i] for i in 1:length(t_values))
            @test all(
                control_results[i] == control_results_2[i] for i in 1:length(t_values)
            )
        end
    end
end

end # module

test_solution() = TestOCPSolution.test_solution()
