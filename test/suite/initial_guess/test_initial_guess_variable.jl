module TestInitialGuessVariable

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Dummy OCPs for testing
struct DummyOCPNoVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCPNoVar) = 1
CTModels.control_dimension(::DummyOCPNoVar) = 1
CTModels.variable_dimension(::DummyOCPNoVar) = 0
CTModels.has_fixed_initial_time(::DummyOCPNoVar) = true
CTModels.initial_time(::DummyOCPNoVar) = 0.0

struct DummyOCP1DVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1DVar) = 1
CTModels.control_dimension(::DummyOCP1DVar) = 1
CTModels.variable_dimension(::DummyOCP1DVar) = 1
CTModels.has_fixed_initial_time(::DummyOCP1DVar) = true
CTModels.initial_time(::DummyOCP1DVar) = 0.0

struct DummyOCP2DVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP2DVar) = 1
CTModels.control_dimension(::DummyOCP2DVar) = 1
CTModels.variable_dimension(::DummyOCP2DVar) = 2
CTModels.has_fixed_initial_time(::DummyOCP2DVar) = true
CTModels.initial_time(::DummyOCP2DVar) = 0.0

function test_initial_guess_variable()
    Test.@testset "Variable Initial Guess" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@testset "initial_variable with Scalar" begin
            ocp_1d = DummyOCP1DVar()

            result = CTModels.initial_variable(ocp_1d, 0.5)
            Test.@test result == 0.5

            ocp_no_var = DummyOCPNoVar()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.initial_variable(
                ocp_no_var, 0.5
            )
        end

        Test.@testset "initial_variable with Vector" begin
            ocp = DummyOCP2DVar()

            result = CTModels.initial_variable(ocp, [0.0, 1.0])
            Test.@test result == [0.0, 1.0]

            Test.@test_throws Exceptions.IncorrectArgument CTModels.initial_variable(
                ocp, [0.0]
            )
        end

        Test.@testset "initial_variable with Nothing" begin
            ocp_no_var = DummyOCPNoVar()
            result = CTModels.initial_variable(ocp_no_var, nothing)
            Test.@test result == Float64[]

            ocp_1d = DummyOCP1DVar()
            result_1d = CTModels.initial_variable(ocp_1d, nothing)
            Test.@test result_1d == 0.1

            ocp_2d = DummyOCP2DVar()
            result_2d = CTModels.initial_variable(ocp_2d, nothing)
            Test.@test result_2d == [0.1, 0.1]
        end

        Test.@testset "variable accessor" begin
            ocp = DummyOCP2DVar()

            init = CTModels.initial_guess(ocp; variable=[0.0, 1.0])

            Test.@test CTModels.variable(init) == [0.0, 1.0]
        end
    end
end

end # module

test_initial_guess_variable() = TestInitialGuessVariable.test_initial_guess_variable()
