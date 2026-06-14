module TestOCPObjective

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_objective()
    Test.@testset "Objective Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Objective Models
        # ====================================================================

        # is concretetype
        Test.@test isconcretetype(Components.MayerObjectiveModel{Function})
        Test.@test isconcretetype(Components.LagrangeObjectiveModel{Function})
        Test.@test isconcretetype(Components.BolzaObjectiveModel{Function,Function})

        # Functions
        mayer(x0, xf, v) = x0 .+ xf .+ v
        lagrange(t, x, u, v) = t .+ x .+ u .+ v

        # MayerObjectiveModel
        objective = Components.MayerObjectiveModel(mayer, :min)
        Test.@test Components.mayer(objective) == mayer
        Test.@test Components.criterion(objective) == :min
        Test.@test Components.has_mayer_cost(objective) == true
        Test.@test Components.has_lagrange_cost(objective) == false

        # LagrangeObjectiveModel
        objective = Components.LagrangeObjectiveModel(lagrange, :max)
        Test.@test Components.lagrange(objective) == lagrange
        Test.@test Components.criterion(objective) == :max
        Test.@test Components.has_mayer_cost(objective) == false
        Test.@test Components.has_lagrange_cost(objective) == true

        # BolzaObjectiveModel
        objective = Components.BolzaObjectiveModel(mayer, lagrange, :min)
        Test.@test Components.mayer(objective) == mayer
        Test.@test Components.lagrange(objective) == lagrange
        Test.@test Components.criterion(objective) == :min
        Test.@test Components.has_mayer_cost(objective) == true
        Test.@test Components.has_lagrange_cost(objective) == true

        # from PreModel with Mayer objective
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Building.objective!(ocp, :min; mayer=mayer)
        Test.@test ocp.objective == Components.MayerObjectiveModel(mayer, :min)
        Test.@test Components.criterion(ocp.objective) == :min
        Test.@test Components.has_mayer_cost(ocp.objective) == true
        Test.@test Components.has_lagrange_cost(ocp.objective) == false

        # from PreModel with Lagrange objective
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Building.objective!(ocp, :max; lagrange=lagrange)
        Test.@test ocp.objective == Components.LagrangeObjectiveModel(lagrange, :max)
        Test.@test Components.criterion(ocp.objective) == :max
        Test.@test Components.has_mayer_cost(ocp.objective) == false
        Test.@test Components.has_lagrange_cost(ocp.objective) == true

        # from PreModel with Bolza objective
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Building.objective!(ocp; mayer=mayer, lagrange=lagrange) # default criterion is :min
        Test.@test ocp.objective == Components.BolzaObjectiveModel(mayer, lagrange, :min)
        Test.@test Components.criterion(ocp.objective) == :min
        Test.@test Components.has_mayer_cost(ocp.objective) == true
        Test.@test Components.has_lagrange_cost(ocp.objective) == true

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        # state not set
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.objective!(
            ocp, :min, mayer=mayer
        )

        # control is now optional - this should succeed
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.variable!(ocp, 1)
        Building.objective!(ocp, :min, mayer=mayer)
        Test.@test Building.__is_objective_set(ocp)

        # times not set
        ocp = Building.PreModel()
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.objective!(
            ocp, :min, mayer=mayer
        )

        # objective already set
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Building.objective!(ocp, :min; mayer=mayer)
        Test.@test_throws Exceptions.PreconditionError Building.objective!(
            ocp, :min, mayer=mayer
        )

        # variable set after the objective
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.objective!(ocp, :min; mayer=mayer)
        Test.@test_throws Exceptions.PreconditionError Building.variable!(ocp, 1)

        # no function given
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.IncorrectArgument Building.objective!(ocp, :min)

        # Criterion validation
        Test.@testset "objective! - Criterion validation" begin
            # Invalid criterion
            ocp = Building.PreModel()
            Building.time!(ocp; t0=0.0, tf=10.0)
            Building.state!(ocp, 1)
            Building.control!(ocp, 1)
            Building.variable!(ocp, 1)
            Test.@test_throws Exceptions.IncorrectArgument Building.objective!(
                ocp, :invalid, mayer=mayer
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.objective!(
                ocp, :optimize, mayer=mayer
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.objective!(
                ocp, :Minimize, mayer=mayer
            )

            # Valid criteria (lowercase)
            ocp2 = Building.PreModel()
            Building.time!(ocp2; t0=0.0, tf=10.0)
            Building.state!(ocp2, 1)
            Building.control!(ocp2, 1)
            Building.variable!(ocp2, 1)
            Test.@test_nowarn Building.objective!(ocp2, :min, mayer=mayer)
            Test.@test Components.criterion(ocp2.objective) == :min

            ocp3 = Building.PreModel()
            Building.time!(ocp3; t0=0.0, tf=10.0)
            Building.state!(ocp3, 1)
            Building.control!(ocp3, 1)
            Building.variable!(ocp3, 1)
            Test.@test_nowarn Building.objective!(ocp3, :max, lagrange=lagrange)
            Test.@test Components.criterion(ocp3.objective) == :max

            # Valid criteria (uppercase - case-insensitive)
            ocp4 = Building.PreModel()
            Building.time!(ocp4; t0=0.0, tf=10.0)
            Building.state!(ocp4, 1)
            Building.control!(ocp4, 1)
            Building.variable!(ocp4, 1)
            Test.@test_nowarn Building.objective!(ocp4, :MIN, mayer=mayer)
            Test.@test Components.criterion(ocp4.objective) == :min

            ocp5 = Building.PreModel()
            Building.time!(ocp5; t0=0.0, tf=10.0)
            Building.state!(ocp5, 1)
            Building.control!(ocp5, 1)
            Building.variable!(ocp5, 1)
            Test.@test_nowarn Building.objective!(ocp5, :MAX, lagrange=lagrange)
            Test.@test Components.criterion(ocp5.objective) == :max
        end

        # ====================================================================
        # UNIT TESTS - Cost aliases
        # ====================================================================

        Test.@testset "cost aliases" verbose=VERBOSE showtiming=SHOWTIMING begin
            mayer_alias(x0, xf, v) = x0 .+ xf .+ v
            lagrange_alias(t, x, u, v) = t .+ x .+ u .+ v

            # MayerObjectiveModel
            obj_mayer = Components.MayerObjectiveModel(mayer_alias, :min)
            Test.@test Components.is_mayer_cost_defined(obj_mayer) ==
                Components.has_mayer_cost(obj_mayer)
            Test.@test Components.is_lagrange_cost_defined(obj_mayer) ==
                Components.has_lagrange_cost(obj_mayer)
            Test.@test Components.is_mayer_cost_defined(obj_mayer) === true
            Test.@test Components.is_lagrange_cost_defined(obj_mayer) === false

            # LagrangeObjectiveModel
            obj_lagrange = Components.LagrangeObjectiveModel(lagrange_alias, :max)
            Test.@test Components.is_mayer_cost_defined(obj_lagrange) ==
                Components.has_mayer_cost(obj_lagrange)
            Test.@test Components.is_lagrange_cost_defined(obj_lagrange) ==
                Components.has_lagrange_cost(obj_lagrange)
            Test.@test Components.is_mayer_cost_defined(obj_lagrange) === false
            Test.@test Components.is_lagrange_cost_defined(obj_lagrange) === true

            # BolzaObjectiveModel
            obj_bolza = Components.BolzaObjectiveModel(mayer_alias, lagrange_alias, :min)
            Test.@test Components.is_mayer_cost_defined(obj_bolza) ==
                Components.has_mayer_cost(obj_bolza)
            Test.@test Components.is_lagrange_cost_defined(obj_bolza) ==
                Components.has_lagrange_cost(obj_bolza)
            Test.@test Components.is_mayer_cost_defined(obj_bolza) === true
            Test.@test Components.is_lagrange_cost_defined(obj_bolza) === true
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_objective() = TestOCPObjective.test_objective()
