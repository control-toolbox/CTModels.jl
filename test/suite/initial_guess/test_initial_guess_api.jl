module TestInitialGuessAPI

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
using Main.TestProblems
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Dummy OCPs for testing
struct DummyOCP1DNoVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1DNoVar) = 1
CTModels.control_dimension(::DummyOCP1DNoVar) = 1
CTModels.variable_dimension(::DummyOCP1DNoVar) = 0
CTModels.has_fixed_initial_time(::DummyOCP1DNoVar) = true
CTModels.initial_time(::DummyOCP1DNoVar) = 0.0
CTModels.state_name(::DummyOCP1DNoVar) = "x"
CTModels.state_components(::DummyOCP1DNoVar) = ["x"]
CTModels.control_name(::DummyOCP1DNoVar) = "u"
CTModels.control_components(::DummyOCP1DNoVar) = ["u"]
CTModels.variable_name(::DummyOCP1DNoVar) = "v"
CTModels.variable_components(::DummyOCP1DNoVar) = String[]

struct DummyOCP1DVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1DVar) = 1
CTModels.control_dimension(::DummyOCP1DVar) = 1
CTModels.variable_dimension(::DummyOCP1DVar) = 1
CTModels.has_fixed_initial_time(::DummyOCP1DVar) = true
CTModels.initial_time(::DummyOCP1DVar) = 0.0
CTModels.state_name(::DummyOCP1DVar) = "x"
CTModels.state_components(::DummyOCP1DVar) = ["x"]
CTModels.control_name(::DummyOCP1DVar) = "u"
CTModels.control_components(::DummyOCP1DVar) = ["u"]
CTModels.variable_name(::DummyOCP1DVar) = "v"
CTModels.variable_components(::DummyOCP1DVar) = ["v"]

