module TestInitialGuessState

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Init: Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Dummy OCPs for testing — top-level (world-age requirement)
struct DummyOCP1DState <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DState) = 1
Models.control_dimension(::DummyOCP1DState) = 1
Models.variable_dimension(::DummyOCP1DState) = 0
Components.has_fixed_initial_time(::DummyOCP1DState) = true
Components.initial_time(::DummyOCP1DState) = 0.0

struct DummyOCP2DState <: Models.AbstractModel end
Models.state_dimension(::DummyOCP2DState) = 2
Models.control_dimension(::DummyOCP2DState) = 1
Models.variable_dimension(::DummyOCP2DState) = 0
Components.has_fixed_initial_time(::DummyOCP2DState) = true
Components.initial_time(::DummyOCP2DState) = 0.0

function test_initial_guess_state()
    Test.@testset "State Initial Guess Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - State Initial Guess Functions
        # ====================================================================

        Test.@testset "initial_state with Function" begin
            ocp = DummyOCP2DState()

            f = t -> [t, t^2]
            result = Init.initial_state(ocp, f)
            Test.@test result === f
        end

        Test.@testset "initial_state with Scalar" begin
            ocp_1d = DummyOCP1DState()

            result = Init.initial_state(ocp_1d, 0.5)
            Test.@test result isa Function
            Test.@test result(0.0) == 0.5

            ocp_2d = DummyOCP2DState()
            Test.@test_throws Exceptions.IncorrectArgument Init.initial_state(ocp_2d, 0.5)
        end

        Test.@testset "initial_state with Vector" begin
            ocp = DummyOCP2DState()

            result = Init.initial_state(ocp, [0.0, 1.0])
            Test.@test result isa Function
            Test.@test result(0.0) == [0.0, 1.0]

            Test.@test_throws Exceptions.IncorrectArgument Init.initial_state(ocp, [0.0])
        end

        Test.@testset "initial_state with Nothing" begin
            ocp = DummyOCP2DState()

            result = Init.initial_state(ocp, nothing)
            Test.@test result isa Function
            Test.@test result(0.0) == [0.1, 0.1]

            ocp_1d = DummyOCP1DState()
            result_1d = Init.initial_state(ocp_1d, nothing)
            Test.@test result_1d isa Function
            Test.@test result_1d(0.0) == 0.1
        end

        Test.@testset "state accessor" begin
            ocp = DummyOCP2DState()

            init = Init.initial_guess(ocp; state=t -> [0.0, 1.0])

            Test.@test Models.state(init) isa Function
            Test.@test Models.state(init)(0.5) == [0.0, 1.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_state() = TestInitialGuessState.test_initial_guess_state()
