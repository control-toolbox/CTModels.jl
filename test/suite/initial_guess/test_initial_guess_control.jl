# ------------------------------------------------------------------------------
# Control Initial Guess Tests
# ------------------------------------------------------------------------------
using Test
using CTModels
using CTModels.InitialGuess

@testset "Control Initial Guess" verbose = true begin
    
    @testset "initial_control with Function" begin
        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1, "u")
        
        f = t -> sin(t)
        result = initial_control(ocp, f)
        @test result === f
    end
    
    @testset "initial_control with Scalar" begin
        # 1D control - should work
        ocp_1d = CTModels.PreModel()
        CTModels.control!(ocp_1d, 1, "u")
        
        result = initial_control(ocp_1d, 0.5)
        @test result isa Function
        @test result(0.0) == 0.5
        
        # 2D control - should throw error
        ocp_2d = CTModels.PreModel()
        CTModels.control!(ocp_2d, 2, "u", ["u₁", "u₂"])
        
        @test_throws CTModels.Exceptions.IncorrectArgument initial_control(ocp_2d, 0.5)
    end
    
    @testset "initial_control with Vector" begin
        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1, "u")
        
        # Correct dimension
        result = initial_control(ocp, [0.0])
        @test result isa Function
        @test result(0.0) == 0.0
        
        # Wrong dimension
        @test_throws CTModels.Exceptions.IncorrectArgument initial_control(ocp, [0.0, 1.0])
    end
    
    @testset "initial_control with Nothing" begin
        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1, "u")
        
        result = initial_control(ocp, nothing)
        @test result isa Function
        @test result(0.0) == 0.1
        
        # 2D control
        ocp_2d = CTModels.PreModel()
        CTModels.control!(ocp_2d, 2, "u", ["u₁", "u₂"])
        
        result_2d = initial_control(ocp_2d, nothing)
        @test result_2d isa Function
        @test result_2d(0.0) == [0.1, 0.1]
    end
    
    @testset "control accessor" begin
        ocp = CTModels.PreModel()
        CTModels.time!(ocp, t0=0, tf=1, time_name="t")
        CTModels.control!(ocp, 1, "u")
        
        init = initial_guess(ocp; control=t -> sin(t))
        
        @test control(init) isa Function
        @test control(init)(0.5) ≈ sin(0.5)
    end
end
