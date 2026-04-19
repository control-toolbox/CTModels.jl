module TestOCPSolutionTypes

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_ocp_solution_types()
    Test.@testset "OCP Solution Types Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for OCP solution types functionality
        end

        # ====================================================================
        # UNIT TESTS - Core Solution Types
        # ====================================================================

        Test.@testset "TimeGridModel and is_empty" begin
            grid = CTModels.TimeGridModel([0.0, 0.5, 1.0])
            empty_grid = CTModels.EmptyTimeGridModel()

            Test.@test CTModels.is_empty(empty_grid)
            Test.@test !CTModels.is_empty(grid)
        end

        Test.@testset "SolverInfos structure" begin
            extra_infos = Dict(:foo => 1, :bar => "x")
            infos = CTModels.SolverInfos(10, :ok, "message", true, 1e-3, extra_infos)

            Test.@test infos.iterations == 10
            Test.@test infos.status == :ok
            Test.@test infos.message == "message"
            Test.@test infos.successful
            Test.@test infos.constraints_violation ≈ 1e-3
            Test.@test infos.infos === extra_infos
            Test.@test infos isa CTModels.AbstractSolverInfos
        end

        Test.@testset "DualModel structure" begin
            pc = t -> [1.0, 2.0]
            bc = [3.0, 4.0]
            sc_lb = t -> [0.0]
            sc_ub = t -> [1.0]
            cc_lb = t -> [0.0]
            cc_ub = t -> [1.0]
            vc_lb = [5.0]
            vc_ub = [6.0]

            dual = CTModels.DualModel(pc, bc, sc_lb, sc_ub, cc_lb, cc_ub, vc_lb, vc_ub)

            Test.@test dual.path_constraints_dual === pc
            Test.@test dual.boundary_constraints_dual === bc
            Test.@test dual.state_constraints_lb_dual === sc_lb
            Test.@test dual.state_constraints_ub_dual === sc_ub
            Test.@test dual.control_constraints_lb_dual === cc_lb
            Test.@test dual.control_constraints_ub_dual === cc_ub
            Test.@test dual.variable_constraints_lb_dual === vc_lb
            Test.@test dual.variable_constraints_ub_dual === vc_ub
        end

        Test.@testset "Solution structure and empty time grid" begin
            times = CTModels.TimesModel(
                CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = CTModels.StateModel("x", ["x"])
            control = CTModels.ControlModel("u", ["u"])
            variable = CTModels.VariableModel("v", ["v"])

            costate_fun = t -> [0.0]
            objective_val = 0.0

            dual = CTModels.DualModel(
                nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing
            )

            infos = CTModels.SolverInfos(0, :unknown, "", false, 0.0, Dict{Symbol,Any}())

            dynamics = (r, t, x, u, v) -> nothing
            objective = CTModels.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)
            constraints = CTModels.ConstraintsModel((), (), (), (), ())
            definition = CTModels.OCP.EmptyDefinition()
            build_examodel = nothing

            model = CTModels.Model{CTModels.Autonomous}(
                times,
                state,
                control,
                variable,
                dynamics,
                objective,
                constraints,
                definition,
                build_examodel,
            )

            grid_full = CTModels.TimeGridModel([0.0, 0.5, 1.0])
            grid_empty = CTModels.EmptyTimeGridModel()

            sol_full = CTModels.Solution(
                grid_full,
                times,
                state,
                control,
                variable,
                model,
                costate_fun,
                objective_val,
                dual,
                infos,
            )

            sol_empty = CTModels.Solution(
                grid_empty,
                times,
                state,
                control,
                variable,
                model,
                costate_fun,
                objective_val,
                dual,
                infos,
            )

            # Type parameters should reflect the underlying component types
            Test.@test sol_full isa CTModels.Solution{
                typeof(grid_full),
                typeof(times),
                typeof(state),
                typeof(control),
                typeof(variable),
                typeof(model),
                typeof(costate_fun),
                typeof(objective_val),
                typeof(dual),
                typeof(infos),
            }

            Test.@test sol_empty isa CTModels.Solution{
                typeof(grid_empty),
                typeof(times),
                typeof(state),
                typeof(control),
                typeof(variable),
                typeof(model),
                typeof(costate_fun),
                typeof(objective_val),
                typeof(dual),
                typeof(infos),
            }

            Test.@test !CTModels.is_empty_time_grid(sol_full)
            Test.@test CTModels.is_empty_time_grid(sol_empty)
        end

        # ========================================================================
        # Integration-style tests – fake post-processing of a Solution
        # ========================================================================

        Test.@testset "fake Solution summary" begin
            times = CTModels.TimesModel(
                CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = CTModels.StateModel("x", ["x"])
            control = CTModels.ControlModel("u", ["u"])
            variable = CTModels.VariableModel("v", ["v"])

            costate_fun = t -> [0.0]
            objective_val = 42.0

            dual = CTModels.DualModel(
                nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing
            )

            infos = CTModels.SolverInfos(15, :converged, "ok", true, 0.0, Dict(:nit => 15))

            dynamics = (r, t, x, u, v) -> nothing
            objective = CTModels.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)
            constraints = CTModels.ConstraintsModel((), (), (), (), ())
            definition = CTModels.OCP.EmptyDefinition()
            build_examodel = nothing

            model = CTModels.Model{CTModels.Autonomous}(
                times,
                state,
                control,
                variable,
                dynamics,
                objective,
                constraints,
                definition,
                build_examodel,
            )

            grid = CTModels.TimeGridModel([0.0, 1.0])
            sol = CTModels.Solution(
                grid,
                times,
                state,
                control,
                variable,
                model,
                costate_fun,
                objective_val,
                dual,
                infos,
            )

            function extract_summary(sol_local)
                return (
                    iterations=sol_local.solver_infos.iterations,
                    status=sol_local.solver_infos.status,
                    objective=sol_local.objective,
                )
            end

            summary = extract_summary(sol)

            Test.@test summary.iterations == 15
            Test.@test summary.status == :converged
            Test.@test summary.objective == 42.0
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ocp_solution_types() = TestOCPSolutionTypes.test_ocp_solution_types()