function test_initial_guess_api()
    Test.@testset "Testing initial guess API" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ========================================================================
        # UNIT TESTS - Public API Functions
        # ========================================================================

        Test.@testset "pre_initial_guess" begin
            # Test with all arguments
            state_data = t -> [t]
            control_data = t -> [-t]
            variable_data = 0.5

            pre = CTModels.pre_initial_guess(
                state=state_data, control=control_data, variable=variable_data
            )

            Test.@test pre isa CTModels.PreInitialGuess
            Test.@test pre.state === state_data
            Test.@test pre.control === control_data
            Test.@test pre.variable === variable_data

            # Test with no arguments (all nothing)
            pre_empty = CTModels.pre_initial_guess()
            Test.@test pre_empty isa CTModels.PreInitialGuess
            Test.@test pre_empty.state === nothing
            Test.@test pre_empty.control === nothing
            Test.@test pre_empty.variable === nothing

            # Test with partial arguments
            pre_partial = CTModels.pre_initial_guess(state=0.1)
            Test.@test pre_partial.state === 0.1
            Test.@test pre_partial.control === nothing
            Test.@test pre_partial.variable === nothing
        end

        Test.@testset "initial_guess - basic construction" begin
            ocp = DummyOCP1DNoVar()

            # Scalar initial guess consistent with dimension 1
            init = CTModels.initial_guess(ocp; state=0.2, control=-0.1)
            Test.@test init isa CTModels.AbstractInitialGuess
            Test.@test init isa CTModels.InitialGuess

            # Verify state and control are functions
            Test.@test CTModels.state(init) isa Function
            Test.@test CTModels.control(init) isa Function

            # Verify they return correct values
            Test.@test CTModels.state(init)(0.5) ≈ 0.2
            Test.@test CTModels.control(init)(0.5) ≈ -0.1

            # Variable should be empty vector for no-variable problem
            Test.@test CTModels.variable(init) isa Vector{Float64}
            Test.@test length(CTModels.variable(init)) == 0
        end

        Test.@testset "initial_guess - with variable" begin
            ocp = DummyOCP1DVar()

            # Scalar variable consistent with dimension 1
            init = CTModels.initial_guess(ocp; state=0.2, control=-0.1, variable=0.5)
            Test.@test init isa CTModels.InitialGuess

            # Verify variable
            Test.@test CTModels.variable(init) ≈ 0.5
        end

        Test.@testset "initial_guess - default values" begin
            ocp = DummyOCP1DNoVar()

            # No arguments - should use defaults
            init = CTModels.initial_guess(ocp)
            Test.@test init isa CTModels.InitialGuess

            # Defaults should be 0.1
            Test.@test CTModels.state(init)(0.5) ≈ 0.1
            Test.@test CTModels.control(init)(0.5) ≈ 0.1
        end

        Test.@testset "build_initial_guess - nothing input" begin
            ocp = DummyOCP1DNoVar()

            # nothing should return default initial guess
            ig_nothing = CTModels.build_initial_guess(ocp, nothing)
            Test.@test ig_nothing isa CTModels.InitialGuess

            # () should also return default
            ig_empty = CTModels.build_initial_guess(ocp, ())
            Test.@test ig_empty isa CTModels.InitialGuess
        end

        Test.@testset "build_initial_guess - InitialGuess input (valid)" begin
            ocp = DummyOCP1DNoVar()

            # Create a valid initial guess
            init = CTModels.initial_guess(ocp; state=0.5)

            # Passing it to build_initial_guess should validate and return it
            ig = CTModels.build_initial_guess(ocp, init)
            Test.@test ig === init
        end

        Test.@testset "build_initial_guess - InitialGuess input (invalid)" begin
            ocp = DummyOCP1DNoVar()

            # Manually construct an invalid initial guess (wrong state dimension)
            bad_init = CTModels.InitialGuess(t -> [t, 2t], t -> 0.1, Float64[])

            # build_initial_guess must now catch this via centralised validation
            Test.@test_throws Exceptions.IncorrectArgument CTModels.build_initial_guess(
                ocp, bad_init
            )
        end

        Test.@testset "build_initial_guess - PreInitialGuess input" begin
            ocp1 = DummyOCP1DNoVar()
            ocp2 = DummyOCP1DVar()

            # Create a PreInit
            pre1 = CTModels.pre_initial_guess(state=0.2, control=-0.1)
            ig1 = CTModels.build_initial_guess(ocp1, pre1)
            Test.@test ig1 isa CTModels.InitialGuess
            Test.@test CTModels.state(ig1)(0.5) ≈ 0.2
            Test.@test CTModels.control(ig1)(0.5) ≈ -0.1

            # With variable
            pre2 = CTModels.pre_initial_guess(state=0.2, control=-0.1, variable=0.5)
            ig2 = CTModels.build_initial_guess(ocp2, pre2)
            Test.@test ig2 isa CTModels.InitialGuess
            Test.@test CTModels.variable(ig2) ≈ 0.5
        end

        Test.@testset "build_initial_guess - NamedTuple input" begin
            # Use Beam problem from TestProblems
            beam_data = Beam()
            ocp = beam_data.ocp

            # Build from NamedTuple
            init_nt = (state=t -> [0.0, 0.0], control=t -> [1.0])
            ig = CTModels.build_initial_guess(ocp, init_nt)
            Test.@test ig isa CTModels.InitialGuess

            # Verify state and control
            x = CTModels.state(ig)(0.5)
            Test.@test x isa AbstractVector
            Test.@test length(x) == 2
            Test.@test x[1] ≈ 0.0
            Test.@test x[2] ≈ 0.0

            u = CTModels.control(ig)(0.5)
            Test.@test u isa AbstractVector
            Test.@test length(u) == 1
            Test.@test u[1] ≈ 1.0
        end

        Test.@testset "build_initial_guess - unsupported type" begin
            ocp = DummyOCP1DNoVar()

            # Unsupported type should throw
            Test.@test_throws Exceptions.IncorrectArgument CTModels.build_initial_guess(
                ocp, 42
            )
            Test.@test_throws Exceptions.IncorrectArgument CTModels.build_initial_guess(
                ocp, "invalid"
            )
            Test.@test_throws Exceptions.IncorrectArgument CTModels.build_initial_guess(
                ocp, [1, 2, 3]
            )
        end

        Test.@testset "validate_initial_guess - valid" begin
            ocp = DummyOCP1DNoVar()

            # Valid initial guess should not throw
            init = CTModels.initial_guess(ocp; state=0.2, control=-0.1)
            result = CTModels.validate_initial_guess(ocp, init)
            Test.@test result === init
        end

        Test.@testset "validate_initial_guess - invalid dimensions" begin
            ocp = DummyOCP1DNoVar()

            # Manually construct an invalid initial guess
            bad_init = CTModels.InitialGuess(t -> [t, 2t], t -> 0.1, Float64[])

            # validate_initial_guess must catch dimension mismatch
            Test.@test_throws Exceptions.IncorrectArgument CTModels.validate_initial_guess(
                ocp, bad_init
            )
        end

        # ========================================================================
        # UNIT TESTS - Separation of Construction and Validation
        # ========================================================================

        Test.@testset "initial_guess is pure construction (no validation)" begin
            ocp = DummyOCP1DNoVar()

            # initial_guess() constructs without validating; it returns an
            # InitialGuess even with compatible dimensions.
            init = CTModels.initial_guess(ocp; state=0.2, control=-0.1)
            Test.@test init isa CTModels.InitialGuess
            Test.@test CTModels.state(init)(0.0) ≈ 0.2
            Test.@test CTModels.control(init)(0.0) ≈ -0.1
        end

        Test.@testset "build_initial_guess centralises validation" begin
            ocp = DummyOCP1DNoVar()

            # All branches of build_initial_guess must produce validated output.
            # Test nothing branch
            ig1 = CTModels.build_initial_guess(ocp, nothing)
            Test.@test ig1 isa CTModels.InitialGuess

            # Test () branch
            ig2 = CTModels.build_initial_guess(ocp, ())
            Test.@test ig2 isa CTModels.InitialGuess

            # Test PreInit branch
            pre = CTModels.pre_initial_guess(state=0.2, control=-0.1)
            ig3 = CTModels.build_initial_guess(ocp, pre)
            Test.@test ig3 isa CTModels.InitialGuess

            # Test NamedTuple branch
            ig4 = CTModels.build_initial_guess(ocp, (state=0.2, control=-0.1))
            Test.@test ig4 isa CTModels.InitialGuess

            # Test direct InitialGuess branch (was not validated before)
            valid_init = CTModels.initial_guess(ocp; state=0.3)
            ig5 = CTModels.build_initial_guess(ocp, valid_init)
            Test.@test ig5 === valid_init
        end

        # ========================================================================
        # INTEGRATION TESTS - API Workflow
        # ========================================================================

        Test.@testset "complete workflow: PreInit -> build -> validate" begin
            ocp = DummyOCP1DVar()

            # Step 1: Create PreInit
            pre = CTModels.pre_initial_guess(state=0.3, control=-0.2, variable=0.7)

            # Step 2: Build initial guess
            ig = CTModels.build_initial_guess(ocp, pre)
            Test.@test ig isa CTModels.InitialGuess

            # Step 3: Validate
            validated = CTModels.validate_initial_guess(ocp, ig)
            Test.@test validated === ig

            # Verify values
            Test.@test CTModels.state(ig)(0.5) ≈ 0.3
            Test.@test CTModels.control(ig)(0.5) ≈ -0.2
            Test.@test CTModels.variable(ig) ≈ 0.7
        end

        Test.@testset "complete workflow: NamedTuple -> build -> validate" begin
            ocp = DummyOCP1DVar()

            # Step 1: Create NamedTuple
            init_nt = (state=0.3, control=-0.2, variable=0.7)

            # Step 2: Build initial guess (validates internally)
            ig = CTModels.build_initial_guess(ocp, init_nt)
            Test.@test ig isa CTModels.InitialGuess

            # Step 3: Validate again (idempotent)
            validated = CTModels.validate_initial_guess(ocp, ig)
            Test.@test validated === ig

            # Verify values
            Test.@test CTModels.state(ig)(0.5) ≈ 0.3
            Test.@test CTModels.control(ig)(0.5) ≈ -0.2
            Test.@test CTModels.variable(ig) ≈ 0.7
        end

        Test.@testset "regression: invalid direct InitialGuess is caught by build" begin
            ocp = DummyOCP1DVar()

            # Construct an invalid initial guess manually (wrong control dimension)
            bad_init = CTModels.InitialGuess(t -> 0.1, t -> [0.1, 0.2], 0.5)

            # Before refactoring, this would pass through unchecked.
            # After refactoring, build_initial_guess validates ALL branches.
            Test.@test_throws Exceptions.IncorrectArgument CTModels.build_initial_guess(
                ocp, bad_init
            )
        end
    end
end
end # module

test_initial_guess_api() = TestInitialGuessAPI.test_initial_guess_api()
