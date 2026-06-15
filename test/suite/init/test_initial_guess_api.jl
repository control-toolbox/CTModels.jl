module TestInitialGuessAPI

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Models: Models
import CTModels.Init: Init

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Dummy OCPs for testing
struct DummyOCP1DNoVar <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DNoVar) = 1
Models.control_dimension(::DummyOCP1DNoVar) = 1
Models.variable_dimension(::DummyOCP1DNoVar) = 0
Models.has_fixed_initial_time(::DummyOCP1DNoVar) = true
Models.initial_time(::DummyOCP1DNoVar) = 0.0
Models.state_name(::DummyOCP1DNoVar) = "x"
Models.state_components(::DummyOCP1DNoVar) = ["x"]
Models.control_name(::DummyOCP1DNoVar) = "u"
Models.control_components(::DummyOCP1DNoVar) = ["u"]
Models.variable_name(::DummyOCP1DNoVar) = "v"
Models.variable_components(::DummyOCP1DNoVar) = String[]

struct DummyOCP1DVar <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DVar) = 1
Models.control_dimension(::DummyOCP1DVar) = 1
Models.variable_dimension(::DummyOCP1DVar) = 1
Models.has_fixed_initial_time(::DummyOCP1DVar) = true
Models.initial_time(::DummyOCP1DVar) = 0.0
Models.state_name(::DummyOCP1DVar) = "x"
Models.state_components(::DummyOCP1DVar) = ["x"]
Models.control_name(::DummyOCP1DVar) = "u"
Models.control_components(::DummyOCP1DVar) = ["u"]
Models.variable_name(::DummyOCP1DVar) = "v"
Models.variable_components(::DummyOCP1DVar) = ["v"]

