module TestOCPTimeDependence

using Test
using CTBase
using CTModels
using Main.TestOptions: VERBOSE, SHOWTIMING

function test_time_dependence()
    # TODO: add tests for src/ocp/time_dependence.jl.

    # ========================================================================
    # Unit tests – time_dependence! and is_autonomous
    # ========================================================================

    Test.@testset "time_dependence! basic behavior" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        ocp = CTModels.PreModel()

        # Initially not set
        Test.@test !CTModels.OCP.__is_autonomous_set(ocp)

        # Set once
        CTModels.time_dependence!(ocp; autonomous=true)
        Test.@test CTModels.OCP.__is_autonomous_set(ocp)
        Test.@test CTModels.is_autonomous(ocp) === true

        # Second call must fail
        Test.@test_throws CTModels.Exceptions.UnauthorizedCall CTModels.time_dependence!(
            ocp; autonomous=false
        )
    end

    # ========================================================================
    # Integration-style tests – fake OCPs with different time dependence
    # ========================================================================

    Test.@testset "fake OCP time dependence flag" verbose = VERBOSE showtiming = SHOWTIMING begin
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

end # module

test_time_dependence() = TestOCPTimeDependence.test_time_dependence()
