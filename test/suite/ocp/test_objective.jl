module TestOCPObjective

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_objective()
    Test.@testset "Objective" verbose = VERBOSE showtiming = SHOWTIMING begin

        # is concretetype    
        @test isconcretetype(CTModels.MayerObjectiveModel{Function}) # MayerObjectiveModel
        @test isconcretetype(CTModels.LagrangeObjectiveModel{Function}) # LagrangeObjectiveModel
        @test isconcretetype(CTModels.BolzaObjectiveModel{Function,Function}) # BolzaObjectiveModel

        # Functions
        mayer(x0, xf, v) = x0 .+ xf .+ v
        lagrange(t, x, u, v) = t .+ x .+ u .+ v

        # MayerObjectiveModel
        objective = CTModels.MayerObjectiveModel(mayer, :min)
        @test CTModels.mayer(objective) == mayer
        @test CTModels.criterion(objective) == :min
        @test CTModels.has_mayer_cost(objective) == true
        @test CTModels.has_lagrange_cost(objective) == false

        # LagrangeObjectiveModel
        objective = CTModels.LagrangeObjectiveModel(lagrange, :max)
        @test CTModels.lagrange(objective) == lagrange
        @test CTModels.criterion(objective) == :max
        @test CTModels.has_mayer_cost(objective) == false
        @test CTModels.has_lagrange_cost(objective) == true

        # BolzaObjectiveModel
        objective = CTModels.BolzaObjectiveModel(mayer, lagrange, :min)
        @test CTModels.mayer(objective) == mayer
        @test CTModels.lagrange(objective) == lagrange
        @test CTModels.criterion(objective) == :min
        @test CTModels.has_mayer_cost(objective) == true
        @test CTModels.has_lagrange_cost(objective) == true

        # from PreModel with Mayer objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp, :min; mayer=mayer)
        @test ocp.objective == CTModels.MayerObjectiveModel(mayer, :min)
        @test CTModels.criterion(ocp.objective) == :min
        @test CTModels.has_mayer_cost(ocp.objective) == true
        @test CTModels.has_lagrange_cost(ocp.objective) == false

        # from PreModel with Lagrange objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp, :max; lagrange=lagrange)
        @test ocp.objective == CTModels.LagrangeObjectiveModel(lagrange, :max)
        @test CTModels.criterion(ocp.objective) == :max
        @test CTModels.has_mayer_cost(ocp.objective) == false
        @test CTModels.has_lagrange_cost(ocp.objective) == true

        # from PreModel with Bolza objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp; mayer=mayer, lagrange=lagrange) # default criterion is :min
        @test ocp.objective == CTModels.BolzaObjectiveModel(mayer, lagrange, :min)
        @test CTModels.criterion(ocp.objective) == :min
        @test CTModels.has_mayer_cost(ocp.objective) == true
        @test CTModels.has_lagrange_cost(ocp.objective) == true

        # exceptions
        # state not set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        @test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # control not set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.variable!(ocp, 1)
        @test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # times not set
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        @test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # objective already set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        CTModels.objective!(ocp, :min; mayer=mayer)
        @test_throws Exceptions.PreconditionError CTModels.objective!(
            ocp, :min, mayer=mayer
        )

        # variable set after the objective
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.objective!(ocp, :min; mayer=mayer)
        @test_throws Exceptions.PreconditionError CTModels.variable!(ocp, 1)

        # no function given
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        @test_throws Exceptions.IncorrectArgument CTModels.objective!(ocp, :min)

        # NEW: Criterion validation tests
        @testset "objective! - Criterion validation" begin
            # Invalid criterion
            ocp = CTModels.PreModel()
            CTModels.time!(ocp; t0=0.0, tf=10.0)
            CTModels.state!(ocp, 1)
            CTModels.control!(ocp, 1)
            CTModels.variable!(ocp, 1)
            @test_throws Exceptions.IncorrectArgument CTModels.objective!(
                ocp, :invalid, mayer=mayer
            )
            @test_throws Exceptions.IncorrectArgument CTModels.objective!(
                ocp, :optimize, mayer=mayer
            )
            @test_throws Exceptions.IncorrectArgument CTModels.objective!(
                ocp, :Minimize, mayer=mayer
            )  # not in accepted list

            # Valid criteria (lowercase)
            ocp2 = CTModels.PreModel()
            CTModels.time!(ocp2; t0=0.0, tf=10.0)
            CTModels.state!(ocp2, 1)
            CTModels.control!(ocp2, 1)
            CTModels.variable!(ocp2, 1)
            @test_nowarn CTModels.objective!(ocp2, :min, mayer=mayer)
            @test CTModels.criterion(ocp2.objective) == :min

            ocp3 = CTModels.PreModel()
            CTModels.time!(ocp3; t0=0.0, tf=10.0)
            CTModels.state!(ocp3, 1)
            CTModels.control!(ocp3, 1)
            CTModels.variable!(ocp3, 1)
            @test_nowarn CTModels.objective!(ocp3, :max, lagrange=lagrange)
            @test CTModels.criterion(ocp3.objective) == :max

            # Valid criteria (uppercase - case-insensitive)
            ocp4 = CTModels.PreModel()
            CTModels.time!(ocp4; t0=0.0, tf=10.0)
            CTModels.state!(ocp4, 1)
            CTModels.control!(ocp4, 1)
            CTModels.variable!(ocp4, 1)
            @test_nowarn CTModels.objective!(ocp4, :MIN, mayer=mayer)
            @test CTModels.criterion(ocp4.objective) == :min  # normalized to lowercase

            ocp5 = CTModels.PreModel()
            CTModels.time!(ocp5; t0=0.0, tf=10.0)
            CTModels.state!(ocp5, 1)
            CTModels.control!(ocp5, 1)
            CTModels.variable!(ocp5, 1)
            @test_nowarn CTModels.objective!(ocp5, :MAX, lagrange=lagrange)
            @test CTModels.criterion(ocp5.objective) == :max  # normalized to lowercase
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
            @test CTModels.is_mayer_cost_defined(obj_mayer) ==
                CTModels.has_mayer_cost(obj_mayer)
            @test CTModels.is_lagrange_cost_defined(obj_mayer) ==
                CTModels.has_lagrange_cost(obj_mayer)
            @test CTModels.is_mayer_cost_defined(obj_mayer) === true
            @test CTModels.is_lagrange_cost_defined(obj_mayer) === false

            # LagrangeObjectiveModel
            obj_lagrange = CTModels.LagrangeObjectiveModel(lagrange_alias, :max)
            @test CTModels.is_mayer_cost_defined(obj_lagrange) ==
                CTModels.has_mayer_cost(obj_lagrange)
            @test CTModels.is_lagrange_cost_defined(obj_lagrange) ==
                CTModels.has_lagrange_cost(obj_lagrange)
            @test CTModels.is_mayer_cost_defined(obj_lagrange) === false
            @test CTModels.is_lagrange_cost_defined(obj_lagrange) === true

            # BolzaObjectiveModel
            obj_bolza = CTModels.BolzaObjectiveModel(mayer_alias, lagrange_alias, :min)
            @test CTModels.is_mayer_cost_defined(obj_bolza) ==
                CTModels.has_mayer_cost(obj_bolza)
            @test CTModels.is_lagrange_cost_defined(obj_bolza) ==
                CTModels.has_lagrange_cost(obj_bolza)
            @test CTModels.is_mayer_cost_defined(obj_bolza) === true
            @test CTModels.is_lagrange_cost_defined(obj_bolza) === true
        end
    end
end

end # module

test_objective() = TestOCPObjective.test_objective()
