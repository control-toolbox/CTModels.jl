module TestOCPSolution

import Test: Test
import CTModels.Components: Components
import CTModels.Building: Building
import CTModels.Models: Models
import CTModels.Solutions: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_solution()
    Test.@testset "Solution Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Solution Functionality
        # ====================================================================

        # create an ocp
        pre_ocp = Building.PreModel()
        Building.time!(pre_ocp; t0=0.0, tf=1.0, time_name=:s)
        Building.state!(pre_ocp, 2, "y", ["u", "v"])
        Building.control!(pre_ocp, 1, "w")
        Building.variable!(pre_ocp, 2, "z", ["a", "b"])
        dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
        Building.dynamics!(pre_ocp, dynamics!) # does not correspond to the solution
        mayer(x0, xf, v) = x0[1] + xf[1]
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        Building.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange) # does not correspond to the solution
        f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
        f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
        f_variable(r, t, v) = r .= v .+ t
        Building.constraint!(pre_ocp, :path; f=f_path, lb=[0, 1], ub=[1, 2], label=:path)
        Building.constraint!(
            pre_ocp, :boundary; f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary
        )
        Building.constraint!(pre_ocp, :state; rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
        Building.constraint!(pre_ocp, :control; rg=1:1, lb=[0], ub=[1], label=:control_rg)
        Building.constraint!(
            pre_ocp, :variable; rg=1:2, lb=[0, 1], ub=[1, 2], label=:variable_rg
        )
        Building.definition!(pre_ocp, quote end)
        Building.time_dependence!(pre_ocp; autonomous=false)
        ocp = Building.build(pre_ocp)

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
        sol = Solutions.build_solution(ocp, T, X, U, v, P; kwargs...)

        # call getters and check the values
        Test.@testset "model" begin
            Test.@test Solutions.model(sol) isa Models.Model
            Test.@test Solutions.model(sol) === ocp
        end
        Test.@testset "state" begin
            Test.@test Models.state_dimension(sol) == 2
            Test.@test Models.state_name(sol) == "y"
            Test.@test Models.state_components(sol) == ["u", "v"]
            Test.@test Models.state(sol)(1) == [1.0, 1.0]
            Test.@test Models.state(sol)(0.4) == [0.4, 0.4] # linear interpolation
            X_ = t -> [t, t]
            sol_ = Solutions.build_solution(ocp, T, X_, U, v, P; kwargs...)
            Test.@test Models.state(sol_)(1) == [1.0, 1.0]
        end
        Test.@testset "control" begin
            Test.@test Models.control_dimension(sol) == 1
            Test.@test Models.control_name(sol) == "w"
            Test.@test Models.control_components(sol) == ["w"]
            Test.@test Models.control(sol)(1) == 3.0 # it is a scalar since the control dimension is 1
            U_ = t -> [3t]
            sol_ = Solutions.build_solution(ocp, T, X, U_, v, P; kwargs...)
            Test.@test Models.control(sol_)(1) == 3.0
        end
        Test.@testset "variable" begin
            Test.@test Models.variable_dimension(sol) == 2
            Test.@test Models.variable_name(sol) == "z"
            Test.@test Models.variable_components(sol) == ["a", "b"]
            Test.@test Models.variable(sol) == [10.0, 11.0]
        end
        Test.@testset "costate" begin
            Test.@test Solutions.costate(sol)(1) == [11.0, 11.0] # flat extrapolation (last value)
            P_ = [10.0 10.0; 11.0 11.0; 12.0 12.0] # test with 3 points
            sol_ = Solutions.build_solution(ocp, T, X, U, v, P_; kwargs...)
            Test.@test Solutions.costate(sol_)(1) == [12.0, 12.0]
            P_ = t -> 10.0 .+ 2 * [t, t]
            sol_ = Solutions.build_solution(ocp, T, X, U, v, P_; kwargs...)
            Test.@test Solutions.costate(sol_)(1) == [12.0, 12.0]
        end
        Test.@testset "time" begin
            Test.@test Components.time_name(sol) == "s"
            Test.@test Components.initial_time_name(sol) == "0.0"
            Test.@test Components.final_time_name(sol) == "1.0"
            Test.@test Solutions.time_grid(sol) == [0.0, 0.5, 1.0]
            Test.@test Models.times(sol) isa Components.TimesModel
            Test.@test Components.initial_time(Models.times(sol)) == 0
            Test.@test Components.final_time(Models.times(sol)) == 1
            # Test direct time getters on solution
            Test.@test Components.initial_time(sol) == 0
            Test.@test Components.final_time(sol) == 1
            Test.@test Components.has_fixed_initial_time(sol) == true
            Test.@test Components.has_free_initial_time(sol) == false
            Test.@test Components.has_fixed_final_time(sol) == true
            Test.@test Components.has_free_final_time(sol) == false
        end
        Test.@testset "infos" begin
            Test.@test Models.objective(sol) == 0.5
            Test.@test Solutions.iterations(sol) == 10
            Test.@test Solutions.constraints_violation(sol) == 12.0
            Test.@test Solutions.message(sol) == "message"
            Test.@test Solutions.status(sol) == :status
            Test.@test Solutions.successful(sol) == true
            Test.@test Solutions.infos(sol) == Dict()
        end
        Test.@testset "dual to constraints" begin
            Test.@test Solutions.path_constraints_dual(sol) === nothing
            Test.@test Solutions.boundary_constraints_dual(sol) === nothing
            Test.@test Solutions.state_constraints_lb_dual(sol) === nothing
            Test.@test Solutions.state_constraints_ub_dual(sol) === nothing
            Test.@test Solutions.control_constraints_lb_dual(sol) === nothing
            Test.@test Solutions.control_constraints_ub_dual(sol) === nothing
            Test.@test Solutions.variable_constraints_lb_dual(sol) === nothing
            Test.@test Solutions.variable_constraints_ub_dual(sol) === nothing
            # path constraints dual: matrix and function
            path_constraints_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            path_constraints_dual_func = t -> [1.0 + 4.0 * t, 2.0 + 4.0 * t]
            sol_ = Solutions.build_solution(
                ocp, T, X, U, v, P; kwargs..., path_constraints_dual=path_constraints_dual
            )
            Test.@test Solutions.path_constraints_dual(sol_)(1) == [5.0, 6.0]
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                path_constraints_dual=path_constraints_dual_func,
            )
            Test.@test Solutions.path_constraints_dual(sol_)(1) == [5.0, 6.0]
            # boundary constraints dual: vector
            boundary_constraints_dual = [3.0, 2.0]
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                boundary_constraints_dual=boundary_constraints_dual,
            )
            Test.@test Solutions.boundary_constraints_dual(sol_) == [3.0, 2.0]
            # state constraints lower bounds dual: matrix
            state_constraints_lb_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                state_constraints_lb_dual=state_constraints_lb_dual,
            )
            Test.@test Solutions.state_constraints_lb_dual(sol_)(1) == [5.0, 6.0]
            # state constraints upper bounds dual: matrix
            state_constraints_ub_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                state_constraints_ub_dual=state_constraints_ub_dual,
            )
            Test.@test Solutions.state_constraints_ub_dual(sol_)(1) == [5.0, 6.0]
            # control constraints lower bounds dual: matrix
            ccld = zeros(3, 1)
            ccld[:, 1] = [1.0, 2.0, 3.0]
            control_constraints_lb_dual = ccld
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                control_constraints_lb_dual=control_constraints_lb_dual,
            )
            Test.@test Solutions.control_constraints_lb_dual(sol_)(1) == 3.0
            # control constraints upper bounds dual: matrix
            control_constraints_ub_dual = ccld
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                control_constraints_ub_dual=control_constraints_ub_dual,
            )
            Test.@test Solutions.control_constraints_ub_dual(sol_)(1) == 3.0
            # variable constraints lower bounds dual: vector
            variable_constraints_lb_dual = [1.0, 2.0]
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                variable_constraints_lb_dual=variable_constraints_lb_dual,
            )
            Test.@test Solutions.variable_constraints_lb_dual(sol_) == [1.0, 2.0]
            # variable constraints upper bounds dual: vector
            variable_constraints_ub_dual = [1.0, 2.0]
            sol_ = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                variable_constraints_ub_dual=variable_constraints_ub_dual,
            )
            Test.@test Solutions.variable_constraints_ub_dual(sol_) == [1.0, 2.0]
        end
        Test.@testset "dimension helpers" begin
            # Test dim_path_constraints_nl
            Test.@test Components.dim_path_constraints_nl(sol) == 0  # no path constraints
            path_constraints_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            sol_pc = Solutions.build_solution(
                ocp, T, X, U, v, P; kwargs..., path_constraints_dual=path_constraints_dual
            )
            Test.@test Components.dim_path_constraints_nl(sol_pc) == 2  # 2 path constraints

            # Test dim_boundary_constraints_nl
            Test.@test Components.dim_boundary_constraints_nl(sol) == 0  # no boundary constraints
            boundary_constraints_dual = [3.0, 2.0, 1.0]
            sol_bc = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                boundary_constraints_dual=boundary_constraints_dual,
            )
            Test.@test Components.dim_boundary_constraints_nl(sol_bc) == 3  # 3 boundary constraints

            # Test dim_dual_variable_constraints_box
            Test.@test Solutions.dim_dual_variable_constraints_box(sol) == 0  # no variable duals
            variable_constraints_lb_dual = [1.0, 2.0]
            sol_vc = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                variable_constraints_lb_dual=variable_constraints_lb_dual,
            )
            Test.@test Solutions.dim_dual_variable_constraints_box(sol_vc) == 2  # 2 variable duals

            # Test dim_dual_state_constraints_box
            Test.@test Solutions.dim_dual_state_constraints_box(sol) == 0  # no state duals
            state_constraints_lb_dual = [1.0 2.0; 3.0 4.0; 5.0 6.0]
            sol_sc = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                state_constraints_lb_dual=state_constraints_lb_dual,
            )
            Test.@test Solutions.dim_dual_state_constraints_box(sol_sc) == 2  # 2 state duals (dim_x = 2)

            # Test dim_dual_control_constraints_box
            Test.@test Solutions.dim_dual_control_constraints_box(sol) == 0  # no control duals
            control_constraints_lb_dual = zeros(3, 1)
            control_constraints_lb_dual[:, 1] = [1.0, 2.0, 3.0]
            sol_cc = Solutions.build_solution(
                ocp,
                T,
                X,
                U,
                v,
                P;
                kwargs...,
                control_constraints_lb_dual=control_constraints_lb_dual,
            )
            Test.@test Solutions.dim_dual_control_constraints_box(sol_cc) == 1  # 1 control dual (dim_u = 1)
        end
        Test.@testset "dual from label" begin
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
            sol_ = Solutions.build_solution(
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
            Test.@test Solutions.dual(sol_, ocp, :path)(1) == [5.0, 6.0]
            Test.@test Solutions.dual(sol_, ocp, :boundary) == [3.0, 2.0]
            Test.@test Solutions.dual(sol_, ocp, :state_rg)(1) == [5.0, 6.0] - (-[5.0, 6.0])
            Test.@test Solutions.dual(sol_, ocp, :control_rg)(1) == 3.0 - (-3.0)
            Test.@test Solutions.dual(sol_, ocp, :variable_rg) == [1.0, 2.0] - (-[1.0, 2.0])
        end

        # ========================================================================
        # Closure independence tests (Phase 3: deepcopy removal validation)
        # ========================================================================
        Test.@testset "Closure independence (deepcopy validation)" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            # Test 1: Multiple solutions from same data should be independent
            T1 = [0.0, 0.5, 1.0]
            X1 = [0.0 0.0; 0.5 0.5; 1.0 1.0]
            U1 = [1.0; 2.0; 3.0;;]
            v1 = [10.0, 11.0]
            P1 = [10.0 10.0; 11.0 11.0]

            sol1 = Solutions.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)
            sol2 = Solutions.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)

            # Both solutions should produce identical results
            Test.@test Models.state(sol1)(0.5) == Models.state(sol2)(0.5)
            Test.@test Models.control(sol1)(0.5) == Models.control(sol2)(0.5)
            Test.@test Solutions.costate(sol1)(0.5) == Solutions.costate(sol2)(0.5)

            # Test 2: Solutions should remain independent after creation
            # (modifying source data should not affect already-created solutions)
            X2 = copy(X1)
            sol3 = Solutions.build_solution(ocp, T1, X2, U1, v1, P1; kwargs...)
            X2[2, 1] = 999.0  # Modify source after solution creation

            # Solution should still have original values
            Test.@test Models.state(sol3)(0.5) == [0.5, 0.5]  # Not affected by X2 modification

            # Test 3: Scalar extraction for 1D control (critical deepcopy case)
            # The existing ocp has 1D control, which tests the scalar extraction path
            sol3a = Solutions.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)
            sol3b = Solutions.build_solution(ocp, T1, X1, U1, v1, P1; kwargs...)

            # Control is 1D, so should return scalar (not vector)
            Test.@test Models.control(sol3a)(0.5) isa Real  # Scalar output
            Test.@test Models.control(sol3a)(0.5) == Models.control(sol3b)(0.5)

            # State is 2D, so should return vector
            Test.@test Models.state(sol3a)(0.5) isa AbstractVector
            Test.@test length(Models.state(sol3a)(0.5)) == 2

            # Test 4: Function-based inputs with parameter modification
            # This tests that closures properly capture values, not references
            param_x = 1.0
            param_u = 2.0
            param_p = 10.0

            X_func = t -> [param_x * t, param_x * t]
            U_func = t -> [param_u * t]
            P_func = t -> [param_p + t, param_p + t]

            sol_func = Solutions.build_solution(
                ocp, T1, X_func, U_func, v1, P_func; kwargs...
            )

            # Verify initial values
            Test.@test Models.state(sol_func)(0.5) == [0.5, 0.5]
            Test.@test Models.control(sol_func)(0.5) == 1.0
            Test.@test Solutions.costate(sol_func)(0.5) == [10.5, 10.5]

            # Modify parameters AFTER solution creation
            param_x = 999.0
            param_u = 999.0
            param_p = 999.0

            # Solution should still use original parameter values
            # (closures capture the values at creation time)
            Test.@test Models.state(sol_func)(0.5) == [0.5, 0.5]  # NOT [499.5, 499.5]
            Test.@test Models.control(sol_func)(0.5) == 1.0  # NOT 499.5
            Test.@test Solutions.costate(sol_func)(0.5) == [10.5, 10.5]  # NOT [999.5, 999.5]

            # Test 5: Multiple evaluations should give consistent results
            state_fun = Models.state(sol1)
            results = [state_fun(0.5) for _ in 1:10]
            Test.@test all(r == results[1] for r in results)

            # Test 6: Verify closure independence across different time evaluations
            # This ensures that the closure doesn't have unexpected side effects
            t_values = [0.0, 0.25, 0.5, 0.75, 1.0]
            state_results = [Models.state(sol1)(t) for t in t_values]
            control_results = [Models.control(sol1)(t) for t in t_values]

            # Re-evaluate at same points - should get identical results
            state_results_2 = [Models.state(sol1)(t) for t in t_values]
            control_results_2 = [Models.control(sol1)(t) for t in t_values]

            Test.@test all(
                state_results[i] == state_results_2[i] for i in 1:length(t_values)
            )
            Test.@test all(
                control_results[i] == control_results_2[i] for i in 1:length(t_values)
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_solution() = TestOCPSolution.test_solution()
