module TestComponents

import Test: Test
import CTModels.Components: Components

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_components()
    Test.@testset "OCP Components Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - OCP Components
        # ====================================================================
        Test.@testset "state/control/variable models" begin
            state = Components.StateModel("y", ["u", "v"])
            Test.@test Components.dimension(state) == 2
            Test.@test Components.name(state) == "y"
            Test.@test Components.components(state) == ["u", "v"]

            control = Components.ControlModel("u", ["u₁", "u₂"])
            Test.@test Components.dimension(control) == 2
            Test.@test Components.name(control) == "u"
            Test.@test Components.components(control) == ["u₁", "u₂"]

            variable = Components.VariableModel("v", ["v₁", "v₂"])
            Test.@test Components.dimension(variable) == 2
            Test.@test Components.name(variable) == "v"
            Test.@test Components.components(variable) == ["v₁", "v₂"]
        end

        Test.@testset "time models" begin
            Test.@test isabstracttype(Components.AbstractTimeModel)

            t0 = Components.FixedTimeModel(0.0, "t₀")
            tf = Components.FixedTimeModel(1.0, "t_f")
            Test.@test t0.time == 0.0
            Test.@test t0.name == "t₀"
            Test.@test tf.time == 1.0
            Test.@test tf.name == "t_f"

            free_t0 = Components.FreeTimeModel(1, "t₀")
            free_tf = Components.FreeTimeModel(2, "t_f")
            Test.@test free_t0.index == 1
            Test.@test free_t0.name == "t₀"
            Test.@test free_tf.index == 2
            Test.@test free_tf.name == "t_f"

            times = Components.TimesModel(t0, tf, "t")
            Test.@test times.initial === t0
            Test.@test times.final === tf
            Test.@test times.time_name == "t"
        end

        Test.@testset "objective and constraints models" begin
            mayer_f = (x0, xf, v) -> x0[1] + xf[1]
            lagrange_f = (t, x, u, v) -> u[1]^2

            mayer = Components.MayerObjectiveModel(mayer_f, :min)
            lagrange = Components.LagrangeObjectiveModel(lagrange_f, :max)
            bolza = Components.BolzaObjectiveModel(mayer_f, lagrange_f, :min)

            Test.@test mayer.criterion == :min
            Test.@test lagrange.criterion == :max
            Test.@test bolza.criterion == :min

            # Simple construction of an empty ConstraintsModel
            constraints = Components.ConstraintsModel((), (), (), (), ())
            Test.@test constraints.path_nl == ()
            Test.@test constraints.boundary_nl == ()
            Test.@test constraints.state_box == ()
            Test.@test constraints.control_box == ()
            Test.@test constraints.variable_box == ()
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_components() = TestComponents.test_components()