function test_initial_guess_api()
    Test.@testset "Initial Guess API Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Public API Functions
        # ====================================================================

        Test.@testset "pre_initial_guess" begin
            # Test with all arguments
            state_data = t -> [t]
            control_data = t -> [-t]
            variable_data = 0.5

            pre = Init.pre_initial_guess(
                state=state_data, control=control_data, variable=variable_data
            )

            Test.@test pre isa Init.PreInitialGuess
            Test.@test pre.state === state_data
            Test.@test pre.control === control_data
            Test.@test pre.variable === variable_data

            # Test with no arguments (all nothing)
            pre_empty = Init.pre_initial_guess()
            Test.@test pre_empty isa Init.PreInitialGuess
            Test.@test pre_empty.state === nothing
            Test.@test pre_empty.control === nothing
            Test.@test pre_empty.variable === nothing

            # Test with partial arguments
            pre_partial = Init.pre_initial_guess(state=0.1)
            Test.@test pre_partial.state === 0.1
            Test.@test pre_partial.control === nothing
            Test.@test pre_partial.variable === nothing
        end

        Test.@testset "initial_guess - basic construction" begin
            ocp = DummyOCP1DNoVar()

            # Scalar initial guess consistent with dimension 1
            init = Init.initial_guess(ocp; state=0.2, control=-0.1)
            Test.@test init isa Init.AbstractInitialGuess
            Test.@test init isa Init.InitialGuess

            # Verify state and control are functions
            Test.@test Models.state(init) isa Function
            Test.@test Models.control(init) isa Function

            # Verify they return correct values
            Test.@test Models.state(init)(0.5) ≈ 0.2
            Test.@test Models.control(init)(0.5) ≈ -0.1

            # Variable should be empty vector for no-variable problem
            Test.@test Models.variable(init) isa Vector{Float64}
            Test.@test length(Models.variable(init)) == 0
        end

        Test.@testset "initial_guess - with variable" begin
            ocp = DummyOCP1DVar()

            # Scalar variable consistent with dimension 1
            init = Init.initial_guess(ocp; state=0.2, control=-0.1, variable=0.5)
            Test.@test init isa Init.InitialGuess

            # Verify variable
            Test.@test Models.variable(init) ≈ 0.5
        end

        Test.@testset "initial_guess - default values" begin
            ocp = DummyOCP1DNoVar()

            # No arguments - should use defaults
            init = Init.initial_guess(ocp)
            Test.@test init isa Init.InitialGuess

            # Defaults should be 0.1
            Test.@test Models.state(init)(0.5) ≈ 0.1
            Test.@test Models.control(init)(0.5) ≈ 0.1
        end

        Test.@testset "build_initial_guess - nothing input" begin
            ocp = DummyOCP1DNoVar()

            # nothing should return default initial guess
            ig_nothing = Init.build_initial_guess(ocp, nothing)
            Test.@test ig_nothing isa Init.InitialGuess

            # () should also return default
            ig_empty = Init.build_initial_guess(ocp, ())
            Test.@test ig_empty isa Init.InitialGuess
        end

        Test.@testset "build_initial_guess - InitialGuess input (valid)" begin
            ocp = DummyOCP1DNoVar()

            # Create a valid initial guess
            init = Init.initial_guess(ocp; state=0.5)

            # Passing it to build_initial_guess should validate and return it
            ig = Init.build_initial_guess(ocp, init)
            Test.@test ig === init
        end

        Test.@testset "build_initial_guess - InitialGuess input (invalid)" begin
            ocp = DummyOCP1DNoVar()

            # Manually construct an invalid initial guess (wrong state dimension)
            bad_init = Init.InitialGuess(t -> [t, 2t], t -> 0.1, Float64[])

            # build_initial_guess must now catch this via centralised validation
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_init
            )
        end

        Test.@testset "build_initial_guess - PreInitialGuess input" begin
            ocp1 = DummyOCP1DNoVar()
            ocp2 = DummyOCP1DVar()

            # Create a PreInit
            pre1 = Init.pre_initial_guess(state=0.2, control=-0.1)
            ig1 = Init.build_initial_guess(ocp1, pre1)
            Test.@test ig1 isa Init.InitialGuess
            Test.@test Models.state(ig1)(0.5) ≈ 0.2
            Test.@test Models.control(ig1)(0.5) ≈ -0.1

            # With variable
            pre2 = Init.pre_initial_guess(state=0.2, control=-0.1, variable=0.5)
            ig2 = Init.build_initial_guess(ocp2, pre2)
            Test.@test ig2 isa Init.InitialGuess
            Test.@test Models.variable(ig2) ≈ 0.5
        end

        Test.@testset "build_initial_guess - NamedTuple input" begin
            # Use Beam problem from TestProblems
            beam_data = TestProblems.Beam()
            ocp = beam_data.ocp

            # Build from NamedTuple
            init_nt = (state=t -> [0.0, 0.0], control=t -> [1.0])
            ig = Init.build_initial_guess(ocp, init_nt)
            Test.@test ig isa Init.InitialGuess

            # Verify state and control
            x = Models.state(ig)(0.5)
            Test.@test x isa AbstractVector
            Test.@test length(x) == 2
            Test.@test x[1] ≈ 0.0
            Test.@test x[2] ≈ 0.0

            u = Models.control(ig)(0.5)
            Test.@test u isa AbstractVector
            Test.@test length(u) == 1
            Test.@test u[1] ≈ 1.0
        end

        Test.@testset "build_initial_guess - unsupported type" begin
            ocp = DummyOCP1DNoVar()

            # Unsupported type should throw
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(ocp, 42)
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, "invalid"
            )
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, [1, 2, 3]
            )
        end

        Test.@testset "validate_initial_guess - valid" begin
            ocp = DummyOCP1DNoVar()

            # Valid initial guess should not throw
            init = Init.initial_guess(ocp; state=0.2, control=-0.1)
            result = Init.validate_initial_guess(ocp, init)
            Test.@test result === init
        end

        Test.@testset "validate_initial_guess - invalid dimensions" begin
            ocp = DummyOCP1DNoVar()

            # Manually construct an invalid initial guess
            bad_init = Init.InitialGuess(t -> [t, 2t], t -> 0.1, Float64[])

            # validate_initial_guess must catch dimension mismatch
            Test.@test_throws Exceptions.IncorrectArgument Init.validate_initial_guess(
                ocp, bad_init
            )
        end

        # ====================================================================
        # UNIT TESTS - Separation of Construction and Validation
        # ====================================================================

        Test.@testset "initial_guess is pure construction (no validation)" begin
            ocp = DummyOCP1DNoVar()

            # initial_guess() constructs without validating; it returns an
            # InitialGuess even with compatible dimensions.
            init = Init.initial_guess(ocp; state=0.2, control=-0.1)
            Test.@test init isa Init.InitialGuess
            Test.@test Models.state(init)(0.0) ≈ 0.2
            Test.@test Models.control(init)(0.0) ≈ -0.1
        end

        Test.@testset "build_initial_guess centralises validation" begin
            ocp = DummyOCP1DNoVar()

            # All branches of build_initial_guess must produce validated output.
            # Test nothing branch
            ig1 = Init.build_initial_guess(ocp, nothing)
            Test.@test ig1 isa Init.InitialGuess

            # Test () branch
            ig2 = Init.build_initial_guess(ocp, ())
            Test.@test ig2 isa Init.InitialGuess

            # Test PreInit branch
            pre = Init.pre_initial_guess(state=0.2, control=-0.1)
            ig3 = Init.build_initial_guess(ocp, pre)
            Test.@test ig3 isa Init.InitialGuess

            # Test NamedTuple branch
            ig4 = Init.build_initial_guess(ocp, (state=0.2, control=-0.1))
            Test.@test ig4 isa Init.InitialGuess

            # Test direct InitialGuess branch (was not validated before)
            valid_init = Init.initial_guess(ocp; state=0.3)
            ig5 = Init.build_initial_guess(ocp, valid_init)
            Test.@test ig5 === valid_init
        end

        # ====================================================================
        # INTEGRATION TESTS - API Workflow
        # ====================================================================

        Test.@testset "complete workflow: PreInit -> build -> validate" begin
            ocp = DummyOCP1DVar()

            # Step 1: Create PreInit
            pre = Init.pre_initial_guess(state=0.3, control=-0.2, variable=0.7)

            # Step 2: Build initial guess
            ig = Init.build_initial_guess(ocp, pre)
            Test.@test ig isa Init.InitialGuess

            # Step 3: Validate
            validated = Init.validate_initial_guess(ocp, ig)
            Test.@test validated === ig

            # Verify values
            Test.@test Models.state(ig)(0.5) ≈ 0.3
            Test.@test Models.control(ig)(0.5) ≈ -0.2
            Test.@test Models.variable(ig) ≈ 0.7
        end

        Test.@testset "complete workflow: NamedTuple -> build -> validate" begin
            ocp = DummyOCP1DVar()

            # Step 1: Create NamedTuple
            init_nt = (state=0.3, control=-0.2, variable=0.7)

            # Step 2: Build initial guess (validates internally)
            ig = Init.build_initial_guess(ocp, init_nt)
            Test.@test ig isa Init.InitialGuess

            # Step 3: Validate again (idempotent)
            validated = Init.validate_initial_guess(ocp, ig)
            Test.@test validated === ig

            # Verify values
            Test.@test Models.state(ig)(0.5) ≈ 0.3
            Test.@test Models.control(ig)(0.5) ≈ -0.2
            Test.@test Models.variable(ig) ≈ 0.7
        end

        Test.@testset "regression: invalid direct InitialGuess is caught by build" begin
            ocp = DummyOCP1DVar()

            # Construct an invalid initial guess manually (wrong control dimension)
            bad_init = Init.InitialGuess(t -> 0.1, t -> [0.1, 0.2], 0.5)

            # Before refactoring, this would pass through unchecked.
            # After refactoring, build_initial_guess validates ALL branches.
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_init
            )
        end
    end
end
end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_api() = TestInitialGuessAPI.test_initial_guess_api()
