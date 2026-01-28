module TestInitialGuessVariable

using Test
using CTModels
using CTModels.Exceptions
using Main.TestOptions: VERBOSE, SHOWTIMING

# Dummy OCPs for testing
struct DummyOCPNoVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCPNoVar) = 1
CTModels.control_dimension(::DummyOCPNoVar) = 1
CTModels.variable_dimension(::DummyOCPNoVar) = 0

struct DummyOCP1DVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1DVar) = 1
CTModels.control_dimension(::DummyOCP1DVar) = 1
CTModels.variable_dimension(::DummyOCP1DVar) = 1

struct DummyOCP2DVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP2DVar) = 1
CTModels.control_dimension(::DummyOCP2DVar) = 1
CTModels.variable_dimension(::DummyOCP2DVar) = 2

function test_initial_guess_variable()
    Test.@testset "Variable Initial Guess" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        Test.@testset "initial_variable with Scalar" verbose=VERBOSE showtiming=SHOWTIMING begin
            ocp_1d = DummyOCP1DVar()
            
            result = CTModels.initial_variable(ocp_1d, 0.5)
            Test.@test result == 0.5
            
            ocp_2d = DummyOCP2DVar()
            result_2d = CTModels.initial_variable(ocp_2d, 0.5)
            Test.@test result_2d == 0.5
            
            ocp_no_var = DummyOCPNoVar()
            Test.@test_throws IncorrectArgument CTModels.initial_variable(ocp_no_var, 0.5)
        end
        
        Test.@testset "initial_variable with Vector" verbose=VERBOSE showtiming=SHOWTIMING begin
            ocp = DummyOCP2DVar()
            
            result = CTModels.initial_variable(ocp, [0.0, 1.0])
            Test.@test result == [0.0, 1.0]
            
            Test.@test_throws IncorrectArgument CTModels.initial_variable(ocp, [0.0])
        end
        
        Test.@testset "initial_variable with Nothing" verbose=VERBOSE showtiming=SHOWTIMING begin
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
        
        Test.@testset "variable accessor" verbose=VERBOSE showtiming=SHOWTIMING begin
            ocp = DummyOCP2DVar()
            
            init = CTModels.initial_guess(ocp; variable=[0.0, 1.0])
            
            Test.@test CTModels.variable(init) == [0.0, 1.0]
        end
    end
end

end # module

test_initial_guess_variable() = TestInitialGuessVariable.test_initial_guess_variable()
