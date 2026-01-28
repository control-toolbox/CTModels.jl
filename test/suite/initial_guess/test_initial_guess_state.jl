# ------------------------------------------------------------------------------
# State Initial Guess Tests
# ------------------------------------------------------------------------------
using Test
using CTModels
using CTModels.InitialGuess

@testset "State Initial Guess" verbose = true begin
    
    @testset "initial_state with Function" begin
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
        
        f = t -> [t, t^2]
        result = initial_state(ocp, f)
        @test result === f
    end
    
    @testset "initial_state with Scalar" begin
        # 1D state - should work
        ocp_1d = CTModels.PreModel()
        CTModels.state!(ocp_1d, 1, "x")
        
        result = initial_state(ocp_1d, 0.5)
        @test result isa Function
        @test result(0.0) == 0.5
        
        # 2D state - should throw error
        ocp_2d = CTModels.PreModel()
        CTModels.state!(ocp_2d, 2, "x", ["x₁", "x₂"])
        
        @test_throws CTModels.Exceptions.IncorrectArgument initial_state(ocp_2d, 0.5)
    end
    
    @testset "initial_state with Vector" begin
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
        
        # Correct dimension
        result = initial_state(ocp, [0.0, 1.0])
        @test result isa Function
        @test result(0.0) == [0.0, 1.0]
        
        # Wrong dimension
        @test_throws CTModels.Exceptions.IncorrectArgument initial_state(ocp, [0.0])
    end
    
    @testset "initial_state with Nothing" begin
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
        
        result = initial_state(ocp, nothing)
        @test result isa Function
        @test result(0.0) == [0.1, 0.1]
        
        # 1D state
        ocp_1d = CTModels.PreModel()
        CTModels.state!(ocp_1d, 1, "x")
        
        result_1d = initial_state(ocp_1d, nothing)
        @test result_1d isa Function
        @test result_1d(0.0) == 0.1
    end
    
    @testset "state accessor" begin
        ocp = CTModels.PreModel()
        CTModels.time!(ocp, t0=0, tf=1, time_name="t")
        CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
        
        init = initial_guess(ocp; state=t -> [0.0, 1.0])
        
        @test state(init) isa Function
        @test state(init)(0.5) == [0.0, 1.0]
    end
end
