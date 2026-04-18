module TestVariableControlChecks

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_variable_control_checks()
    Test.@testset "Variable and Control Checks Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - PreModel Methods
        # ====================================================================

        Test.@testset "is_variable - PreModel" begin
            Test.@testset "Default PreModel (no variable)" begin
                ocp = CTModels.PreModel()
                Test.@test CTModels.is_variable(ocp) === false
            end

            Test.@testset "PreModel with variable" begin
                ocp = CTModels.PreModel()
                CTModels.variable!(ocp, 2)
                Test.@test CTModels.is_variable(ocp) === true
            end

            Test.@testset "PreModel with zero dimension variable" begin
                ocp = CTModels.PreModel()
                CTModels.variable!(ocp, 0)
                Test.@test CTModels.is_variable(ocp) === false
            end
        end

        Test.@testset "is_control_free - PreModel" begin
            Test.@testset "Default PreModel (no control)" begin
                ocp = CTModels.PreModel()
                Test.@test CTModels.is_control_free(ocp) === true
            end

            Test.@testset "PreModel with control" begin
                ocp = CTModels.PreModel()
                CTModels.control!(ocp, 1)
                Test.@test CTModels.is_control_free(ocp) === false
            end

            Test.@testset "PreModel with multiple control inputs" begin
                ocp = CTModels.PreModel()
                CTModels.control!(ocp, 3)
                Test.@test CTModels.is_control_free(ocp) === false
            end
        end

        # ====================================================================
        # UNIT TESTS - Model Methods
        # ====================================================================

        Test.@testset "is_variable - Model" begin
            Test.@testset "Model with variable" begin
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 1)
                CTModels.control!(ocp, 1)
                CTModels.variable!(ocp, 2)

                dyn!(r, t, x, u, v) = r .= 0
                CTModels.dynamics!(ocp, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                CTModels.objective!(ocp, :min; mayer=mayer, lagrange=lagrange)

                CTModels.definition!(ocp, quote end)
                CTModels.time_dependence!(ocp; autonomous=true)

                model = CTModels.build(ocp)
                Test.@test CTModels.is_variable(model) === true
            end

            Test.@testset "Model without variable" begin
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
                CTModels.time_dependence!(ocp; autonomous=true)

                model = CTModels.build(ocp)
                Test.@test CTModels.is_variable(model) === false
            end
        end

        Test.@testset "is_control_free - Model" begin
            Test.@testset "Model with control" begin
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
                CTModels.time_dependence!(ocp; autonomous=true)

                model = CTModels.build(ocp)
                Test.@test CTModels.is_control_free(model) === false
            end

            Test.@testset "Model without control" begin
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 1)
                CTModels.variable!(ocp, 0)

                dyn!(r, t, x, u, v) = r .= 0
                CTModels.dynamics!(ocp, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                CTModels.objective!(ocp, :min; mayer=mayer, lagrange=lagrange)

                CTModels.definition!(ocp, quote end)
                CTModels.time_dependence!(ocp; autonomous=true)

                model = CTModels.build(ocp)
                Test.@test CTModels.is_control_free(model) === true
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Complete OCP workflows
        # ====================================================================

        Test.@testset "Integration - Mixed configurations" begin
            Test.@testset "PreModel with variable and control" begin
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 2)
                CTModels.control!(ocp, 1)
                CTModels.variable!(ocp, 1)

                Test.@test CTModels.is_variable(ocp) === true
                Test.@test CTModels.is_control_free(ocp) === false
            end

            Test.@testset "PreModel with variable only (control-free)" begin
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 2)
                CTModels.variable!(ocp, 1)

                Test.@test CTModels.is_variable(ocp) === true
                Test.@test CTModels.is_control_free(ocp) === true
            end

            Test.@testset "PreModel with control only (no variable)" begin
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 2)
                CTModels.control!(ocp, 1)

                Test.@test CTModels.is_variable(ocp) === false
                Test.@test CTModels.is_control_free(ocp) === false
            end

            Test.@testset "PreModel with neither variable nor control" begin
                ocp = CTModels.PreModel()
                CTModels.time!(ocp; t0=0.0, tf=1.0)
                CTModels.state!(ocp, 2)

                Test.@test CTModels.is_variable(ocp) === false
                Test.@test CTModels.is_control_free(ocp) === true
            end
        end

        # ====================================================================
        # EXPORTS VERIFICATION
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported Functions" begin
                for f in (:is_variable, :is_control_free)
                    Test.@test isdefined(CTModels, f)
                end
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable_control_checks() = TestVariableControlChecks.test_variable_control_checks()
