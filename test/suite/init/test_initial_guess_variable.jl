module TestInitialGuessVariable

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Init: Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Dummy OCPs for testing — top-level (world-age requirement)
struct DummyOCPNoVarIG <: Models.AbstractModel end
Models.state_dimension(::DummyOCPNoVarIG) = 1
Models.control_dimension(::DummyOCPNoVarIG) = 1
Models.variable_dimension(::DummyOCPNoVarIG) = 0
Components.has_fixed_initial_time(::DummyOCPNoVarIG) = true
Components.initial_time(::DummyOCPNoVarIG) = 0.0

struct DummyOCP1DVarIG <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DVarIG) = 1
Models.control_dimension(::DummyOCP1DVarIG) = 1
Models.variable_dimension(::DummyOCP1DVarIG) = 1
Components.has_fixed_initial_time(::DummyOCP1DVarIG) = true
Components.initial_time(::DummyOCP1DVarIG) = 0.0

struct DummyOCP2DVarIG <: Models.AbstractModel end
Models.state_dimension(::DummyOCP2DVarIG) = 1
Models.control_dimension(::DummyOCP2DVarIG) = 1
Models.variable_dimension(::DummyOCP2DVarIG) = 2
Components.has_fixed_initial_time(::DummyOCP2DVarIG) = true
Components.initial_time(::DummyOCP2DVarIG) = 0.0

function test_initial_guess_variable()
    Test.@testset "Variable Initial Guess Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Variable Initial Guess Functions
        # ====================================================================

        Test.@testset "initial_variable with Scalar" begin
            ocp_1d = DummyOCP1DVarIG()

            result = Init.initial_variable(ocp_1d, 0.5)
            Test.@test result == 0.5

            ocp_no_var = DummyOCPNoVarIG()
            Test.@test_throws Exceptions.IncorrectArgument Init.initial_variable(
                ocp_no_var, 0.5
            )
        end

        Test.@testset "initial_variable with Vector" begin
            ocp = DummyOCP2DVarIG()

            result = Init.initial_variable(ocp, [0.0, 1.0])
            Test.@test result == [0.0, 1.0]

            Test.@test_throws Exceptions.IncorrectArgument Init.initial_variable(
                ocp, [0.0]
            )
        end

        Test.@testset "initial_variable with Nothing" begin
            ocp_no_var = DummyOCPNoVarIG()
            result = Init.initial_variable(ocp_no_var, nothing)
            Test.@test result == Float64[]

            ocp_1d = DummyOCP1DVarIG()
            result_1d = Init.initial_variable(ocp_1d, nothing)
            Test.@test result_1d == 0.1

            ocp_2d = DummyOCP2DVarIG()
            result_2d = Init.initial_variable(ocp_2d, nothing)
            Test.@test result_2d == [0.1, 0.1]
        end

        Test.@testset "variable accessor" begin
            ocp = DummyOCP2DVarIG()

            init = Init.initial_guess(ocp; variable=[0.0, 1.0])

            Test.@test Models.variable(init) == [0.0, 1.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_variable() = TestInitialGuessVariable.test_initial_guess_variable()
