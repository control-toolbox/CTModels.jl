module TestInitialGuessState

using Test: Test
import CTBase.Exceptions
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Dummy OCPs for testing
struct DummyOCP1D <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1D) = 1
CTModels.control_dimension(::DummyOCP1D) = 1
CTModels.variable_dimension(::DummyOCP1D) = 0
CTModels.has_fixed_initial_time(::DummyOCP1D) = true
CTModels.initial_time(::DummyOCP1D) = 0.0

struct DummyOCP2D <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP2D) = 2
CTModels.control_dimension(::DummyOCP2D) = 1
CTModels.variable_dimension(::DummyOCP2D) = 0
CTModels.has_fixed_initial_time(::DummyOCP2D) = true
CTModels.initial_time(::DummyOCP2D) = 0.0

function test_initial_guess_state()
    Test.@testset "State Initial Guess Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for state initial guess functionality
        end

        # ====================================================================
        # UNIT TESTS - State Initial Guess Functions
        # ====================================================================

        Test.@testset "initial_state with Function" begin
            ocp = DummyOCP2D()

            f = t -> [t, t^2]
            result = CTModels.initial_state(ocp, f)
            Test.@test result === f
        end

        Test.@testset "initial_state with Scalar" begin
            ocp_1d = DummyOCP1D()

            result = CTModels.initial_state(ocp_1d, 0.5)
            Test.@test result isa Function
            Test.@test result(0.0) == 0.5

            ocp_2d = DummyOCP2D()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.initial_state(
                ocp_2d, 0.5
            )
        end

        Test.@testset "initial_state with Vector" begin
            ocp = DummyOCP2D()

            result = CTModels.initial_state(ocp, [0.0, 1.0])
            Test.@test result isa Function
            Test.@test result(0.0) == [0.0, 1.0]

            Test.@test_throws Exceptions.IncorrectArgument CTModels.initial_state(
                ocp, [0.0]
            )
        end

        Test.@testset "initial_state with Nothing" begin
            ocp = DummyOCP2D()

            result = CTModels.initial_state(ocp, nothing)
            Test.@test result isa Function
            Test.@test result(0.0) == [0.1, 0.1]

            ocp_1d = DummyOCP1D()
            result_1d = CTModels.initial_state(ocp_1d, nothing)
            Test.@test result_1d isa Function
            Test.@test result_1d(0.0) == 0.1
        end

        Test.@testset "state accessor" begin
            ocp = DummyOCP2D()

            init = CTModels.initial_guess(ocp; state=t -> [0.0, 1.0])

            Test.@test CTModels.state(init) isa Function
            Test.@test CTModels.state(init)(0.5) == [0.0, 1.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_state() = TestInitialGuessState.test_initial_guess_state()
