module TestOCPModelTypes

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_ocp_model_types()
    Test.@testset "OCP Model Types Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for OCP model types functionality
        end

        # ====================================================================
        # UNIT TESTS - Core OCP Model Types
        # ====================================================================

        Test.@testset "Model and PreModel hierarchy" begin
            Test.@test isabstracttype(CTModels.AbstractModel)
            Test.@test CTModels.Model <: CTModels.AbstractModel
            Test.@test CTModels.PreModel <: CTModels.AbstractModel
        end

        Test.@testset "__is_* predicates on Model" begin
            times = CTModels.TimesModel(
                CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = CTModels.StateModel("x", ["x"])
            control = CTModels.ControlModel("u", ["u"])
            variable = CTModels.VariableModel("v", ["v"])
            dynamics = (r, t, x, u, v) -> nothing
            objective = CTModels.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)
            constraints = CTModels.ConstraintsModel((), (), (), (), ())
            definition = CTModels.EmptyDefinition()
            build_examodel = nothing

            ocp = CTModels.Model{CTModels.Autonomous}(
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

            # Type parameters should follow the concrete component types
            Test.@test ocp isa CTModels.Model{
                CTModels.Autonomous,
                typeof(times),
                typeof(state),
                typeof(control),
                typeof(variable),
                typeof(dynamics),
                typeof(objective),
                typeof(constraints),
                typeof(definition),
                typeof(build_examodel),
            }

            Test.@test CTModels.OCP.__is_times_set(ocp)
            Test.@test CTModels.OCP.__is_state_set(ocp)
            Test.@test CTModels.OCP.__is_control_set(ocp)
            Test.@test CTModels.OCP.__is_variable_set(ocp)
            Test.@test CTModels.OCP.__is_dynamics_set(ocp)
            Test.@test CTModels.OCP.__is_objective_set(ocp)
            Test.@test CTModels.OCP.__is_definition_set(ocp)
        end

        Test.@testset "__is_* predicates on PreModel" begin
            ocp = CTModels.PreModel()

            # Fresh PreModel should be empty
            Test.@test CTModels.OCP.__is_empty(ocp)
            Test.@test !CTModels.OCP.__is_times_set(ocp)
            Test.@test !CTModels.OCP.__is_state_set(ocp)
            Test.@test !CTModels.OCP.__is_control_set(ocp)
            Test.@test !CTModels.OCP.__is_dynamics_set(ocp)
            Test.@test !CTModels.OCP.__is_objective_set(ocp)
            Test.@test !CTModels.OCP.__is_definition_set(ocp)

            times = CTModels.TimesModel(
                CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = CTModels.StateModel("x", ["x"])
            control = CTModels.ControlModel("u", ["u"])
            variable = CTModels.VariableModel("v", ["v"])
            dynamics = (r, t, x, u, v) -> nothing
            objective = CTModels.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)

            ocp.times = times
            ocp.state = state
            ocp.control = control
            ocp.variable = variable
            ocp.dynamics = dynamics
            ocp.objective = objective
            ocp.autonomous = true

            Test.@test CTModels.OCP.__is_times_set(ocp)
            Test.@test CTModels.OCP.__is_state_set(ocp)
            Test.@test CTModels.OCP.__is_control_set(ocp)
            Test.@test CTModels.OCP.__is_variable_set(ocp)
            Test.@test CTModels.OCP.__is_dynamics_set(ocp)
            Test.@test CTModels.OCP.__is_objective_set(ocp)
            Test.@test CTModels.OCP.__is_autonomous_set(ocp)

            # definition is optional: model is complete without it
            Test.@test CTModels.OCP.__is_consistent(ocp)
            Test.@test CTModels.OCP.__is_complete(ocp)

            ocp.definition = CTModels.Definition(quote end)

            Test.@test CTModels.OCP.__is_definition_set(ocp)
            Test.@test CTModels.OCP.__is_complete(ocp)
            Test.@test !CTModels.OCP.__is_empty(ocp)
        end

        # ========================================================================
        # Integration-style tests – fake buildability check
        # ========================================================================

        Test.@testset "fake PreModel buildability" begin
            function can_build(ocp_local)
                return CTModels.OCP.__is_complete(ocp_local)
            end

            empty_ocp = CTModels.PreModel()
            Test.@test !can_build(empty_ocp)

            times = CTModels.TimesModel(
                CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = CTModels.StateModel("x", ["x"])
            control = CTModels.ControlModel("u", ["u"])
            variable = CTModels.VariableModel("v", ["v"])
            dynamics = (r, t, x, u, v) -> nothing
            objective = CTModels.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)

            ocp = CTModels.PreModel()
            ocp.times = times
            ocp.state = state
            ocp.control = control
            ocp.variable = variable
            ocp.dynamics = dynamics
            ocp.objective = objective
            ocp.definition = CTModels.Definition(quote end)
            ocp.autonomous = true

            Test.@test can_build(ocp)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ocp_model_types() = TestOCPModelTypes.test_ocp_model_types()
