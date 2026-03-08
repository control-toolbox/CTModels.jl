module TestOCPTimeDependence

import Test
import CTBase.Exceptions
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_time_dependence()
    Test.@testset "Time Dependence Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for time dependence functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Time Dependence Functions
        # ====================================================================

        Test.@testset "time_dependence! basic behavior" begin
            ocp = CTModels.PreModel()

            # Initially not set
            Test.@test !CTModels.OCP.__is_autonomous_set(ocp)

            # Set once
            CTModels.time_dependence!(ocp; autonomous=true)
            Test.@test CTModels.OCP.__is_autonomous_set(ocp)
            Test.@test CTModels.is_autonomous(ocp) === true

            # Second call must fail
            Test.@test_throws Exceptions.PreconditionError CTModels.time_dependence!(
                ocp; autonomous=false
            )
        end

        # ========================================================================
        # Integration-style tests – fake OCPs with different time dependence
        # ========================================================================

        Test.@testset "fake OCP time dependence flag" begin
            function build_premodel_with_time_dependence(flag::Bool)
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 1)
                CTModels.control!(ocp, 1)
                CTModels.variable!(ocp, 0)

                dyn!(r, t, x, u, v) = r .= 0
                CTModels.dynamics!(ocp, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                CTModels.objective!(ocp, :min; mayer=mayer, lagrange=lagrange)

                CTModels.definition!(ocp, quote end)
                CTModels.time_dependence!(ocp; autonomous=flag)
                return ocp
            end

            pre_autonomous = build_premodel_with_time_dependence(true)
            pre_nonautonomous = build_premodel_with_time_dependence(false)

            Test.@test CTModels.is_autonomous(pre_autonomous) === true
            Test.@test CTModels.is_autonomous(pre_nonautonomous) === false
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_time_dependence() = TestOCPTimeDependence.test_time_dependence()
