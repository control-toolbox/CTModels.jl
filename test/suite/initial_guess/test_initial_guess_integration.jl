module TestInitialGuessIntegration

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
using Main.TestProblems
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_initial_guess_integration()
    Test.@testset "Initial Guess Integration" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ========================================================================
        # INTEGRATION TESTS - Real OCP Problems
        # ========================================================================

        Test.@testset "Beam problem - NamedTuple initialization" begin
            beam_data = Beam()
            ocp = beam_data.ocp

            # Test with NamedTuple on real problem
            init_named = (state=[0.05, 0.1], control=[0.1], variable=Float64[])
            ig = CTModels.build_initial_guess(ocp, init_named)
            Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
            CTModels.validate_initial_guess(ocp, ig)

            # Verify values
            x = CTModels.state(ig)(0.5)
            Test.@test x isa AbstractVector
            Test.@test length(x) == 2
            Test.@test x[1] ≈ 0.05
            Test.@test x[2] ≈ 0.1

            u = CTModels.control(ig)(0.5)
            Test.@test u isa AbstractVector
            Test.@test length(u) == 1
            Test.@test u[1] ≈ 0.1

            # Test with incorrect state dimension (should throw)
            bad_named = (state=[0.1, 0.2, 0.3], control=[0.1], variable=Float64[])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.build_initial_guess(
                ocp, bad_named
            )
        end

        Test.@testset "Beam problem - function-based initialization" begin
            beam_data = Beam()
            ocp = beam_data.ocp

            # Test with functions
            init_nt = (state=t -> [sin(t), cos(t)], control=t -> [t])
            ig = CTModels.build_initial_guess(ocp, init_nt)
            Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
            CTModels.validate_initial_guess(ocp, ig)

            # Verify functions work correctly
            x = CTModels.state(ig)(0.5)
            Test.@test x[1] ≈ sin(0.5)
            Test.@test x[2] ≈ cos(0.5)

            u = CTModels.control(ig)(0.5)
            Test.@test u[1] ≈ 0.5
        end

        Test.@testset "Beam problem - time-grid initialization" begin
            beam_data = Beam()
            ocp = beam_data.ocp

            # Test with time-grid data
            time = [0.0, 0.5, 1.0]
            state_data = [[0.0, 0.0], [0.5, 0.5], [1.0, 1.0]]
            control_data = [[0.0], [0.5], [1.0]]

            init_nt = (state=(time, state_data), control=(time, control_data))
            ig = CTModels.build_initial_guess(ocp, init_nt)
            Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
            CTModels.validate_initial_guess(ocp, ig)

            # Verify interpolation works
            x = CTModels.state(ig)(0.5)
            Test.@test x[1] ≈ 0.5
            Test.@test x[2] ≈ 0.5

            u = CTModels.control(ig)(0.5)
            Test.@test u[1] ≈ 0.5
        end

        Test.@testset "Beam problem - PreInit workflow" begin
            beam_data = Beam()
            ocp = beam_data.ocp

            # Create PreInit
            pre = CTModels.pre_initial_guess(
                state=t -> [0.1, 0.2], control=t -> [0.5]
            )

            # Build and validate
            ig = CTModels.build_initial_guess(ocp, pre)
            Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
            validated = CTModels.validate_initial_guess(ocp, ig)
            Test.@test validated === ig

            # Verify values
            x = CTModels.state(ig)(0.5)
            Test.@test x[1] ≈ 0.1
            Test.@test x[2] ≈ 0.2

            u = CTModels.control(ig)(0.5)
            Test.@test u[1] ≈ 0.5
        end

        Test.@testset "Beam problem - complete workflow with all features" begin
            beam_data = Beam()
            ocp = beam_data.ocp

            # Complex initialization with mixed features:
            # - Time-grid for state
            # - Function for control
            # - Named components
            time = [0.0, 1.0]
            state_data = [[0.0, 0.0], [1.0, 1.0]]

            init_nt = (state=(time, state_data), control=t -> [sin(t)])
            ig = CTModels.build_initial_guess(ocp, init_nt)
            Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
            CTModels.validate_initial_guess(ocp, ig)

            # Verify both time-grid (state) and function (control) work
            x = CTModels.state(ig)(0.5)
            Test.@test x isa AbstractVector
            Test.@test length(x) == 2

            u = CTModels.control(ig)(0.5)
            Test.@test u[1] ≈ sin(0.5)
        end
    end
end
end # module

test_initial_guess_integration() = TestInitialGuessIntegration.test_initial_guess_integration()
