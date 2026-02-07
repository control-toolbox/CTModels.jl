module TestInitialGuessControl

using Test
using CTBase: CTBase, Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Dummy OCPs for testing
struct DummyOCP1D <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1D) = 1
CTModels.control_dimension(::DummyOCP1D) = 1
CTModels.variable_dimension(::DummyOCP1D) = 0
CTModels.has_fixed_initial_time(::DummyOCP1D) = true
CTModels.initial_time(::DummyOCP1D) = 0.0

struct DummyOCP2D <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP2D) = 1
CTModels.control_dimension(::DummyOCP2D) = 2
CTModels.variable_dimension(::DummyOCP2D) = 0
CTModels.has_fixed_initial_time(::DummyOCP2D) = true
CTModels.initial_time(::DummyOCP2D) = 0.0

function test_initial_guess_control()
    Test.@testset "Control Initial Guess" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        Test.@testset "initial_control with Function" begin
            ocp = DummyOCP1D()
            
            f = t -> sin(t)
            result = CTModels.initial_control(ocp, f)
            Test.@test result === f
        end
        
        Test.@testset "initial_control with Scalar" begin
            ocp_1d = DummyOCP1D()
            
            result = CTModels.initial_control(ocp_1d, 0.5)
            Test.@test result isa Function
            Test.@test result(0.0) == 0.5
            
            ocp_2d = DummyOCP2D()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.initial_control(ocp_2d, 0.5)
        end
        
        Test.@testset "initial_control with Vector" begin
            ocp = DummyOCP1D()
            
            result = CTModels.initial_control(ocp, [0.0])
            Test.@test result isa Function
            Test.@test result(0.0) == [0.0]
            
            Test.@test_throws Exceptions.IncorrectArgument CTModels.initial_control(ocp, [0.0, 1.0])
        end
        
        Test.@testset "initial_control with Nothing" begin
            ocp = DummyOCP1D()
            
            result = CTModels.initial_control(ocp, nothing)
            Test.@test result isa Function
            Test.@test result(0.0) == 0.1
            
            ocp_2d = DummyOCP2D()
            result_2d = CTModels.initial_control(ocp_2d, nothing)
            Test.@test result_2d isa Function
            Test.@test result_2d(0.0) == [0.1, 0.1]
        end
        
        Test.@testset "control accessor" begin
            ocp = DummyOCP1D()
            
            init = CTModels.initial_guess(ocp; control=t -> sin(t))
            
            Test.@test CTModels.control(init) isa Function
            Test.@test CTModels.control(init)(0.5) ≈ sin(0.5)
        end
    end
end

end # module

test_initial_guess_control() = TestInitialGuessControl.test_initial_guess_control()
