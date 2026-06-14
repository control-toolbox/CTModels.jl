module TestOCPTimeDependence

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_time_dependence()
    Test.@testset "Time Dependence Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Time Dependence Functions
        # ====================================================================

        Test.@testset "time_dependence! basic behavior" begin
            ocp = Building.PreModel()

            # Initially not set
            Test.@test !Building.__is_autonomous_set(ocp)

            # Set once
            Building.time_dependence!(ocp; autonomous=true)
            Test.@test Building.__is_autonomous_set(ocp)
            Test.@test ocp.autonomous === true

            # Second call must fail
            Test.@test_throws Exceptions.PreconditionError Building.time_dependence!(
                ocp; autonomous=false
            )
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "fake OCP time dependence flag" begin
            function build_premodel_with_time_dependence(flag::Bool)
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 1)
                Building.control!(ocp, 1)
                Building.variable!(ocp, 0)

                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(ocp, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                Building.objective!(ocp, :min; mayer=mayer, lagrange=lagrange)

                Building.definition!(ocp, quote end)
                Building.time_dependence!(ocp; autonomous=flag)
                return ocp
            end

            pre_autonomous = build_premodel_with_time_dependence(true)
            pre_nonautonomous = build_premodel_with_time_dependence(false)

            Test.@test pre_autonomous.autonomous === true
            Test.@test pre_nonautonomous.autonomous === false
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_time_dependence() = TestOCPTimeDependence.test_time_dependence()
