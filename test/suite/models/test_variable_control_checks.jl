module TestVariableControlChecks

import Test: Test
import CTBase.Traits: Traits
import CTModels.Building: Building
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_variable_control_checks()
    Test.@testset "Variable and Control Checks Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Model Methods
        # ====================================================================

        Test.@testset "is_variable - Model" begin
            Test.@testset "Model with variable" begin
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 1)
                Building.control!(ocp, 1)
                Building.variable!(ocp, 2)

                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(ocp, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                Building.objective!(ocp, :min; mayer=mayer, lagrange=lagrange)

                Building.definition!(ocp, quote end)
                Building.time_dependence!(ocp; autonomous=true)

                model = Building.build(ocp)
                Test.@test Models.is_variable(model) === true
            end

            Test.@testset "Model without variable" begin
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
                Building.time_dependence!(ocp; autonomous=true)

                model = Building.build(ocp)
                Test.@test Models.is_variable(model) === false
            end
        end

        Test.@testset "is_control_free - Model" begin
            Test.@testset "Model with control" begin
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
                Building.time_dependence!(ocp; autonomous=true)

                model = Building.build(ocp)
                Test.@test Models.is_control_free(model) === false
                Test.@test Models.has_control(model) === true
                Test.@test Traits.control_dependence(model) === Traits.WithControl
                Test.@test Traits.has_control_dependence_trait(model) === true
            end

            Test.@testset "Model without control" begin
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 1)
                Building.variable!(ocp, 0)

                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(ocp, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                Building.objective!(ocp, :min; mayer=mayer, lagrange=lagrange)

                Building.definition!(ocp, quote end)
                Building.time_dependence!(ocp; autonomous=true)

                model = Building.build(ocp)
                Test.@test Models.is_control_free(model) === true
                Test.@test Models.has_control(model) === false
                Test.@test Traits.control_dependence(model) === Traits.ControlFree
                Test.@test Traits.has_control_dependence_trait(model) === true
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Complete OCP workflows
        # ====================================================================

        Test.@testset "Integration - Mixed configurations" begin
            Test.@testset "PreModel with variable and control" begin
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 2)
                Building.control!(ocp, 1)
                Building.variable!(ocp, 1)

                Test.@test !Building.__is_variable_empty(ocp)
                Test.@test !Building.__is_control_empty(ocp)
            end

            Test.@testset "PreModel with variable only (control-free)" begin
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 2)
                Building.variable!(ocp, 1)

                Test.@test !Building.__is_variable_empty(ocp)
                Test.@test Building.__is_control_empty(ocp)
            end

            Test.@testset "PreModel with control only (no variable)" begin
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 2)
                Building.control!(ocp, 1)

                Test.@test Building.__is_variable_empty(ocp)
                Test.@test !Building.__is_control_empty(ocp)
            end

            Test.@testset "PreModel with neither variable nor control" begin
                ocp = Building.PreModel()
                Building.time!(ocp; t0=0.0, tf=1.0)
                Building.state!(ocp, 2)

                Test.@test Building.__is_variable_empty(ocp)
                Test.@test Building.__is_control_empty(ocp)
            end
        end

        # ====================================================================
        # EXPORTS VERIFICATION
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported Functions" begin
                for f in (:is_variable, :is_control_free, :has_control)
                    Test.@test isdefined(Models, f)
                end
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable_control_checks() = TestVariableControlChecks.test_variable_control_checks()
