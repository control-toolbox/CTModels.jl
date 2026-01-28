module TestInitialGuessUtils

using Test
using CTModels
using Main.TestOptions: VERBOSE, SHOWTIMING

# Helper struct for testing
struct DummyOCP1D <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1D) = 1
CTModels.control_dimension(::DummyOCP1D) = 1
CTModels.variable_dimension(::DummyOCP1D) = 0
CTModels.has_fixed_initial_time(::DummyOCP1D) = true
CTModels.initial_time(::DummyOCP1D) = 0.0
CTModels.state_name(::DummyOCP1D) = "x"
CTModels.state_components(::DummyOCP1D) = ["x"]
CTModels.control_name(::DummyOCP1D) = "u"
CTModels.control_components(::DummyOCP1D) = ["u"]
CTModels.variable_name(::DummyOCP1D) = "v"
CTModels.variable_components(::DummyOCP1D) = String[]

struct DummyOCP2D <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP2D) = 2
CTModels.control_dimension(::DummyOCP2D) = 1
CTModels.variable_dimension(::DummyOCP2D) = 0
CTModels.has_fixed_initial_time(::DummyOCP2D) = true
CTModels.initial_time(::DummyOCP2D) = 0.0
CTModels.state_name(::DummyOCP2D) = "x"
CTModels.state_components(::DummyOCP2D) = ["x1", "x2"]
CTModels.control_name(::DummyOCP2D) = "u"
CTModels.control_components(::DummyOCP2D) = ["u"]
CTModels.variable_name(::DummyOCP2D) = "v"
CTModels.variable_components(::DummyOCP2D) = String[]

function test_initial_guess_utils()
    # ========================================================================
    # UNIT TESTS - Utility Functions
    # ========================================================================

    Test.@testset "time grid formatting (indirect test)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D()

        # Test that time grid formatting works via build_initial_guess
        # (tests _format_time_grid indirectly)
        time_vec = [0.0, 0.5, 1.0]
        state_data = [0.0, 0.5, 1.0]

        init_nt = (state=(time_vec, state_data),)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess

        # Verify the state function works (proves time grid was formatted correctly)
        x_fun = CTModels.state(ig)
        Test.@test x_fun(0.0) ≈ 0.0
        Test.@test x_fun(0.5) ≈ 0.5
        Test.@test x_fun(1.0) ≈ 1.0
    end

    Test.@testset "matrix data formatting (indirect test)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2D()

        # Matrix format: each row is a time point, each column is a state component
        time = [0.0, 0.5, 1.0]
        state_matrix = [0.0 1.0; 0.5 1.5; 1.0 2.0]

        init_nt = (state=(time, state_matrix),)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess

        # Verify the state function works (proves matrix was formatted correctly)
        x_fun = CTModels.state(ig)
        x0 = x_fun(0.0)
        Test.@test x0 isa AbstractVector
        Test.@test length(x0) == 2
        Test.@test x0[1] ≈ 0.0
        Test.@test x0[2] ≈ 1.0

        x1 = x_fun(1.0)
        Test.@test x1[1] ≈ 1.0
        Test.@test x1[2] ≈ 2.0
    end

    # ========================================================================
    # INTEGRATION TESTS - Utils with Builders
    # ========================================================================

    Test.@testset "time grid formatting in context" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D()

        # Test that time grid formatting works correctly when building initial guess
        time_array = [0.0 0.5 1.0]  # Array format
        state_data = [0.0, 0.5, 1.0]

        # This should work because _format_time_grid converts the array
        init_nt = (state=(time_array, state_data),)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess

        # Verify the state function works
        x_fun = CTModels.state(ig)
        Test.@test x_fun(0.0) ≈ 0.0
        Test.@test x_fun(0.5) ≈ 0.5
        Test.@test x_fun(1.0) ≈ 1.0
    end

    Test.@testset "matrix data formatting in context" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2D()

        # Matrix format: each row is a time point, each column is a state component
        time = [0.0, 0.5, 1.0]
        state_matrix = [0.0 1.0; 0.5 1.5; 1.0 2.0]

        init_nt = (state=(time, state_matrix),)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess

        # Verify the state function works
        x_fun = CTModels.state(ig)
        x0 = x_fun(0.0)
        Test.@test x0 isa AbstractVector
        Test.@test length(x0) == 2
        Test.@test x0[1] ≈ 0.0
        Test.@test x0[2] ≈ 1.0

        x1 = x_fun(1.0)
        Test.@test x1[1] ≈ 1.0
        Test.@test x1[2] ≈ 2.0
    end
end

end # module

test_initial_guess_utils() = TestInitialGuessUtils.test_initial_guess_utils()
