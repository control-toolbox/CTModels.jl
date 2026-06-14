module TestModelTypes

import Test: Test
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_model_types()
    Test.@testset "OCP Model Types Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Core OCP Model Types
        # ====================================================================

        Test.@testset "Model and PreModel hierarchy" begin
            Test.@test isabstracttype(Models.AbstractModel)
            Test.@test Models.Model <: Models.AbstractModel
            Test.@test Building.PreModel <: Models.AbstractModel
        end

        Test.@testset "__is_* predicates on Model" begin
            times = Components.TimesModel(
                Components.FixedTimeModel(0.0, "t₀"), Components.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = Components.StateModel("x", ["x"])
            control = Components.ControlModel("u", ["u"])
            variable = Components.VariableModel("v", ["v"])
            dynamics = (r, t, x, u, v) -> nothing
            objective = Components.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)
            constraints = Components.ConstraintsModel((), (), (), (), ())
            definition = Components.EmptyDefinition()
            build_examodel = nothing

            ocp = Models.Model{Components.Autonomous}(
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
            Test.@test ocp isa Models.Model{
                Components.Autonomous,
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

            Test.@test !Building.__is_control_empty(ocp.control)
            Test.@test !Building.__is_variable_empty(ocp.variable)
            Test.@test Building.__is_definition_empty(ocp.definition)
        end

        Test.@testset "__is_* predicates on PreModel" begin
            ocp = Building.PreModel()

            # Fresh PreModel should be empty
            Test.@test Building.__is_empty(ocp)
            Test.@test !Building.__is_times_set(ocp)
            Test.@test !Building.__is_state_set(ocp)
            Test.@test Building.__is_control_empty(ocp)
            Test.@test !Building.__is_dynamics_set(ocp)
            Test.@test !Building.__is_objective_set(ocp)
            Test.@test Building.__is_definition_empty(ocp)

            times = Components.TimesModel(
                Components.FixedTimeModel(0.0, "t₀"), Components.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = Components.StateModel("x", ["x"])
            control = Components.ControlModel("u", ["u"])
            variable = Components.VariableModel("v", ["v"])
            dynamics = (r, t, x, u, v) -> nothing
            objective = Components.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)

            ocp.times = times
            ocp.state = state
            ocp.control = control
            ocp.variable = variable
            ocp.dynamics = dynamics
            ocp.objective = objective
            ocp.autonomous = true

            Test.@test Building.__is_times_set(ocp)
            Test.@test Building.__is_state_set(ocp)
            Test.@test !Building.__is_control_empty(ocp)
            Test.@test !Building.__is_variable_empty(ocp)
            Test.@test Building.__is_dynamics_set(ocp)
            Test.@test Building.__is_objective_set(ocp)
            Test.@test Building.__is_autonomous_set(ocp)

            # definition is optional: model is consistent without it
            Test.@test Building.__is_consistent(ocp)

            ocp.definition = Components.Definition(quote end)

            Test.@test !Building.__is_definition_empty(ocp)
            Test.@test Building.__is_consistent(ocp)
            Test.@test !Building.__is_empty(ocp)
        end

        # ========================================================================
        # Integration-style tests – fake buildability check
        # ========================================================================

        Test.@testset "fake PreModel buildability" begin
            function can_build(ocp_local)
                return Building.__is_consistent(ocp_local)
            end

            empty_ocp = Building.PreModel()
            Test.@test !can_build(empty_ocp)

            times = Components.TimesModel(
                Components.FixedTimeModel(0.0, "t₀"), Components.FixedTimeModel(1.0, "t_f"), "t"
            )
            state = Components.StateModel("x", ["x"])
            control = Components.ControlModel("u", ["u"])
            variable = Components.VariableModel("v", ["v"])
            dynamics = (r, t, x, u, v) -> nothing
            objective = Components.MayerObjectiveModel((x0, xf, v) -> 0.0, :min)

            ocp = Building.PreModel()
            ocp.times = times
            ocp.state = state
            ocp.control = control
            ocp.variable = variable
            ocp.dynamics = dynamics
            ocp.objective = objective
            ocp.definition = Components.Definition(quote end)
            ocp.autonomous = true

            Test.@test can_build(ocp)
        end

        # ========================================================================
        # User-Facing Predicates
        # ========================================================================

        Test.@testset "User-Facing Predicates" begin
            dyn!(r, t, x, u, v) = r .= 0
            mayer_fn(x0, xf, v) = 0.0

            function build_model(;
                with_variable=false,
                with_control=true,
                autonomous=true,
                with_definition=false,
            )
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 2)
                with_control && Building.control!(ocp, 1)
                with_variable && Building.variable!(ocp, 1)
                Building.dynamics!(ocp, dyn!)
                Building.objective!(ocp, :min; mayer=mayer_fn)
                with_definition && Building.definition!(ocp, :(ẋ = Ax + Bu))
                Building.time_dependence!(ocp; autonomous=autonomous)
                return Building.build(ocp)
            end

            Test.@testset "has_variable / is_nonvariable" begin
                model = build_model(with_variable=false)
                Test.@test !Models.has_variable(model)
                Test.@test Models.is_nonvariable(model)

                model2 = build_model(with_variable=true)
                Test.@test Models.has_variable(model2)
                Test.@test !Models.is_nonvariable(model2)
            end

            Test.@testset "has_control" begin
                model = build_model(with_control=false)
                Test.@test !Models.has_control(model)

                model2 = build_model(with_control=true)
                Test.@test Models.has_control(model2)
            end

            Test.@testset "is_nonautonomous" begin
                model = build_model(autonomous=true)
                Test.@test !Models.is_nonautonomous(model)

                model2 = build_model(autonomous=false)
                Test.@test Models.is_nonautonomous(model2)
            end

            Test.@testset "has_abstract_definition / is_abstractly_defined" begin
                model = build_model(with_definition=false)
                Test.@test !Models.has_abstract_definition(model)
                Test.@test !Models.is_abstractly_defined(model)

                model2 = build_model(with_definition=true)
                Test.@test Models.has_abstract_definition(model2)
                Test.@test Models.is_abstractly_defined(model2)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_model_types() = TestModelTypes.test_model_types()
