module TestInitialGuessUtils

import Test: Test
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Init: Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Helper structs — top-level (world-age requirement)
struct DummyOCP1DUtils <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DUtils) = 1
Models.control_dimension(::DummyOCP1DUtils) = 1
Models.variable_dimension(::DummyOCP1DUtils) = 0
Components.has_fixed_initial_time(::DummyOCP1DUtils) = true
Components.initial_time(::DummyOCP1DUtils) = 0.0
Models.state_name(::DummyOCP1DUtils) = "x"
Models.state_components(::DummyOCP1DUtils) = ["x"]
Models.control_name(::DummyOCP1DUtils) = "u"
Models.control_components(::DummyOCP1DUtils) = ["u"]
Models.variable_name(::DummyOCP1DUtils) = "v"
Models.variable_components(::DummyOCP1DUtils) = String[]

struct DummyOCP2DUtils <: Models.AbstractModel end
Models.state_dimension(::DummyOCP2DUtils) = 2
Models.control_dimension(::DummyOCP2DUtils) = 1
Models.variable_dimension(::DummyOCP2DUtils) = 0
Components.has_fixed_initial_time(::DummyOCP2DUtils) = true
Components.initial_time(::DummyOCP2DUtils) = 0.0
Models.state_name(::DummyOCP2DUtils) = "x"
Models.state_components(::DummyOCP2DUtils) = ["x1", "x2"]
Models.control_name(::DummyOCP2DUtils) = "u"
Models.control_components(::DummyOCP2DUtils) = ["u"]
Models.variable_name(::DummyOCP2DUtils) = "v"
Models.variable_components(::DummyOCP2DUtils) = String[]

function test_initial_guess_utils()
    Test.@testset "Initial Guess Utils Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Utility Functions
        # ====================================================================

        Test.@testset "time grid formatting (indirect test)" begin
            ocp = DummyOCP1DUtils()

            time_vec = [0.0, 0.5, 1.0]
            state_data = [0.0, 0.5, 1.0]

            init_nt = (state=(time_vec, state_data),)
            ig = Init.build_initial_guess(ocp, init_nt)
            Test.@test ig isa Init.AbstractInitialGuess

            x_fun = Models.state(ig)
            Test.@test x_fun(0.0) ≈ 0.0
            Test.@test x_fun(0.5) ≈ 0.5
            Test.@test x_fun(1.0) ≈ 1.0
        end

        Test.@testset "matrix data formatting (indirect test)" begin
            ocp = DummyOCP2DUtils()

            time = [0.0, 0.5, 1.0]
            state_matrix = [0.0 1.0; 0.5 1.5; 1.0 2.0]

            init_nt = (state=(time, state_matrix),)
            ig = Init.build_initial_guess(ocp, init_nt)
            Test.@test ig isa Init.AbstractInitialGuess

            x_fun = Models.state(ig)
            x0 = x_fun(0.0)
            Test.@test x0 isa AbstractVector
            Test.@test length(x0) == 2
            Test.@test x0[1] ≈ 0.0
            Test.@test x0[2] ≈ 1.0

            x1 = x_fun(1.0)
            Test.@test x1[1] ≈ 1.0
            Test.@test x1[2] ≈ 2.0
        end

        # ====================================================================
        # INTEGRATION TESTS - Utils with Builders
        # ====================================================================

        Test.@testset "time grid formatting in context" begin
            ocp = DummyOCP1DUtils()

            time_array = [0.0 0.5 1.0]  # Array format
            state_data = [0.0, 0.5, 1.0]

            init_nt = (state=(time_array, state_data),)
            ig = Init.build_initial_guess(ocp, init_nt)
            Test.@test ig isa Init.AbstractInitialGuess

            x_fun = Models.state(ig)
            Test.@test x_fun(0.0) ≈ 0.0
            Test.@test x_fun(0.5) ≈ 0.5
            Test.@test x_fun(1.0) ≈ 1.0
        end

        Test.@testset "matrix data formatting in context" begin
            ocp = DummyOCP2DUtils()

            time = [0.0, 0.5, 1.0]
            state_matrix = [0.0 1.0; 0.5 1.5; 1.0 2.0]

            init_nt = (state=(time, state_matrix),)
            ig = Init.build_initial_guess(ocp, init_nt)
            Test.@test ig isa Init.AbstractInitialGuess

            x_fun = Models.state(ig)
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
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_utils() = TestInitialGuessUtils.test_initial_guess_utils()
