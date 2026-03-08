module TestOCPObjective

import Test
import CTBase.Exceptions
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_objective()
    Test.@testset "Objective Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for objective functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Objective Models
        # ====================================================================

        # is concretetype    
        Test.@test isconcretetype(CTModels.MayerObjectiveModel{Function}) # MayerObjectiveModel
        Test.@test isconcretetype(CTModels.LagrangeObjectiveModel{Function}) # LagrangeObjectiveModel
        Test.@test isconcretetype(CTModels.BolzaObjectiveModel{Function,Function}) # BolzaObjectiveModel

        # Functions
        mayer(x0, xf, v) = x0 .+ xf .+ v
        lagrange(t, x, u, v) = t .+ x .+ u .+ v

        # MayerObjectiveModel
        objective = CTModels.MayerObjectiveModel(mayer, :min)
        Test.@test CTModels.mayer(objective) == mayer
        Test.@test CTModels.criterion(objective) == :min
        Test.@test CTModels.has_mayer_cost(objective) == true
        Test.@test CTModels.has_lagrange_cost(objective) == false

        # LagrangeObjectiveModel
        objective = CTModels.LagrangeObjectiveModel(lagrange, :max)
        Test.@test CTModels.lagrange(objective) == lagrange
        Test.@test CTModels.criterion(objective) == :max
        Test.@test CTModels.has_mayer_cost(objective) == false
        Test.@test CTModels.has_lagrange_cost(objective) == true

        # BolzaObjectiveModel
        objective = CTModels.BolzaObjectiveModel(mayer, lagrange, :min)
        Test.@test CTModels.mayer(objective) == mayer
        Test.@test CTModels.lagrange(objective) == lagrange
        Test.@test CTModels.criterion(objective) == :min
        Test.@test CTModels.has_mayer_cost(objective) == true
        Test.@test CTModels.has_lagrange_cost(objective) == true

        # from PreModel with Mayer objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp, :min; mayer=mayer)
        Test.@test ocp.objective == CTModels.MayerObjectiveModel(mayer, :min)
        Test.@test CTModels.criterion(ocp.objective) == :min
        Test.@test CTModels.has_mayer_cost(ocp.objective) == true
        Test.@test CTModels.has_lagrange_cost(ocp.objective) == false

        # from PreModel with Lagrange objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp, :max; lagrange=lagrange)
        Test.@test ocp.objective == CTModels.LagrangeObjectiveModel(lagrange, :max)
        Test.@test CTModels.criterion(ocp.objective) == :max
        Test.@test CTModels.has_mayer_cost(ocp.objective) == false
        Test.@test CTModels.has_lagrange_cost(ocp.objective) == true

        # from PreModel with Bolza objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp; mayer=mayer, lagrange=lagrange) # default criterion is :min
        Test.@test ocp.objective == CTModels.BolzaObjectiveModel(mayer, lagrange, :min)
        Test.@test CTModels.criterion(ocp.objective) == :min
        Test.@test CTModels.has_mayer_cost(ocp.objective) == true
        Test.@test CTModels.has_lagrange_cost(ocp.objective) == true

        # exceptions
        # state not set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # control not set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # times not set
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # objective already set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp, :min; mayer=mayer)
        Test.@test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # variable set after the objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.objective!(ocp, :min; mayer=mayer)
        Test.@test_throws Exceptions.PreconditionError CTModels.variable!(ocp, 1)

        # no function given
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.objective!(ocp, :min)

        # NEW: Criterion validation tests
        Test.@testset "objective! - Criterion validation" begin
            # Invalid criterion
            ocp = CTModels.PreModel()
            CTModels.time!(ocp; t0=0.0, tf=10.0)
            CTModels.state!(ocp, 1)
            CTModels.control!(ocp, 1)
            CTModels.variable!(ocp, 1)
            Test.@test_throws Exceptions.IncorrectArgument CTModels.objective!(
                ocp, :invalid, mayer=mayer
            )
            Test.@test_throws Exceptions.IncorrectArgument CTModels.objective!(
                ocp, :optimize, mayer=mayer
            )
            Test.@test_throws Exceptions.IncorrectArgument CTModels.objective!(
                ocp, :Minimize, mayer=mayer
            )  # not in accepted list

            # Valid criteria (lowercase)
            ocp2 = CTModels.PreModel()
            CTModels.time!(ocp2; t0=0.0, tf=10.0)
            CTModels.state!(ocp2, 1)
            CTModels.control!(ocp2, 1)
            CTModels.variable!(ocp2, 1)
            Test.@test_nowarn CTModels.objective!(ocp2, :min, mayer=mayer)
            Test.@test CTModels.criterion(ocp2.objective) == :min

            ocp3 = CTModels.PreModel()
            CTModels.time!(ocp3; t0=0.0, tf=10.0)
            CTModels.state!(ocp3, 1)
            CTModels.control!(ocp3, 1)
            CTModels.variable!(ocp3, 1)
            Test.@test_nowarn CTModels.objective!(ocp3, :max, lagrange=lagrange)
            Test.@test CTModels.criterion(ocp3.objective) == :max

            # Valid criteria (uppercase - case-insensitive)
            ocp4 = CTModels.PreModel()
            CTModels.time!(ocp4; t0=0.0, tf=10.0)
            CTModels.state!(ocp4, 1)
            CTModels.control!(ocp4, 1)
            CTModels.variable!(ocp4, 1)
            Test.@test_nowarn CTModels.objective!(ocp4, :MIN, mayer=mayer)
            Test.@test CTModels.criterion(ocp4.objective) == :min  # normalized to lowercase

            ocp5 = CTModels.PreModel()
            CTModels.time!(ocp5; t0=0.0, tf=10.0)
            CTModels.state!(ocp5, 1)
            CTModels.control!(ocp5, 1)
            CTModels.variable!(ocp5, 1)
            Test.@test_nowarn CTModels.objective!(ocp5, :MAX, lagrange=lagrange)
            Test.@test CTModels.criterion(ocp5.objective) == :max  # normalized to lowercase
        end

        # ========================================================================
        # Test naming consistency aliases (issue #169)
        # ========================================================================

        Test.@testset "cost aliases" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Functions (different names to avoid warnings)
            mayer_alias(x0, xf, v) = x0 .+ xf .+ v
            lagrange_alias(t, x, u, v) = t .+ x .+ u .+ v

            # MayerObjectiveModel
            obj_mayer = CTModels.MayerObjectiveModel(mayer_alias, :min)
            Test.@test CTModels.is_mayer_cost_defined(obj_mayer) ==
                CTModels.has_mayer_cost(obj_mayer)
            Test.@test CTModels.is_lagrange_cost_defined(obj_mayer) ==
                CTModels.has_lagrange_cost(obj_mayer)
            Test.@test CTModels.is_mayer_cost_defined(obj_mayer) === true
            Test.@test CTModels.is_lagrange_cost_defined(obj_mayer) === false

            # LagrangeObjectiveModel
            obj_lagrange = CTModels.LagrangeObjectiveModel(lagrange_alias, :max)
            Test.@test CTModels.is_mayer_cost_defined(obj_lagrange) ==
                CTModels.has_mayer_cost(obj_lagrange)
            Test.@test CTModels.is_lagrange_cost_defined(obj_lagrange) ==
                CTModels.has_lagrange_cost(obj_lagrange)
            Test.@test CTModels.is_mayer_cost_defined(obj_lagrange) === false
            Test.@test CTModels.is_lagrange_cost_defined(obj_lagrange) === true

            # BolzaObjectiveModel
            obj_bolza = CTModels.BolzaObjectiveModel(mayer_alias, lagrange_alias, :min)
            Test.@test CTModels.is_mayer_cost_defined(obj_bolza) ==
                CTModels.has_mayer_cost(obj_bolza)
            Test.@test CTModels.is_lagrange_cost_defined(obj_bolza) ==
                CTModels.has_lagrange_cost(obj_bolza)
            Test.@test CTModels.is_mayer_cost_defined(obj_bolza) === true
            Test.@test CTModels.is_lagrange_cost_defined(obj_bolza) === true
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_objective() = TestOCPObjective.test_objective()
